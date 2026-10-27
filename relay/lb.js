'use strict';

/*
 * Letterboxd client for the Matinee relay.
 *
 * The phone (iOS 6) never talks to letterboxd.com directly. This module owns
 * every upstream request and every parse, so the device only ever sees small,
 * stable JSON over a connection we control.
 *
 * Two upstream surfaces are used:
 *   - /<handle>/rss/          public, no auth, carries diary entries and lists
 *   - /film/<slug>/           public HTML; JSON-LD for metadata, form for uid
 *
 * The official API is request-only and is not used here.
 */

const https = require('https');
const { URL } = require('url');

// The relay is a modern client, so it should not advertise itself as a 2012
// browser -- old UAs collect Cloudflare challenges. Direct mode (device ->
// letterboxd) is the only place the iOS 6 UA is correct, and it lives in the
// app, not here.
const UA =
  'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 ' +
  '(KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36';

const TIMEOUT_MS = 15000;
const MAX_REDIRECTS = 3;

/*
 * Test-only upstream override. Production always talks to letterboxd.com;
 * the integration suite points this at a local HTTPS server so the cookie
 * write path can be exercised without a real account.
 */
const LB_ORIGIN = (process.env.MATINEE_LB_ORIGIN || 'https://letterboxd.com')
  .replace(/\/+$/, '');
const ALLOW_INSECURE_TLS = process.env.MATINEE_INSECURE_TLS === '1';

const RESERVED = new Set([
  'film', 'films', 'list', 'lists', 'director', 'actor', 'member', 'members',
  'settings', 'import', 'search', 'rss', 'about', 'apps', 'api', 'pro',
  'welcome', 'signin', 'signup', 'logout', 'activity', 'journal', 'reviews',
]);

const HANDLE_RE = /^[A-Za-z0-9_-]{1,40}$/;

/* ------------------------------------------------------------------ */
/* handle parsing                                                      */
/* ------------------------------------------------------------------ */

/**
 * Accept a handle, an @handle, a profile URL, or a pasted RSS URL and return
 * just the handle. Returns null when the input is not a Letterboxd handle.
 *
 * This is the SSRF boundary for the connect flow: whatever the member pastes,
 * the relay always rebuilds the upstream URL from this handle. The pasted URL
 * itself is never fetched.
 */
