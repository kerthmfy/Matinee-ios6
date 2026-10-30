'use strict';

/*
 * Matinee relay.
 *
 * One process, no runtime dependencies:
 *   - serves small JSON to the phone
 *   - owns every upstream request to Letterboxd and TMDB
 *
 * Start:  node relay/server.js
 * Config: PORT, MATINEE_MEMBER, LB_SESSION_COOKIE, TMDB_API_KEY
 * Offline: MATINEE_OFFLINE=1 (bundled snapshots)
 * Test-only upstream overrides: MATINEE_TMDB_ORIGIN, MATINEE_LB_ORIGIN
 */

const http = require('http');
const https = require('https');
const fs = require('fs');
const path = require('path');

const lb = require('./lb');
const images = require('./images');

const PORT = parseInt(process.env.PORT || '3000', 10);
const MEMBER = process.env.MATINEE_MEMBER || 'kerthfyadao';
const TMDB_KEY = process.env.TMDB_API_KEY || '';
const CACHE_DIR = path.join(__dirname, '.cache');
const FIXTURE_DIR = path.join(__dirname, 'fixtures');

/*
 * Test/deployment switches. The default origin is the real service; the
 * offline flag makes the integration suite deterministic and also lets the
 * relay run from the bundled snapshots without a network.
 */
const TMDB_ORIGIN = process.env.MATINEE_TMDB_ORIGIN || 'https://api.themoviedb.org';
const OFFLINE = process.env.MATINEE_OFFLINE === '1';
const ALLOW_INSECURE_TLS = process.env.MATINEE_INSECURE_TLS === '1';

const FEED_TTL_MS = 5 * 60 * 1000;
const FILM_TTL_MS = 60 * 60 * 1000;

try {
  fs.mkdirSync(CACHE_DIR, { recursive: true });
} catch (e) {
  /* non-fatal */
}

const feedCache = new Map(); // handle -> { data, at, source }
const filmCache = new Map(); // slug -> { data, at, source }

/* ------------------------------------------------------------------ */
/* cache helpers                                                       */
/* ------------------------------------------------------------------ */

function cacheFile(kind, key) {
  return path.join(CACHE_DIR, kind + '-' + key.replace(/[^A-Za-z0-9_-]/g, '_') + '.json');
}

function readJson(file) {
  try {
    return JSON.parse(fs.readFileSync(file, 'utf8'));
  } catch (e) {
    return null;
  }
}

function writeJson(file, value) {
  try {
    fs.writeFileSync(file, JSON.stringify(value));
  } catch (e) {
    /* cache writes are best-effort */
  }
}

function fixture(name) {
  return readJson(path.join(FIXTURE_DIR, name));
}

/* ------------------------------------------------------------------ */
/* feed                                                                */
/* ------------------------------------------------------------------ */

function decorateFeed(parsed, handle, source, fetchedAt) {
  const items = parsed.items.map((item) => {
    if (item.kind === 'diary') {
      return Object.assign({}, item, {
        poster: lb.proxyPath(item.posterCdn, 300),
      });
    }
    return item;
  });

  return {
    ok: true,
    handle,
    member: parsed.member,
    source,
    fetchedAt,
    counts: parsed.counts,
    items,
  };
}

async function getFeed(handle, opts) {
  if (OFFLINE) {
    const fx = fixture('feed-' + handle + '.json');
    if (!fx) throw new Error('offline_fixture_missing');
    const data = decorateFeed(
      { member: fx.member, items: fx.items, counts: fx.counts },
      handle,
      'fixture',
      fx.fetchedAt
    );
    feedCache.set(handle, { data, at: Date.now(), source: 'fixture' });
    return data;
  }

  const force = opts && opts.refresh;
  const hit = feedCache.get(handle);
  if (hit && !force && Date.now() - hit.at < FEED_TTL_MS) {
    return hit.data;
  }

  const disk = readJson(cacheFile('feed', handle));
  if (disk && !force && Date.now() - Date.parse(disk.fetchedAt) < FEED_TTL_MS) {
    feedCache.set(handle, { data: disk, at: Date.now(), source: disk.source });
    return disk;
  }

  try {
    const res = await lb.fetchFeed(handle);
    const parsed = lb.parseFeed(res.xml, handle);
    if (!parsed.items.length) throw new Error('feed_empty');
    const data = decorateFeed(parsed, handle, 'live', res.fetchedAt);
    feedCache.set(handle, { data, at: Date.now(), source: 'live' });
    writeJson(cacheFile('feed', handle), data);
    return data;
  } catch (err) {
    // Stale disk copy beats nothing.
    if (disk) {
      const stale = Object.assign({}, disk, { source: 'stale' });
      feedCache.set(handle, { data: stale, at: Date.now(), source: 'stale' });
      return stale;
    }
    // Finally: a bundled snapshot, so the device still has something to show.
    const fx = fixture('feed-' + handle + '.json');
    if (fx) {
      const stale = decorateFeed(
        { member: fx.member, items: fx.items, counts: fx.counts },
        handle,
        'fixture',
        fx.fetchedAt
      );
      feedCache.set(handle, { data: stale, at: Date.now(), source: 'fixture' });
      return stale;
    }
    throw err;
  }
}

