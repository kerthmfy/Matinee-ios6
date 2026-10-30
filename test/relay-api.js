'use strict';

/*
 * Relay HTTP integration tests, deterministic and offline.
 *
 * The real createServer() is started on an ephemeral port. MATINEE_OFFLINE=1
 * makes the feed/film routes read the bundled snapshots, so these tests can
 * assert exact counts without touching Letterboxd. No TMDB key or session
 * cookie is configured here; those paths are covered by relay-search.js and
 * relay-write.js against local HTTPS mocks.
 *
 *   node test/relay-api.js
 */

process.env.MATINEE_OFFLINE = '1';
delete process.env.TMDB_API_KEY;
delete process.env.LB_SESSION_COOKIE;
delete process.env.MATINEE_TMDB_ORIGIN;
delete process.env.MATINEE_LB_ORIGIN;

const http = require('http');
const { createServer } = require('../relay/server');
const { testAsync, runAsync, eq, ok, notOk, includes } = require('./_assert');
const { listen, close } = require('./_tls');

let base;
let port;

async function get(pathname, opts) {
  return fetch(base + pathname, opts);
}

async function getJson(pathname, opts) {
  const res = await get(pathname, opts);
  const body = await res.json();
  return { res, body };
}

async function postJson(pathname, value) {
  return getJson(pathname, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(value),
  });
}

function rawGet(pathname) {
  return new Promise((resolve, reject) => {
    const req = http.request(
      { hostname: '127.0.0.1', port, path: pathname, method: 'GET' },
      (res) => {
        const chunks = [];
        res.on('data', (c) => chunks.push(c));
        res.on('end', () => resolve({
          status: res.statusCode,
          headers: res.headers,
          body: Buffer.concat(chunks).toString('utf8'),
        }));
      }
    );
    req.on('error', reject);
    req.end();
  });
}