function parseHandle(input) {
  if (typeof input !== 'string') return null;
  let s = input.trim();
  if (!s) return null;
  if (s.indexOf('..') !== -1 || s.indexOf('\\') !== -1) return null;

  let pathname;
  if (/^https?:\/\//i.test(s)) {
    let u;
    try {
      u = new URL(s);
    } catch (e) {
      return null;
    }
    if (!/(^|\.)letterboxd\.com$/i.test(u.hostname)) return null;
    pathname = u.pathname;
  } else {
    s = s.replace(/^@/, '');
    s = s.replace(/^(www\.)?letterboxd\.com(?=\/|$)/i, '');
    pathname = s.split(/[?#]/)[0];
  }

  // Only /<handle> and /<handle>/rss/ are valid. Anything deeper is rejected
  // rather than silently truncated, so a pasted path cannot smuggle a target.
  const parts = pathname.split('/').filter(Boolean);
  if (!parts.length) return null;
  if (parts.length > 1 && !(parts.length === 2 && parts[1].toLowerCase() === 'rss')) return null;
  const handle = parts[0];
  if (!HANDLE_RE.test(handle)) return null;
  if (RESERVED.has(handle.toLowerCase())) return null;
  return handle;
}

/* ------------------------------------------------------------------ */
/* http                                                                */
/* ------------------------------------------------------------------ */

function request(url, opts, redirects) {
  const options = opts || {};
  const hops = redirects || 0;

  return new Promise((resolve, reject) => {
    let u;
    try {
      u = new URL(url);
    } catch (e) {
      return reject(new Error('bad_url'));
    }
    if (u.protocol !== 'https:') return reject(new Error('not_https'));

    const headers = Object.assign(
      {
        'User-Agent': UA,
        Accept: '*/*',
        'Accept-Language': 'en-NZ,en;q=0.9',
      },
      options.headers || {}
    );
    if (options.body) {
      headers['Content-Length'] = Buffer.byteLength(options.body);
    }

    const requestOptions = {
      method: options.method || 'GET',
      hostname: u.hostname,
      path: u.pathname + u.search,
      headers,
      timeout: TIMEOUT_MS,
    };
    if (u.port) requestOptions.port = Number(u.port);
    if (ALLOW_INSECURE_TLS) requestOptions.rejectUnauthorized = false;

    const req = https.request(
      requestOptions,
      (res) => {
        const status = res.statusCode || 0;
        if (
          status >= 300 &&
          status < 400 &&
          res.headers.location &&
          hops < MAX_REDIRECTS
        ) {
          res.resume();
          const next = new URL(res.headers.location, u).toString();
          return request(next, options, hops + 1).then(resolve, reject);
        }

        const chunks = [];
        let size = 0;
        res.on('data', (c) => {
          size += c.length;
          if (size > 8 * 1024 * 1024) {
            req.destroy(new Error('response_too_large'));
            return;
          }
          chunks.push(c);
        });
        res.on('end', () => {
          resolve({
            status,
            headers: res.headers,
            body: Buffer.concat(chunks),
            url: u.toString(),
          });
        });
      }
    );

    req.on('timeout', () => req.destroy(new Error('timeout')));
    req.on('error', reject);
    if (options.body) req.write(options.body);
    req.end();
  });
}

/* ------------------------------------------------------------------ */
/* text helpers                                                        */
/* ------------------------------------------------------------------ */

function decodeEntities(s) {
  if (!s) return '';
  return s
    .replace(/&#(\d+);/g, (_, d) => String.fromCharCode(parseInt(d, 10)))
    .replace(/&#x([0-9a-f]+);/gi, (_, h) => String.fromCharCode(parseInt(h, 16)))
    .replace(/&quot;/g, '"')
    .replace(/&apos;/g, "'")
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&nbsp;/g, ' ')
    .replace(/&amp;/g, '&');
}

function unwrapCdata(s) {
  if (!s) return '';
  const m = /^\s*<!\[CDATA\[([\s\S]*?)\]\]>\s*$/.exec(s);
  return m ? m[1] : s;
}

function txt(s) {
  return decodeEntities(unwrapCdata(s || '')).trim();
}

function stripTags(html) {
  return decodeEntities(
    (html || '')
      .replace(/<br\s*\/?>/gi, '\n')
      .replace(/<[^>]+>/g, '')
  ).trim();
}

function firstTag(block, name) {
  const esc = name.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  const re = new RegExp('<' + esc + '\\b[^>]*>([\\s\\S]*?)</' + esc + '>', 'i');
  const m = re.exec(block);
  return m ? m[1] : null;
}

function allTags(block, name) {
  const esc = name.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  const re = new RegExp('<' + esc + '\\b[^>]*>([\\s\\S]*?)</' + esc + '>', 'gi');
  const out = [];
  let m;
  while ((m = re.exec(block))) out.push(m[1]);
  return out;
}

function paragraphs(html) {
  const out = [];
  const re = /<p\b[^>]*>([\s\S]*?)<\/p>/gi;
  let m;
  while ((m = re.exec(html || ''))) {
    const t = stripTags(m[1]);
    if (t) out.push(t);
  }
  if (!out.length) {
    const t = stripTags((html || '').replace(/<ol\b[\s\S]*?<\/ol>/gi, ''));
    if (t) out.push(t);
  }
  return out;
}

/**
 * Letterboxd puts "Watched on Sunday May 12, 2019." in the description when an
 * entry has no review. That is a timestamp, not writing, so it is stripped --
 * otherwise every plain watch looks like it has a note.
 */
function cleanReview(text) {
  const t = (text || '').trim();
  if (!t) return '';
  if (/^(?:re)?watched on .{0,60}\b\d{4}\.??$/i.test(t)) return '';
  return t;
}

function isoDate(pubDate) {
  const d = new Date(pubDate || '');
  return isNaN(d.getTime()) ? null : d.toISOString();
}

/* ------------------------------------------------------------------ */
/* feed                                                                */
/* ------------------------------------------------------------------ */

const FEED_URL = (handle) => LB_ORIGIN + '/' + handle + '/rss/';

function parseFeed(xml, handle) {
  const items = [];
  const re = /<item\b[^>]*>([\s\S]*?)<\/item>/g;
  let m;
  let member = null;

  while ((m = re.exec(xml))) {
    const b = m[1];
    const link = txt(firstTag(b, 'link'));
    const guid = txt(firstTag(b, 'guid'));
    const title = txt(firstTag(b, 'title'));
    const desc = unwrapCdata(firstTag(b, 'description') || '');
    const creator = txt(firstTag(b, 'dc:creator'));
    const published = isoDate(txt(firstTag(b, 'pubDate')));

    if (creator && !member) member = creator;

    const watchedDate = txt(firstTag(b, 'letterboxd:watchedDate')) || null;
    const filmTitle = txt(firstTag(b, 'letterboxd:filmTitle'));
    const yearRaw = txt(firstTag(b, 'letterboxd:filmYear'));
    const ratingRaw = txt(firstTag(b, 'letterboxd:memberRating'));
    const likeRaw = txt(firstTag(b, 'letterboxd:memberLike'));
    const rewatchRaw = txt(firstTag(b, 'letterboxd:rewatch'));
    const tmdbId =
      txt(firstTag(b, 'tmdb:movieId')) || txt(firstTag(b, 'tmdb:tvId')) || null;

    const filmSlug = (/\/film\/([^/]+)\//.exec(link) || [])[1] || null;
    const listSlug = (/\/list\/([^/]+)\//.exec(link) || [])[1] || null;
    const posterMatch = /<img[^>]+src="([^"]+)"/i.exec(desc);
    const posterCdn = posterMatch ? decodeEntities(posterMatch[1]) : null;

    if (watchedDate) {
      const rating = ratingRaw ? parseFloat(ratingRaw) : null;
      items.push({
        id: guid || link,
        kind: 'diary',
        title: filmTitle || title.replace(/,\s*\d{4}.*$/, ''),
        year: yearRaw ? parseInt(yearRaw, 10) : null,
        slug: filmSlug,
        link,
        watchedDate,
        published,
        rating: isNaN(rating) ? null : rating,
        liked: /^yes$/i.test(likeRaw),
        rewatch: /^yes$/i.test(rewatchRaw),
        review: cleanReview(paragraphs(desc).join('\n')),
        tmdbId,
        posterCdn,
      });
      continue;
    }

    if (listSlug) {
      const entries = [];
      const liRe = /<li\b[^>]*>[\s\S]*?<a\b[^>]*href="([^"]+)"[^>]*>([\s\S]*?)<\/a>[\s\S]*?<\/li>/gi;
      let li;
      while ((li = liRe.exec(desc))) {
        const href = decodeEntities(li[1]);
        entries.push({
          title: stripTags(li[2]),
          link: href,
          slug: (/\/film\/([^/]+)\//.exec(href) || [])[1] || null,
        });
      }
      const moreMatch = /plus\s+(\d+)\s+more/i.exec(stripTags(desc));
      items.push({
        id: guid || link,
        kind: 'list',
        title,
        slug: listSlug,
        link,
        published,
        entries,
        shown: entries.length,
        total: entries.length + (moreMatch ? parseInt(moreMatch[1], 10) : 0),
      });
    }
  }

  return {
    handle,
    member: member || handle,
    items,
    counts: {
      total: items.length,
      diary: items.filter((i) => i.kind === 'diary').length,
      lists: items.filter((i) => i.kind === 'list').length,
    },
  };
}

async function fetchFeed(handle) {
  const res = await request(FEED_URL(handle));
  if (res.status !== 200) {
    const err = new Error('feed_http_' + res.status);
    err.status = res.status;
    err.body = res.body;
    throw err;
  }
  return {
    status: res.status,
    xml: res.body.toString('utf8'),
    fetchedAt: new Date().toISOString(),
  };
}

/* ------------------------------------------------------------------ */
/* film                                                                */
/* ------------------------------------------------------------------ */

const FILM_URL = (slug) => LB_ORIGIN + '/film/' + slug + '/';

function parseRuntime(iso) {
  const m = /^PT(?:(\d+)H)?(?:(\d+)M)?/.exec(iso || '');
  if (!m) return null;
  const h = parseInt(m[1] || '0', 10);
  const min = parseInt(m[2] || '0', 10);
  const total = h * 60 + min;
  return total > 0 ? total : null;
}

function parseFilm(html, slug) {
  const block = /<script type="application\/ld\+json">([\s\S]*?)<\/script>/i.exec(
    html
  );
  let ld = null;
  if (block) {
    const raw = block[1]
      .replace(/\/\*\s*<!\[CDATA\[\s*\*\//g, '')
      .replace(/\/\*\s*\]\]>\s*\*\//g, '')
      .replace(/<!\[CDATA\[/g, '')
      .replace(/\]\]>/g, '')
      .trim();
    try {
      ld = JSON.parse(raw);
    } catch (e) {
      ld = null;
    }
  }

  const ogTitle = (/:?<meta property="og:title" content="([^"]*)"/i.exec(html) || [])[1];
  const canEnd = (/(?:<link rel="canonical" href="|"canonical" href=")([^"]*)"/i.exec(html) || [])[1];

  const uid = (/(?:data\.viewingable\.uid\s*=\s*|"uid"\s*:\s*)'([^']+)'/.exec(html) ||
    /(?:data\.viewingable\.uid\s*=\s*|"uid"\s*:\s*)"([^"]+)"/.exec(html) ||
    [])[1] || null;

  const csrfMatch = /name="__csrf"\s+value="([^"]*)"/i.exec(html);
  const csrf = csrfMatch ? csrfMatch[1] : null;

  const dateCreated = ld && ld.dateCreated ? String(ld.dateCreated) : null;

  return {
    slug,
    title: (ld && ld.name) || decodeEntities(ogTitle || '') || slug,
    year: dateCreated ? parseInt(dateCreated.slice(0, 4), 10) : null,
    released: dateCreated,
    posterCdn: (ld && ld.image) || null,
    rating: ld && ld.aggregateRating ? ld.aggregateRating.ratingValue : null,
    ratingCount: ld && ld.aggregateRating ? ld.aggregateRating.ratingCount : null,
    reviewCount: ld && ld.aggregateRating ? ld.aggregateRating.reviewCount : null,
    runtime: ld ? parseRuntime(ld.duration) : null,
    directors: ld && ld.director ? [].concat(ld.director).map((d) => d.name) : [],
    cast:
      ld && ld.actor ? [].concat(ld.actor).slice(0, 8).map((a) => a.name) : [],
    genres: ld && ld.genre ? [].concat(ld.genre) : [],
    synopsis: (ld && ld.description) || '',
    countries: ld && ld.countryOfOrigin ? [].concat(ld.countryOfOrigin) : [],
    uid,
    csrf,
    loggable: Boolean(uid) && Boolean(csrf),
    signedIn: Boolean(csrf) && csrf !== 'placeholder',
    canonical: canEnd || FILM_URL(slug),
    parsed: Boolean(ld),
  };
}

