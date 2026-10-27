'use strict';

/*
 * Direct-write integration test.
 *
 * This is the closest we can get to a real log post without a member's
 * Letterboxd cookie: the relay's own submitLog() runs against a local HTTPS
 * server that serves the captured film page, the film JSON endpoint, and the
 * production-log-entries API. It proves the cookie is forwarded, the lid and
 * fresh CSRF are used, the JSON body is right, and success, rejection,
 * challenge, and expired-session responses are distinguished.
 *
 *   node test/relay-write.js
 */

const fs = require('fs');
const path = require('path');
const { testAsync, runAsync, eq, ok, notOk, includes } = require('./_assert');
const { listen, close, startTls } = require('./_tls');

const excerpt = fs.readFileSync(
  path.join(__dirname, '..', 'relay', 'fixtures', 'film-form-excerpt.html'),
  'utf8'
);
const signedInHtml = excerpt +
  "<script>supermodelCSRF = 'test-csrf'; person.loggedIn = true;</script>";
const signedInWithoutToken =
  "<script>data.viewingable.uid = 'film:536970'; person.loggedIn = true;</script>";

async function main() {
  let mode = 'signedin';
  let jsonMode = 'ok';
  let postStatus = 200;
  let postChallenge = false;
  let postCsrfFail = false;
  const seen = [];

  const letterboxd = await startTls((req, res) => {
    const record = {
      method: req.method,
      url: req.url,
      headers: req.headers,
      body: '',
    };

    function finish(status, headers, body) {
      res.writeHead(status, headers);
      res.end(body);
    }

    if (req.method === 'GET') {
      seen.push(record);
      if (req.url === '/film/the-marvels/' || req.url === '/film/primer/') {
        if (mode === 'missing') return finish(404, { 'Content-Type': 'text/html' }, 'missing');
        if (mode === 'signedout') return finish(200, { 'Content-Type': 'text/html' }, excerpt);
        if (mode === 'signedin-nocsrf') {
          return finish(200, { 'Content-Type': 'text/html' }, signedInWithoutToken);
        }
        return finish(200, { 'Content-Type': 'text/html; charset=utf-8' }, signedInHtml);
      }
      if (req.url === '/film/the-marvels/json/') {
        if (jsonMode === 'missing') return finish(404, { 'Content-Type': 'text/html' }, 'missing');
        if (jsonMode === 'malformed') return finish(200, { 'Content-Type': 'text/html' }, '<html>nope</html>');
        if (jsonMode === 'challenge') {
          return finish(403, { 'Content-Type': 'text/html', 'cf-mitigated': 'challenge' },
            '<html><head><title>Just a moment...</title></head></html>');
        }
        if (jsonMode === 'nolid') {
          return finish(200, { 'Content-Type': 'application/json' },
            JSON.stringify({ result: true, csrf: 'json-csrf', uid: 'film:536970' }));
        }
        if (jsonMode === 'nocsrf') {
          return finish(200, { 'Content-Type': 'application/json' },
            JSON.stringify({ result: true, lid: '6YA', uid: 'film:536970' }));
        }
        return finish(200, { 'Content-Type': 'application/json' }, JSON.stringify({
          result: true,
          csrf: 'json-csrf',
          lid: '6YA',
          uid: 'film:536970',
          type: 'film',
          typeName: 'film',
          slug: 'the-marvels',
          name: 'The Marvels',
        }));
      }
    }

    if (req.method === 'POST' && req.url === '/api/v0/production-log-entries') {
      seen.push(record);
      const chunks = [];
      req.on('data', (c) => chunks.push(c));
      req.on('end', () => {
        record.body = Buffer.concat(chunks).toString('utf8');
        if (postChallenge) {
          return finish(403, { 'Content-Type': 'text/html', 'cf-mitigated': 'challenge' },
            '<html><head><title>Just a moment...</title></head></html>');
        }
        if (postCsrfFail) {
          return finish(403, { 'Content-Type': 'text/plain' }, 'Invalid CSRF token');
        }
        if (postStatus === 200) {
          return finish(200, { 'Content-Type': 'application/json' }, JSON.stringify({
            logEntry: {
              id: 'log123',
              name: 'test diary entry',
              production: { id: '6YA' },
            },
          }));
        }
        return finish(postStatus, { 'Content-Type': 'application/json' },
          JSON.stringify({ error: true, message: 'Invalid rating' }));
      });
      return;
    }

    res.writeHead(404, { 'Content-Type': 'text/plain' });
    res.end('not found');
  });

  process.env.MATINEE_LB_ORIGIN = letterboxd.origin;
  process.env.MATINEE_INSECURE_TLS = '1';
  process.env.LB_SESSION_COOKIE = 'letterboxd.signed.in.as=test-cookie';
  process.env.MATINEE_OFFLINE = '1';
  delete process.env.TMDB_API_KEY;
  delete process.env.MATINEE_TMDB_ORIGIN;
  delete process.env.LB_USER_AGENT;

  const lb = require('../relay/lb');
  const { createServer } = require('../relay/server');
  const relay = createServer();
  const relayPort = await listen(relay);
  const base = 'http://127.0.0.1:' + relayPort;

  function reset(overrides) {
    mode = 'signedin';
    jsonMode = 'ok';
    postStatus = 200;
    postChallenge = false;
    postCsrfFail = false;
    seen.length = 0;
    if (overrides) {
      if (overrides.mode) mode = overrides.mode;
      if (overrides.jsonMode) jsonMode = overrides.jsonMode;
      if (overrides.postStatus) postStatus = overrides.postStatus;
      if (overrides.postChallenge) postChallenge = overrides.postChallenge;
      if (overrides.postCsrfFail) postCsrfFail = overrides.postCsrfFail;
    }
  }

  async function postLog(value) {
    const res = await fetch(base + '/api/log', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(value),
    });
    const body = await res.json();
    return { res, body };
  }

  testAsync('the test origins point at the local Letterboxd mock', () => {
    includes(lb.FILM_URL('the-marvels'), letterboxd.origin);
    includes(lb.FILM_JSON_URL('the-marvels'), letterboxd.origin);
    eq(lb.LOG_ENTRY_URL, letterboxd.origin + '/api/v0/production-log-entries');
  });

  testAsync('no session cookie returns before any network request', async () => {
    const previous = process.env.LB_SESSION_COOKIE;
    delete process.env.LB_SESSION_COOKIE;
    seen.length = 0;
    const result = await lb.submitLog({ slug: 'the-marvels', rating: 3 });
    eq(result.ok, false);
    eq(result.reason, 'no_session');
    eq(seen.length, 0);
    process.env.LB_SESSION_COOKIE = previous;
  });

  testAsync('a signed-in page and film JSON produce a JSON log entry', async () => {
    reset();
    const result = await lb.submitLog({
      slug: 'the-marvels',
      cookie: 'letterboxd.signed.in.as=test-cookie',
      rating: 4,
      watchedDate: '2026-10-24',
      review: 'line one & "quotes"',
      rewatch: true,
      liked: true,
      tags: 'marvel, 35mm',
      spoilers: true,
    });

    eq(result.ok, true);
    eq(result.status, 200);
    eq(result.reason, 'submitted');
    eq(result.id, 'log123');
    eq(result.uid, 'film:536970');
    eq(result.lid, '6YA');

    const page = seen.find((r) => r.method === 'GET' && r.url === '/film/the-marvels/');
    const meta = seen.find((r) => r.method === 'GET' && r.url === '/film/the-marvels/json/');
    ok(page, 'film page GET');
    ok(meta, 'film JSON GET');
    eq(page.headers.cookie, 'letterboxd.signed.in.as=test-cookie');
    eq(meta.headers.cookie, 'letterboxd.signed.in.as=test-cookie');
    includes(meta.headers.accept, 'application/json');

    const post = seen.find((r) => r.method === 'POST');
    ok(post, 'log-entry POST');
    eq(post.url, '/api/v0/production-log-entries');
    eq(post.headers.cookie, 'letterboxd.signed.in.as=test-cookie');
    eq(post.headers.origin, letterboxd.origin);
    eq(post.headers.referer, letterboxd.origin + '/film/the-marvels/');
    includes(post.headers['content-type'], 'application/json');
    eq(post.headers['x-csrf-token'], 'json-csrf');
    includes(post.headers.accept, 'application/json');

    eq(JSON.parse(post.body), {
      productionId: '6YA',
      tags: ['marvel', '35mm'],
      like: true,
      rating: 4,
      diaryDetails: { diaryDate: '2026-10-24', rewatch: true },
      review: { text: 'line one & "quotes"', containsSpoilers: true },
    });
  });

  testAsync('/api/log uses the relay session cookie and maps the body', async () => {
    reset();
    const { res, body } = await postLog({
      slug: 'the-marvels',
      rating: 5,
      watchedDate: '2026-10-25',
      review: 'route review',
      rewatch: false,
      liked: true,
    });
    eq(res.status, 200);
    eq(body.ok, true);
    eq(body.reason, 'submitted');
    eq(body.id, 'log123');

    const page = seen.find((r) => r.method === 'GET' && r.url === '/film/the-marvels/');
    const post = seen.find((r) => r.method === 'POST');
    eq(page.headers.cookie, 'letterboxd.signed.in.as=test-cookie');
    eq(post.headers['x-csrf-token'], 'json-csrf');
    eq(JSON.parse(post.body), {
      productionId: '6YA',
      tags: [],
      like: true,
      rating: 5,
      diaryDetails: { diaryDate: '2026-10-25', rewatch: false },
      review: { text: 'route review', containsSpoilers: false },
    });
  });

  testAsync('a rejected log entry is not reported as success', async () => {
    reset({ postStatus: 422 });
    const result = await lb.submitLog({
      slug: 'the-marvels',
      cookie: 'letterboxd.signed.in.as=test-cookie',
      rating: 3,
    });
    eq(result.ok, false);
    eq(result.status, 422);
    eq(result.reason, 'rejected');
    eq(result.detail, 'Invalid rating');
    ok(seen.some((r) => r.method === 'POST'), 'POST was attempted');
  });

  testAsync('a Cloudflare challenge is surfaced as challenge with UA guidance', async () => {
    reset({ postChallenge: true });
    const result = await lb.submitLog({
      slug: 'the-marvels',
      cookie: 'letterboxd.signed.in.as=test-cookie',
      rating: 3,
    });
    eq(result.ok, false);
    eq(result.status, 403);
    eq(result.reason, 'challenge');
    includes(result.detail, 'LB_USER_AGENT');
    includes(result.detail, 'LB_SESSION_COOKIE');
  });

  testAsync('an invalid CSRF response is surfaced as no_csrf', async () => {
    reset({ postCsrfFail: true });
    const result = await lb.submitLog({
      slug: 'the-marvels',
      cookie: 'letterboxd.signed.in.as=test-cookie',
      rating: 3,
    });
    eq(result.ok, false);
    eq(result.status, 403);
    eq(result.reason, 'no_csrf');
  });

  testAsync('a signed-out page is detected before the film JSON or save POST', async () => {
    reset({ mode: 'signedout' });
    const result = await lb.submitLog({
      slug: 'the-marvels',
      cookie: 'letterboxd.signed.in.as=expired',
      rating: 3,
    });
    eq(result.ok, false);
    eq(result.reason, 'session_not_valid');
    ok(seen.some((r) => r.method === 'GET'), 'film GET was attempted');
    notOk(seen.some((r) => r.url === '/film/the-marvels/json/'), 'no film JSON GET');
    notOk(seen.some((r) => r.method === 'POST'), 'no save POST');
  });

  testAsync('an unreachable film page is reported as film_unreachable', async () => {
    reset({ mode: 'missing' });
    const result = await lb.submitLog({
      slug: 'the-marvels',
      cookie: 'letterboxd.signed.in.as=test-cookie',
      rating: 3,
    });
    eq(result.ok, false);
    eq(result.reason, 'film_unreachable');
    notOk(seen.some((r) => r.method === 'POST'), 'no save POST');
  });

  testAsync('an unreachable film JSON is reported as film_unreachable', async () => {
    reset({ jsonMode: 'missing' });
    const result = await lb.submitLog({
      slug: 'the-marvels',
      cookie: 'letterboxd.signed.in.as=test-cookie',
      rating: 3,
    });
    eq(result.ok, false);
    eq(result.status, 404);
    eq(result.reason, 'film_unreachable');
    notOk(seen.some((r) => r.method === 'POST'), 'no save POST');
  });

  testAsync('malformed film JSON is reported as film_json_invalid', async () => {
    reset({ jsonMode: 'malformed' });
    const result = await lb.submitLog({
      slug: 'the-marvels',
      cookie: 'letterboxd.signed.in.as=test-cookie',
      rating: 3,
    });
    eq(result.ok, false);
    eq(result.reason, 'film_json_invalid');
    notOk(seen.some((r) => r.method === 'POST'), 'no save POST');
  });

  testAsync('film JSON without a lid is reported as no_lid', async () => {
    reset({ jsonMode: 'nolid' });
    const result = await lb.submitLog({
      slug: 'the-marvels',
      cookie: 'letterboxd.signed.in.as=test-cookie',
      rating: 3,
    });
    eq(result.ok, false);
    eq(result.reason, 'no_lid');
    notOk(seen.some((r) => r.method === 'POST'), 'no save POST');
  });

  testAsync('a session with no CSRF anywhere is reported as no_csrf', async () => {
    reset({ mode: 'signedin-nocsrf', jsonMode: 'nocsrf' });
    const result = await lb.submitLog({
      slug: 'the-marvels',
      cookie: 'letterboxd.signed.in.as=test-cookie',
      rating: 3,
    });
    eq(result.ok, false);
    eq(result.reason, 'no_csrf');
    notOk(seen.some((r) => r.method === 'POST'), 'no save POST');
  });

  testAsync('a challenged film JSON request is reported as challenge', async () => {
    reset({ jsonMode: 'challenge' });
    const result = await lb.submitLog({
      slug: 'the-marvels',
      cookie: 'letterboxd.signed.in.as=test-cookie',
      rating: 3,
    });
    eq(result.ok, false);
    eq(result.status, 403);
    eq(result.reason, 'challenge');
    notOk(seen.some((r) => r.method === 'POST'), 'no save POST');
  });

  async function getSession() {
    const res = await fetch(base + '/api/session');
    const body = await res.json();
    return { res, body };
  }

  testAsync('/api/session reports no cookie as unconfigured', async () => {
    const previous = process.env.LB_SESSION_COOKIE;
    delete process.env.LB_SESSION_COOKIE;
    seen.length = 0;
    const { res, body } = await getSession();
    eq(res.status, 200);
    eq(body.ok, true);
    eq(body.configured, false);
    eq(body.signedIn, false);
    eq(body.reason, 'no_session');
    eq(seen.length, 0);
    process.env.LB_SESSION_COOKIE = previous;
  });

  testAsync('/api/session accepts a signed-in cookie', async () => {
    reset();
    const { res, body } = await getSession();
    eq(res.status, 200);
    eq(body.configured, true);
    eq(body.signedIn, true);
    eq(body.reason, 'signed_in');
    eq(body.slug, 'primer');
    const page = seen.find((r) => r.method === 'GET');
    eq(page.url, '/film/primer/');
    eq(page.headers.cookie, 'letterboxd.signed.in.as=test-cookie');
  });

  testAsync('/api/session rejects an expired cookie with session_not_valid', async () => {
    reset({ mode: 'signedout' });
    const { res, body } = await getSession();
    eq(res.status, 200);
    eq(body.configured, true);
    eq(body.signedIn, false);
    eq(body.reason, 'session_not_valid');
    notOk(seen.some((r) => r.method === 'POST'), 'no save POST');
  });

  testAsync('/api/session surfaces a network failure without claiming invalid', async () => {
    reset({ mode: 'missing' });
    const { res, body } = await getSession();
    eq(res.status, 200);
    eq(body.configured, true);
    eq(body.signedIn, false);
    eq(body.reason, 'network');
    ok(body.detail, 'detail is present');
  });

  testAsync('the HTTP route still no-sessions when the env cookie is absent', async () => {
    delete process.env.LB_SESSION_COOKIE;
    seen.length = 0;
    const { res, body } = await postLog({ slug: 'the-marvels', rating: 4 });
    eq(res.status, 502);
    eq(body.reason, 'no_session');
    eq(seen.length, 0);
  });

  const fails = await runAsync('relay-write');
  await close(relay);
  await letterboxd.stop();
  process.exit(fails ? 1 : 0);
}

main().catch((err) => {
  console.error('relay-write: fatal ' + (err && err.stack ? err.stack : err));
  process.exit(1);
});
