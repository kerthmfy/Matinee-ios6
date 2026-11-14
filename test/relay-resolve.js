'use strict';

/*
 * Resolve integration test: TMDB-style title -> Letterboxd slug.
 *
 * The relay's /api/resolve route runs against a local HTTPS server that
 * serves the Letterboxd search page and film pages. It proves the search
 * page is scraped for slugs, candidates are verified by title and year,
 * dead candidates are skipped, and challenges, misses, and empty queries
 * are distinguished. Every test uses a unique title because the relay
 * caches successful resolutions in process.
 *
 *   node test/relay-resolve.js
 */

const fs = require('fs');
const path = require('path');
const { testAsync, runAsync, eq, ok } = require('./_assert');
const { listen, close, startTls } = require('./_tls');

function filmPage(title, year) {
  return '<html><head>'
    + '<script type="application/ld+json">'
    + JSON.stringify({
      '@context': 'https://schema.org',
      name: title,
      image: 'https://a.ltrbxd.com/poster.jpg',
      dateCreated: year + '-01-01',
    })
    + '</script></head><body></body></html>';
}

function searchPage(slugs) {
  return '<html><body>'
    + slugs.map((s) => '<div class="film-poster" data-film-slug="' + s + '"></div>').join('')
    + '</body></html>';
}

const CACHE_DIR = path.join(__dirname, '..', 'relay', '.cache');

function dropDiskCache(slug) {
  const file = path.join(CACHE_DIR, 'film-' + slug + '.json');
  try { fs.unlinkSync(file); } catch (e) { /* absent is fine */ }
}