/* ------------------------------------------------------------------ */
/* film                                                                */
/* ------------------------------------------------------------------ */

async function getFilm(slug, opts) {
  if (OFFLINE) {
    const fx = fixture('film-' + slug + '.json');
    if (!fx) throw new Error('offline_fixture_missing');
    const data = Object.assign({}, fx, { source: 'fixture' });
    filmCache.set(slug, { data, at: Date.now() });
    return data;
  }

  const force = opts && opts.refresh;
  const hit = filmCache.get(slug);
  if (hit && !force && Date.now() - hit.at < FILM_TTL_MS) return hit.data;

  const disk = readJson(cacheFile('film', slug));
  if (disk && !force && Date.now() - Date.parse(disk.fetchedAt) < FILM_TTL_MS) {
    filmCache.set(slug, { data: disk, at: Date.now() });
    return disk;
  }

  try {
    const res = await lb.fetchFilm(slug);
    const film = lb.parseFilm(res.html, slug);
    const data = Object.assign({ ok: true, source: 'live', fetchedAt: res.fetchedAt }, film, {
      poster: lb.proxyPath(film.posterCdn, 300),
      posterLarge: lb.proxyPath(film.posterCdn, 600),
    });
    delete data.html;
    filmCache.set(slug, { data, at: Date.now() });
    writeJson(cacheFile('film', slug), data);
    return data;
  } catch (err) {
    if (disk) return Object.assign({}, disk, { source: 'stale' });
    const fx = fixture('film-' + slug + '.json');
    if (fx) return Object.assign({}, fx, { source: 'fixture' });
    throw err;
  }
}

/* ------------------------------------------------------------------ */
/* tmdb search                                                         */
/* ------------------------------------------------------------------ */

function tmdbGet(pathAndQuery) {
  return new Promise((resolve, reject) => {
    const origin = new URL(TMDB_ORIGIN);
    const prefix = origin.pathname.replace(/\/+$/, '');
    const options = {
      hostname: origin.hostname,
      path: prefix + pathAndQuery,
      method: 'GET',
      headers: { Accept: 'application/json' },
      timeout: 10000,
    };
    if (origin.port) options.port = Number(origin.port);
    if (ALLOW_INSECURE_TLS) options.rejectUnauthorized = false;

    const req = https.request(
      options,
      (res) => {
        const chunks = [];
        res.on('data', (c) => chunks.push(c));
        res.on('end', () => {
          try {
            resolve({ status: res.statusCode, json: JSON.parse(Buffer.concat(chunks).toString('utf8')) });
          } catch (e) {
            reject(new Error('tmdb_bad_json'));
          }
        });
      }
    );
    req.on('timeout', () => req.destroy(new Error('tmdb_timeout')));
    req.on('error', reject);
    req.end();
  });
}

async function search(query) {
  if (!TMDB_KEY) {
    return {
      ok: false,
      reason: 'tmdb_key_missing',
      detail:
        'Search needs a free TMDB key. Register at themoviedb.org, then set ' +
        'TMDB_API_KEY and restart the relay.',
    };
  }
  const q = String(query || '').trim().slice(0, 80);
  if (!q) return { ok: false, reason: 'empty_query' };

  const p = '/3/search/multi?api_key=' + encodeURIComponent(TMDB_KEY) +
    '&query=' + encodeURIComponent(q) + '&include_adult=false&language=en-US&page=1';
  const res = await tmdbGet(p);
  if (res.status !== 200) {
    return { ok: false, reason: 'tmdb_http_' + res.status };
  }

  const results = (res.json.results || [])
    .filter((r) => r.media_type === 'movie' || r.media_type === 'tv')
    .slice(0, 12)
    .map((r) => {
      const isMovie = r.media_type === 'movie';
      const date = (isMovie ? r.release_date : r.first_air_date) || '';
      const posterCdn = r.poster_path
        ? 'https://image.tmdb.org/t/p/w342' + r.poster_path
        : null;
      return {
        tmdbId: r.id,
        kind: isMovie ? 'movie' : 'tv',
        title: isMovie ? r.title : r.name,
        year: date ? parseInt(date.slice(0, 4), 10) : null,
        rating: typeof r.vote_average === 'number' ? Math.round(r.vote_average * 10) / 10 : null,
        overview: r.overview || '',
        posterCdn,
        poster: lb.proxyPath(posterCdn, 300),
      };
    });

  return { ok: true, query: q, count: results.length, results };
}