async function main() {
  const server = createServer();
  port = await listen(server);
  base = 'http://127.0.0.1:' + port;

  /* ---------- health and static app ---------- */

  testAsync('health reports the relay and disabled optional integrations', async () => {
    const { res, body } = await getJson('/api/health');
    eq(res.status, 200);
    eq(res.headers.get('cache-control'), 'no-store');
    eq(res.headers.get('access-control-allow-origin'), '*');
    eq(body.ok, true);
    eq(body.service, 'matinee-relay');
    eq(body.member, 'kerthfyadao');
    eq(body.tmdb, false);
    eq(body.session, false);
    eq(body.feed, null);
    ok(body.images && typeof body.images.entries === 'number', 'image stats');
  });

  testAsync('the relay root returns a JSON endpoint index', async () => {
    const { res, body } = await getJson('/');
    eq(res.status, 200);
    eq(res.headers.get('content-type'), 'application/json; charset=utf-8');
    eq(res.headers.get('cache-control'), 'no-store');
    eq(body.ok, true);
    eq(body.service, 'matinee-relay');
    ok(Array.isArray(body.endpoints), 'endpoints');
    includes(body.endpoints.join(','), '/api/health');
  });

  testAsync('unknown files and API routes return JSON 404s', async () => {
    const file = await getJson('/not-a-real-file.css');
    eq(file.res.status, 404);
    eq(file.res.headers.get('content-type'), 'application/json; charset=utf-8');
    eq(file.body.reason, 'not_found');

    const { res, body } = await getJson('/api/not-a-real-route');
    eq(res.status, 404);
    eq(body.reason, 'no_such_endpoint');
  });

  testAsync('path traversal cannot leak relay source', async () => {
    for (const candidate of [
      '/../relay/server.js',
      '/%2e%2e/relay/server.js',
      '/..%2frelay/server.js',
      '/%2e%2e%2frelay%2fserver.js',
    ]) {
      const res = await rawGet(candidate);
      notOk(res.status === 200, candidate + ' returned 200');
      notOk(res.body.indexOf('createServer') !== -1, candidate + ' leaked source');
    }
  });

  /* ---------- feed and film, from bundled fixtures ---------- */

  testAsync('feed returns the fixture counts and proxies every poster', async () => {
    const { res, body } = await getJson('/api/feed');
    eq(res.status, 200);
    eq(body.ok, true);
    eq(body.handle, 'kerthfyadao');
    eq(body.source, 'fixture');
    eq(body.counts.diary, 50);
    eq(body.counts.lists, 5);
    eq(body.items.length, 55);
    const diary = body.items.filter((i) => i.kind === 'diary');
    ok(diary.every((i) => !i.posterCdn || i.poster.indexOf('/img?w=300&u=') === 0), 'poster proxy');
  });

  testAsync('limit truncates to diary entries and never returns lists', async () => {
    const { res, body } = await getJson('/api/feed?limit=3');
    eq(res.status, 200);
    eq(body.truncated, true);
    eq(body.items.length, 3);
    ok(body.items.every((i) => i.kind === 'diary'), 'diary only');
    eq(body.counts.diary, 50);
  });

  testAsync('feed rejects invalid handles before any upstream request', async () => {
    for (const bad of ['../etc/passwd', 'film', 'https://evil.example/me']) {
      const { res, body } = await getJson('/api/feed?user=' + encodeURIComponent(bad));
      eq(res.status, 400);
      eq(body.reason, 'bad_handle');
    }
  });

  testAsync('film returns metadata and proxy poster paths', async () => {
    const { res, body } = await getJson('/api/film?slug=the-marvels');
    eq(res.status, 200);
    eq(body.ok, true);
    eq(body.source, 'fixture');
    eq(body.title, 'The Marvels');
    eq(body.year, 2023);
    eq(body.runtime, 105);
    eq(body.loggable, true);
    includes(body.poster, '/img?w=300&u=');
    includes(body.posterLarge, '/img?w=600&u=');
  });

  testAsync('film validates the slug and reports an unavailable fixture', async () => {
    const bad = await getJson('/api/film?slug=../server.js');
    eq(bad.res.status, 400);
    eq(bad.body.reason, 'bad_slug');

    const missing = await getJson('/api/film?slug=not-in-the-fixtures');
    eq(missing.res.status, 502);
    eq(missing.body.reason, 'film_unavailable');
  });

  /* ---------- search without a key ---------- */

  testAsync('search explains the missing TMDB key instead of scraping', async () => {
    const { res, body } = await getJson('/api/search?q=marvel');
    eq(res.status, 501);
    eq(body.ok, false);
    eq(body.reason, 'tmdb_key_missing');
    includes(body.detail, 'TMDB_API_KEY');
  });

  /* ---------- connect ---------- */

  testAsync('connect rejects malformed JSON and untrusted handles', async () => {
    const badJson = await getJson('/api/connect', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: '{',
    });
    eq(badJson.res.status, 400);
    eq(badJson.body.reason, 'bad_json');

    const badHandle = await postJson('/api/connect', { input: 'https://evil.example/me' });
    eq(badHandle.res.status, 400);
    eq(badHandle.body.reason, 'bad_handle');

    const empty = await postJson('/api/connect', { input: '' });
    eq(empty.res.status, 400);
    eq(empty.body.reason, 'bad_handle');
  });

  testAsync('connect accepts a profile URL and reports the fixture counts', async () => {
    const { res, body } = await postJson('/api/connect', {
      input: 'https://letterboxd.com/kerthfyadao/rss/',
    });
    eq(res.status, 200);
    eq(body.ok, true);
    eq(body.handle, 'kerthfyadao');
    eq(body.member, 'raklht');
    eq(body.source, 'fixture');
    eq(body.counts.diary, 50);
    eq(body.counts.lists, 5);
  });

  testAsync('connect returns a clear 404 for a handle with no fixture', async () => {
    const { res, body } = await postJson('/api/connect', { input: 'nobody-here' });
    eq(res.status, 404);
    eq(body.ok, false);
    eq(body.reason, 'no_public_feed');
  });

  /* ---------- write path without a session ---------- */

  testAsync('log refuses to run without a configured session cookie', async () => {
    const { res, body } = await postJson('/api/log', {
      slug: 'the-marvels',
      rating: 4,
      watchedDate: '2026-10-24',
    });
    eq(res.status, 502);
    eq(body.ok, false);
    eq(body.reason, 'no_session');
  });

  testAsync('log validates the slug before touching the session', async () => {
    const { res, body } = await postJson('/api/log', { slug: '../x', rating: 4 });
    eq(res.status, 400);
    eq(body.reason, 'bad_slug');
  });

  /* ---------- image allowlist / CORS ---------- */

  testAsync('the image proxy validates the u parameter and host allowlist', async () => {
    const missing = await getJson('/img');
    eq(missing.res.status, 400);
    eq(missing.body.reason, 'missing_u');

    for (const target of [
      'https://evil.example/poster.jpg',
      'http://a.ltrbxd.com/poster.jpg',
      'https://a.ltrbxd.com.evil.example/poster.jpg',
    ]) {
      const { res, body } = await getJson('/img?u=' + encodeURIComponent(target));
      eq(res.status, 403);
      eq(body.reason, 'host_not_allowed');
    }
  });

  testAsync('CORS preflight advertises the methods the mock uses', async () => {
    const res = await get('/api/feed', { method: 'OPTIONS' });
    eq(res.status, 204);
    eq(res.headers.get('access-control-allow-origin'), '*');
    includes(res.headers.get('access-control-allow-methods'), 'POST');
    includes(res.headers.get('access-control-allow-headers'), 'Content-Type');
  });

  testAsync('health now reports the cached fixture feed', async () => {
    const { body } = await getJson('/api/health');
    eq(body.feed.items, 55);
    eq(body.feed.source, 'fixture');
    ok(body.feed.fetchedAt, 'fetchedAt');
  });

  /* ---------- summary ---------- */

  const fails = await runAsync('relay-api');
  await close(server);
  process.exit(fails ? 1 : 0);
}

main().catch((err) => {
  console.error('relay-api: fatal ' + (err && err.stack ? err.stack : err));
  process.exit(1);
});
