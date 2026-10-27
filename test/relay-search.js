'use strict';

/*
 * TMDB search integration test.
 *
 * The relay is pointed at a local self-signed HTTPS server that speaks the
 * same /3/search/multi response shape as TMDB. This proves the configured
 * search path (key present, query encoded, results mapped, posters proxied)
 * without needing a real TMDB key.
 *
 *   node test/relay-search.js
 */

const fs = require('fs');
const path = require('path');
const { testAsync, runAsync, eq, ok, notOk, includes } = require('./_assert');
const { listen, close, startTls } = require('./_tls');

const fixture = JSON.parse(
  fs.readFileSync(path.join(__dirname, '..', 'relay', 'fixtures', 'tmdb-search.json'), 'utf8')
);

async function main() {
  const seen = [];
  const tmdb = await startTls((req, res) => {
    seen.push({ url: req.url, headers: req.headers });
    const u = new URL(req.url, 'https://tmdb.test');
    const query = u.searchParams.get('query');

    if (query === 'fail') {
      res.writeHead(500, { 'Content-Type': 'application/json' });
      res.end('{"error":"upstream"}');
      return;
    }
    if (query === 'bad-json') {
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end('not json');
      return;
    }
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify(fixture));
  });

  process.env.TMDB_API_KEY = 'test-key';
  process.env.MATINEE_TMDB_ORIGIN = tmdb.origin;
  process.env.MATINEE_INSECURE_TLS = '1';
  process.env.MATINEE_OFFLINE = '1';
  delete process.env.LB_SESSION_COOKIE;

  const { createServer } = require('../relay/server');
  const relay = createServer();
  const port = await listen(relay);
  const base = 'http://127.0.0.1:' + port;

  async function getJson(pathname) {
    const res = await fetch(base + pathname);
    const body = await res.json();
    return { res, body };
  }

  testAsync('health advertises configured search', async () => {
    const { body } = await getJson('/api/health');
    eq(body.tmdb, true);
  });

  testAsync('configured search maps movie and TV results', async () => {
    const { res, body } = await getJson('/api/search?q=' + encodeURIComponent('marvel & tv'));
    eq(res.status, 200);
    eq(body.ok, true);
    eq(body.query, 'marvel & tv');
    eq(body.count, 3);
    eq(body.results.length, 3);

    const movie = body.results[0];
    eq(movie.kind, 'movie');
    eq(movie.tmdbId, 609681);
    eq(movie.title, 'The Marvels');
    eq(movie.year, 2023);
    eq(movie.rating, 5.9);
    ok(movie.overview.length > 0, 'overview');
    ok(movie.posterCdn.indexOf('https://image.tmdb.org/t/p/w342/') === 0, 'poster cdn');
    includes(movie.poster, '/img?w=300&u=');
    notOk(movie.poster.indexOf('https://') === 0, 'poster is proxied');

    const tv = body.results[1];
    eq(tv.kind, 'tv');
    eq(tv.tmdbId, 1399);
    eq(tv.title, 'Game of Thrones');
    eq(tv.year, 2011);
    eq(tv.rating, 8.4);

    const bare = body.results[2];
    eq(bare.kind, 'movie');
    eq(bare.year, null);
    eq(bare.rating, null);
    eq(bare.posterCdn, null);
    eq(bare.poster, null);
  });

  testAsync('the TMDB request carries the key, encoded query, and filters', async () => {
    seen.length = 0;
    const { body } = await getJson('/api/search?q=' + encodeURIComponent('marvel & tv'));
    eq(body.count, 3);
    eq(seen.length, 1);
    const u = new URL(seen[0].url, 'https://tmdb.test');
    eq(u.pathname, '/3/search/multi');
    eq(u.searchParams.get('api_key'), 'test-key');
    eq(u.searchParams.get('query'), 'marvel & tv');
    eq(u.searchParams.get('include_adult'), 'false');
    eq(u.searchParams.get('language'), 'en-US');
    eq(u.searchParams.get('page'), '1');
    includes(seen[0].headers.accept, 'application/json');
  });

  testAsync('an empty query is rejected before the upstream call', async () => {
    seen.length = 0;
    const { res, body } = await getJson('/api/search?q=');
    eq(res.status, 501);
    eq(body.reason, 'empty_query');
    eq(seen.length, 0);
  });

  testAsync('a TMDB HTTP failure becomes a stable relay error', async () => {
    const { res, body } = await getJson('/api/search?q=fail');
    eq(res.status, 501);
    eq(body.ok, false);
    eq(body.reason, 'tmdb_http_500');
  });

  testAsync('malformed TMDB JSON becomes search_failed', async () => {
    const { res, body } = await getJson('/api/search?q=bad-json');
    eq(res.status, 502);
    eq(body.ok, false);
    eq(body.reason, 'search_failed');
    eq(body.detail, 'tmdb_bad_json');
  });

  testAsync('untrusted query text is only ever sent as a query parameter', async () => {
    seen.length = 0;
    const evil = 'x/../../s/save-diary-entry?api_key=leak';
    const { res } = await getJson('/api/search?q=' + encodeURIComponent(evil));
    eq(res.status, 200);
    const u = new URL(seen[0].url, 'https://tmdb.test');
    eq(u.pathname, '/3/search/multi');
    eq(u.searchParams.get('query'), evil);
    eq(u.searchParams.get('api_key'), 'test-key');
  });

  const fails = await runAsync('relay-search');
  await close(relay);
  await tmdb.stop();
  process.exit(fails ? 1 : 0);
}

main().catch((err) => {
  console.error('relay-search: fatal ' + (err && err.stack ? err.stack : err));
  process.exit(1);
});