async function main() {
  let searchMode = 'ok';
  const seen = [];

  const films = {
    'showcase-film': { title: 'Showcase Film', year: '2023' },
    'unrelated-film': { title: 'Something Else', year: '2023' },
    'older-marvels': { title: 'Year Skip', year: '1998' },
    'year-skip': { title: 'Year Skip', year: '2023' },
    'dead-skip': { title: 'Dead Skip', year: '2023' },
    'cache-probe': { title: 'Cache Probe', year: '2020' },
  };

  const letterboxd = await startTls((req, res) => {
    seen.push(req.url);
    function finish(status, headers, body) {
      res.writeHead(status, headers);
      res.end(body);
    }

    if (req.method === 'GET' && req.url.startsWith('/search/')) {
      if (searchMode === 'challenge') {
        return finish(403, { 'Content-Type': 'text/html', 'cf-mitigated': 'challenge' },
          '<html><head><title>Just a moment...</title></head></html>');
      }
      if (searchMode === 'http500') return finish(500, { 'Content-Type': 'text/html' }, 'nope');
      if (searchMode === 'empty') {
        return finish(200, { 'Content-Type': 'text/html; charset=utf-8' }, '<html><body></body></html>');
      }
      if (searchMode === 'two') {
        return finish(200, { 'Content-Type': 'text/html; charset=utf-8' },
          searchPage(['older-marvels', 'year-skip']));
      }
      if (searchMode === 'dead-first') {
        return finish(200, { 'Content-Type': 'text/html; charset=utf-8' },
          searchPage(['gone-film', 'dead-skip']));
      }
      if (searchMode === 'cache') {
        return finish(200, { 'Content-Type': 'text/html; charset=utf-8' },
          searchPage(['cache-probe']));
      }
      return finish(200, { 'Content-Type': 'text/html; charset=utf-8' },
        searchPage(['showcase-film', 'unrelated-film']));
    }

    if (req.method === 'GET' && req.url.startsWith('/film/')) {
      const slug = decodeURIComponent(req.url.slice('/film/'.length).replace(/\/$/, ''));
      if (slug === 'gone-film') return finish(404, { 'Content-Type': 'text/html' }, 'missing');
      const film = films[slug];
      if (film) {
        return finish(200, { 'Content-Type': 'text/html; charset=utf-8' },
          filmPage(film.title, film.year));
      }
    }

    return finish(404, { 'Content-Type': 'text/plain' }, 'not found');
  });

  process.env.MATINEE_LB_ORIGIN = letterboxd.origin;
  process.env.MATINEE_INSECURE_TLS = '1';
  process.env.LB_SESSION_COOKIE = 'letterboxd.signed.in.as=test-cookie';
  delete process.env.MATINEE_OFFLINE;
  delete process.env.TMDB_API_KEY;
  delete process.env.MATINEE_TMDB_ORIGIN;
  delete process.env.LB_USER_AGENT;

  const { createServer } = require('../relay/server');
  const relay = createServer();
  const port = await listen(relay);
  const base = 'http://127.0.0.1:' + port;

  async function getJson(pathname) {
    const res = await fetch(base + pathname);
    return { res, body: await res.json() };
  }

  function reset(mode) {
    searchMode = mode || 'ok';
    seen.length = 0;
    for (const slug of Object.keys(films).concat(['gone-film'])) {
      dropDiskCache(slug);
    }
  }

  /* ---------- happy path ---------- */

  testAsync('resolve matches title and year through the film page', async () => {
    reset();
    const { res, body } = await getJson('/api/resolve?title=Showcase%20Film&year=2023');
    eq(res.status, 200);
    eq(body.ok, true);
    eq(body.slug, 'showcase-film');
    eq(body.title, 'Showcase Film');
    eq(body.year, 2023);
    ok(body.poster, 'poster proxy path present');
    ok(seen.some((u) => u.startsWith('/search/')), 'search page was fetched');
    ok(seen.includes('/film/showcase-film/'), 'film page verified the match');
  });

  testAsync('resolve is cached per title and year', async () => {
    reset('cache');
    await getJson('/api/resolve?title=Cache%20Probe&year=2020');
    const searches = seen.filter((u) => u.startsWith('/search/')).length;
    await getJson('/api/resolve?title=Cache%20Probe&year=2020');
    eq(searches, 1, 'second resolve reuses the cached match');
  });

  testAsync('resolve skips a candidate whose year disagrees', async () => {
    reset('two');
    const { res, body } = await getJson('/api/resolve?title=Year%20Skip&year=2023');
    eq(res.status, 200);
    eq(body.slug, 'year-skip');
    ok(seen.includes('/film/older-marvels/'), 'older candidate was checked first');
  });

  testAsync('resolve skips a dead candidate and matches the next', async () => {
    reset('dead-first');
    const { res, body } = await getJson('/api/resolve?title=Dead%20Skip&year=2023');
    eq(res.status, 200);
    eq(body.slug, 'dead-skip');
  });

  testAsync('resolve reports a miss when the year disagrees', async () => {
    reset();
    const { res, body } = await getJson('/api/resolve?title=Showcase%20Film&year=1998');
    eq(res.status, 404);
    eq(body.ok, false);
    eq(body.reason, 'not_found');
  });

  testAsync('resolve reports a miss when the search page has no films', async () => {
    reset('empty');
    const { res, body } = await getJson('/api/resolve?title=Empty%20Probe&year=2023');
    eq(res.status, 404);
    eq(body.ok, false);
    eq(body.reason, 'not_found');
  });

  testAsync('resolve surfaces a Cloudflare challenge', async () => {
    reset('challenge');
    const { res, body } = await getJson('/api/resolve?title=Challenge%20Probe&year=2023');
    eq(res.status, 502);
    eq(body.ok, false);
    eq(body.reason, 'challenge');
    ok(body.detail.indexOf('cf_clearance') !== -1, 'detail names the fix');
  });

  testAsync('resolve surfaces an upstream HTTP failure', async () => {
    reset('http500');
    const { res, body } = await getJson('/api/resolve?title=Error%20Probe&year=2023');
    eq(res.status, 502);
    eq(body.reason, 'search_unavailable');
  });

  testAsync('resolve requires a title', async () => {
    reset();
    const { res, body } = await getJson('/api/resolve');
    eq(res.status, 400);
    eq(body.reason, 'empty_title');
  });

  const fails = await runAsync('letterboxd resolve');
  await close(relay);
  await letterboxd.stop();
  process.exit(fails ? 1 : 0);
}

main().catch((err) => {
  console.error('relay-resolve: fatal ' + (err && err.stack ? err.stack : err));
  process.exit(1);
});