async function fetchFilm(slug, cookie) {
  const headers = {};
  if (cookie) headers.Cookie = cookie;
  const res = await request(FILM_URL(slug), { headers });
  if (res.status !== 200) {
    const err = new Error('film_http_' + res.status);
    err.status = res.status;
    throw err;
  }
  return {
    status: res.status,
    html: res.body.toString('utf8'),
    fetchedAt: new Date().toISOString(),
  };
}

/* ------------------------------------------------------------------ */
/* image proxy                                                         */
/* ------------------------------------------------------------------ */

const IMAGE_HOSTS = new Set(['a.ltrbxd.com', 'image.tmdb.org']);

/**
 * Validate an upstream image URL and rewrite Letterboxd's resize path to the
 * requested width. Returns null for anything off the allowlist.
 */
function imageUrl(input, width) {
  let u;
  try {
    u = new URL(input);
  } catch (e) {
    return null;
  }
  if (u.protocol !== 'https:') return null;
  if (!IMAGE_HOSTS.has(u.hostname)) return null;

  if (u.hostname === 'a.ltrbxd.com') {
    const w = Math.max(80, Math.min(900, parseInt(width, 10) || 300));
    const h = Math.round(w * 1.5);
    u.pathname = u.pathname.replace(/-0-\d+-0-\d+-crop/, '-0-' + w + '-0-' + h + '-crop');
  }
  return u.toString();
}