/* ------------------------------------------------------------------ */
/* http helpers                                                        */
/* ------------------------------------------------------------------ */

function sendJson(res, status, body) {
  const payload = Buffer.from(JSON.stringify(body));
  res.writeHead(status, {
    'Content-Type': 'application/json; charset=utf-8',
    'Content-Length': payload.length,
    'Cache-Control': 'no-store',
    'Access-Control-Allow-Origin': '*',
  });
  res.end(payload);
}

function readBody(req, limit) {
  const max = limit || 64 * 1024;
  return new Promise((resolve, reject) => {
    const chunks = [];
    let size = 0;
    req.on('data', (c) => {
      size += c.length;
      if (size > max) {
        reject(new Error('body_too_large'));
        req.destroy();
        return;
      }
      chunks.push(c);
    });
    req.on('end', () => resolve(Buffer.concat(chunks).toString('utf8')));
    req.on('error', reject);
  });
}

async function readJsonBody(req) {
  const raw = await readBody(req);
  if (!raw) return {};
  try {
    return JSON.parse(raw);
  } catch (e) {
    return null;
  }
}

/* ------------------------------------------------------------------ */
/* routes                                                              */
/* ------------------------------------------------------------------ */

async function route(req, res) {
  const u = new URL(req.url, 'http://' + (req.headers.host || 'localhost'));
  const pathname = u.pathname;

  if (req.method === 'OPTIONS') {
    res.writeHead(204, {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type',
    });
    return res.end();
  }

  if (pathname === '/') {
    return sendJson(res, 200, {
      ok: true,
      service: 'matinee-relay',
      version: '1.0.0',
      endpoints: [
        '/api/health',
        '/api/session',
        '/api/feed',
        '/api/film',
        '/api/search',
        '/api/connect',
        '/api/log',
        '/img',
      ],
    });
  }

  if (pathname === '/api/health') {
    const cachedFeed = feedCache.get(MEMBER);
    return sendJson(res, 200, {
      ok: true,
      service: 'matinee-relay',
      version: '1.0.0',
      member: MEMBER,
      tmdb: Boolean(TMDB_KEY),
      images: images.stats(),
      feed: cachedFeed
        ? {
            items: cachedFeed.data.counts.total,
            source: cachedFeed.data.source,
            fetchedAt: cachedFeed.data.fetchedAt,
          }
        : null,
      session: Boolean(process.env.LB_SESSION_COOKIE),
    });
  }

  if (pathname === '/api/session') {
    const cookie = process.env.LB_SESSION_COOKIE || '';
    if (!cookie) {
      return sendJson(res, 200, {
        ok: true,
        configured: false,
        signedIn: false,
        reason: 'no_session',
        detail: 'No LB_SESSION_COOKIE is set on the relay.',
      });
    }
    const result = await lb.checkSession(cookie);
    const signedIn = Boolean(result.ok && result.signedIn);
    return sendJson(res, 200, {
      ok: true,
      configured: true,
      signedIn,
      reason: result.reason || (signedIn ? 'signed_in' : 'session_not_valid'),
      slug: result.slug || null,
      detail: result.detail || null,
    });
  }

  if (pathname === '/api/feed') {
    const handle = u.searchParams.get('user') || MEMBER;
    const parsed = lb.parseHandle(handle);
    if (!parsed) return sendJson(res, 400, { ok: false, reason: 'bad_handle' });
    try {
      const data = await getFeed(parsed, { refresh: u.searchParams.get('refresh') === '1' });
      const limit = parseInt(u.searchParams.get('limit') || '0', 10);
      if (limit > 0) {
        const items = data.items.filter((i) => i.kind === 'diary').slice(0, limit);
        return sendJson(res, 200, Object.assign({}, data, { items, truncated: true }));
      }
      return sendJson(res, 200, data);
    } catch (err) {
      return sendJson(res, 502, {
        ok: false,
        reason: 'feed_unavailable',
        detail: String(err.message || err),
      });
    }
  }

  if (pathname === '/api/film') {
    const slug = (u.searchParams.get('slug') || '').trim();
    if (!/^[a-z0-9][a-z0-9-]{0,199}$/.test(slug)) {
      return sendJson(res, 400, { ok: false, reason: 'bad_slug' });
    }
    try {
      const film = await getFilm(slug, { refresh: u.searchParams.get('refresh') === '1' });
      return sendJson(res, 200, film);
    } catch (err) {
      return sendJson(res, 502, {
        ok: false,
        reason: 'film_unavailable',
        detail: String(err.message || err),
      });
    }
  }

  if (pathname === '/api/search') {
    try {
      const result = await search(u.searchParams.get('q'));
      return sendJson(res, result.ok ? 200 : 501, result);
    } catch (err) {
      return sendJson(res, 502, { ok: false, reason: 'search_failed', detail: String(err.message) });
    }
  }

  if (pathname === '/api/connect' && req.method === 'POST') {
    const body = await readJsonBody(req);
    if (!body) return sendJson(res, 400, { ok: false, reason: 'bad_json' });
    const handle = lb.parseHandle(body.input);
    if (!handle) {
      return sendJson(res, 400, {
        ok: false,
        reason: 'bad_handle',
        detail:
          'That does not look like a Letterboxd handle. Paste a profile link ' +
          'like letterboxd.com/yourname or your RSS URL.',
      });
    }
    try {
      const data = await getFeed(handle, { refresh: true });
      return sendJson(res, 200, {
        ok: true,
        handle,
        member: data.member,
        counts: data.counts,
        source: data.source,
      });
    } catch (err) {
      return sendJson(res, 404, {
        ok: false,
        reason: 'no_public_feed',
        detail:
          'No public diary feed for @' + handle + '. The profile may be private, ' +
          'or the handle misspelled.',
      });
    }
  }

  if (pathname === '/api/log' && req.method === 'POST') {
    const body = await readJsonBody(req);
    if (!body) return sendJson(res, 400, { ok: false, reason: 'bad_json' });
    if (!/^[a-z0-9][a-z0-9-]{0,199}$/.test(body.slug || '')) {
      return sendJson(res, 400, { ok: false, reason: 'bad_slug' });
    }
    const result = await lb.submitLog({
      slug: body.slug,
      rating: body.rating,
      watchedDate: body.watchedDate,
      review: body.review,
      rewatch: body.rewatch,
      liked: body.liked,
      tags: body.tags,
      spoilers: body.spoilers,
    });
    return sendJson(res, result.ok ? 200 : 502, result);
  }

  if (pathname === '/img') {
    const raw = u.searchParams.get('u');
    if (!raw) return sendJson(res, 400, { ok: false, reason: 'missing_u' });
    const target = lb.imageUrl(raw, u.searchParams.get('w'));
    if (!target) {
      return sendJson(res, 403, {
        ok: false,
        reason: 'host_not_allowed',
        detail: 'Only Letterboxd and TMDB poster hosts are proxied.',
      });
    }

    const hit = images.get(target);
    if (hit) {
      res.writeHead(200, {
        'Content-Type': hit.contentType,
        'Content-Length': hit.body.length,
        'Cache-Control': 'public, max-age=86400',
        'Access-Control-Allow-Origin': '*',
        'X-LB-Image': 'cache',
      });
      return res.end(hit.body);
    }

    try {
      const img = await lb.fetchImage(target);
      if (img.status !== 200) {
        return sendJson(res, 502, { ok: false, reason: 'upstream_' + img.status });
      }
      images.put(target, { body: img.body, contentType: img.contentType });
      res.writeHead(200, {
        'Content-Type': img.contentType,
        'Content-Length': img.body.length,
        'Cache-Control': 'public, max-age=86400',
        'Access-Control-Allow-Origin': '*',
        'X-LB-Image': 'live',
      });
      return res.end(img.body);
    } catch (err) {
      return sendJson(res, 502, { ok: false, reason: 'image_unavailable', detail: String(err.message) });
    }
  }

  if (pathname.startsWith('/api/')) {
    return sendJson(res, 404, { ok: false, reason: 'no_such_endpoint' });
  }

  return sendJson(res, 404, { ok: false, reason: 'not_found' });
}

/* ------------------------------------------------------------------ */

function createServer() {
  return http.createServer((req, res) => {
    route(req, res).catch((err) => {
      if (!res.headersSent) {
        sendJson(res, 500, { ok: false, reason: 'internal', detail: String(err.message || err) });
      } else {
        res.end();
      }
    });
  });
}

function start() {
  return createServer().listen(PORT, () => {
    console.log('Matinee relay on http://localhost:' + PORT);
    console.log('  member:  ' + MEMBER);
    console.log('  tmdb:    ' + (TMDB_KEY ? 'configured' : 'not configured (search disabled)'));
    console.log('  session: ' + (process.env.LB_SESSION_COOKIE ? 'configured' : 'none (drafts only)'));
  });
}

if (require.main === module) start();

module.exports = { createServer, start, getFeed, getFilm, search, MEMBER };