async function fetchImage(url) {
  const res = await request(url, { headers: { Accept: 'image/*' } });
  return {
    status: res.status,
    contentType: res.headers['content-type'] || 'application/octet-stream',
    body: res.body,
  };
}

/** Poster path for the device: always through this relay. */
function proxyPath(posterCdn, width) {
  if (!posterCdn) return null;
  return '/img?w=' + (width || 300) + '&u=' + encodeURIComponent(posterCdn);
}

/* ------------------------------------------------------------------ */
/* write path (experimental)                                           */
/* ------------------------------------------------------------------ */

const SAVE_URL = LB_ORIGIN + '/s/save-diary-entry';

/**
 * Post a diary entry using the member's own session cookie.
 *
 * Unsupported, cookie-based, and off by default. The relay only attempts this
 * when LB_SESSION_COOKIE is set. Field names and the 0-10 rating range were
 * read off a live film page, not inferred.
 */
/**
 * Build the form body exactly as Letterboxd's own log form would.
 *
 * Field names and the 0-10 range come from a live film page (see
 * fixtures/film-form-excerpt.html), not from guesswork. Rating on the device
 * is 0.5-5 stars, so it is doubled here.
 */
function buildLogBody(film, opts) {
  const rating = opts.rating == null ? 0 : Math.round(Number(opts.rating) * 2);
  const form = new URLSearchParams();
  form.set('__csrf', film.csrf || '');
  form.set('viewingId', '');
  form.set('viewingableUid', film.uid || '');
  form.set('specifiedDate', 'true');
  form.set('viewingDateStr', opts.watchedDate || '');
  form.set('rating', String(Math.max(0, Math.min(10, rating))));
  form.set('rewatch', opts.rewatch ? 'true' : '');
  form.set('liked', opts.liked ? 'true' : '');
  form.set('review', opts.review || '');
  form.set('tags', opts.tags || '');
  form.set('containsSpoilers', opts.spoilers ? 'true' : '');
  return form.toString();
}

async function submitLog(opts) {
  const cookie = opts.cookie || process.env.LB_SESSION_COOKIE || '';
  if (!cookie) {
    return {
      ok: false,
      reason: 'no_session',
      detail:
        'No Letterboxd session cookie configured on the relay. Drafts still ' +
        'save on the device; use CSV export to import them officially.',
    };
  }

  let film;
  try {
    film = parseFilm((await fetchFilm(opts.slug, cookie)).html, opts.slug);
  } catch (e) {
    return { ok: false, reason: 'film_unreachable', detail: String(e.message) };
  }

  if (!film.uid) {
    return {
      ok: false,
      reason: 'no_uid',
      detail: 'Film page did not expose a viewingable uid.',
    };
  }
  if (!film.signedIn) {
    return {
      ok: false,
      reason: 'session_not_valid',
      detail:
        'Letterboxd rendered a placeholder CSRF token, so that cookie is not ' +
        'signed in (or has expired).',
    };
  }

  const body = buildLogBody(film, opts);

  let res;
  try {
    res = await request(SAVE_URL, {
      method: 'POST',
      headers: {
        Cookie: cookie,
        'Content-Type': 'application/x-www-form-urlencoded',
        Origin: 'https://letterboxd.com',
        Referer: FILM_URL(opts.slug),
        Accept: 'text/html,application/xhtml+xml',
      },
      body,
    });
  } catch (e) {
    return { ok: false, reason: 'network', detail: String(e.message) };
  }

  const ok = res.status === 200 || res.status === 302;
  return {
    ok,
    status: res.status,
    reason: ok ? 'submitted' : 'rejected',
    detail: ok
      ? 'Letterboxd accepted the form post (unverified end-to-end; check your diary).'
      : 'Letterboxd returned HTTP ' + res.status + '.',
    uid: film.uid,
  };
}

/* ------------------------------------------------------------------ */

module.exports = {
  UA,
  HANDLE_RE,
  parseHandle,
  request,
  decodeEntities,
  stripTags,
  paragraphs,
  parseFeed,
  fetchFeed,
  parseFilm,
  fetchFilm,
  parseRuntime,
  imageUrl,
  fetchImage,
  proxyPath,
  buildLogBody,
  submitLog,
  FEED_URL,
  FILM_URL,
  SAVE_URL,
};
