'use strict';

/*
 * Direct-write integration test.
 *
 * This is the closest we can get to a real log post without a member's
 * Letterboxd cookie: the relay's own submitLog() runs against a local HTTPS
 * server that serves the captured film form with a signed-in CSRF token and
 * records the form POST. It proves the cookie is forwarded, the uid/CSRF are
 * parsed, the body fields are right, and success/rejection are distinguished.
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
const signedInHtml = excerpt.replace('value="placeholder"', 'value="test-csrf"');

async function main() {
  let mode = 'signedin';
  let postStatus = 200;
  const seen = [];

  const letterboxd = await startTls((req, res) => {
    const record = {
      method: req.method,
      url: req.url,
      headers: req.headers,
      body: '',
    };
    seen.push(record);

    if (req.method === 'GET' && req.url === '/film/the-marvels/') {
      if (mode === 'missing') {
        res.writeHead(404, { 'Content-Type': 'text/html' });
        res.end('missing');
        return;
      }
      res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
      res.end(mode === 'signedout' ? excerpt : signedInHtml);
      return;
    }

    if (req.method === 'POST' && req.url === '/s/save-diary-entry') {
      const chunks = [];
      req.on('data', (c) => chunks.push(c));
      req.on('end', () => {
        record.body = Buffer.concat(chunks).toString('utf8');
        res.writeHead(postStatus, { 'Content-Type': 'text/html; charset=utf-8' });
        res.end(postStatus === 200 ? 'saved' : 'nope');
      });
      return;
    }

    res.writeHead(404, { 'Content-Type': 'text/plain' });
    res.end('not found');
  });

  process.env.MATINEE_LB_ORIGIN = letterboxd.origin;
  process.env.MATINEE_INSECURE_TLS = '1';
  process.env.LB_SESSION_COOKIE = 'letterboxd.signed.in=test-cookie';
  process.env.MATINEE_OFFLINE = '1';
  delete process.env.TMDB_API_KEY;
  delete process.env.MATINEE_TMDB_ORIGIN;

  const lb = require('../relay/lb');
  const { createServer } = require('../relay/server');
  const relay = createServer();
  const relayPort = await listen(relay);
  const base = 'http://127.0.0.1:' + relayPort;

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
    eq(lb.SAVE_URL, letterboxd.origin + '/s/save-diary-entry');
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

  testAsync('a signed-in form is posted with the captured fields', async () => {
    mode = 'signedin';
    postStatus = 200;
    seen.length = 0;
    const result = await lb.submitLog({
      slug: 'the-marvels',
      cookie: 'letterboxd.signed.in=test-cookie',
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
    eq(result.uid, 'film:536970');

    const get = seen.find((r) => r.method === 'GET');
    ok(get, 'film GET');
    eq(get.url, '/film/the-marvels/');
    eq(get.headers.cookie, 'letterboxd.signed.in=test-cookie');

    const post = seen.find((r) => r.method === 'POST');
    ok(post, 'save POST');
    eq(post.url, '/s/save-diary-entry');
    eq(post.headers.cookie, 'letterboxd.signed.in=test-cookie');
    eq(post.headers.origin, 'https://letterboxd.com');
    eq(post.headers.referer, letterboxd.origin + '/film/the-marvels/');
    includes(post.headers['content-type'], 'application/x-www-form-urlencoded');

    const form = new URLSearchParams(post.body);
    eq(form.get('__csrf'), 'test-csrf');
    eq(form.get('viewingId'), '');
    eq(form.get('viewingableUid'), 'film:536970');
    eq(form.get('specifiedDate'), 'true');
    eq(form.get('viewingDateStr'), '2026-10-24');
    eq(form.get('rating'), '8');
    eq(form.get('rewatch'), 'true');
    eq(form.get('liked'), 'true');
    eq(form.get('review'), 'line one & "quotes"');
    eq(form.get('tags'), 'marvel, 35mm');
    eq(form.get('containsSpoilers'), 'true');
  });

  testAsync('/api/log uses the relay session cookie and maps the body', async () => {
    mode = 'signedin';
    postStatus = 200;
    seen.length = 0;
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
    const get = seen.find((r) => r.method === 'GET');
    const post = seen.find((r) => r.method === 'POST');
    eq(get.headers.cookie, 'letterboxd.signed.in=test-cookie');
    const form = new URLSearchParams(post.body);
    eq(form.get('rating'), '10');
    eq(form.get('viewingDateStr'), '2026-10-25');
    eq(form.get('review'), 'route review');
    eq(form.get('liked'), 'true');
    eq(form.get('rewatch'), '');
  });

  testAsync('a 403 from Letterboxd is reported as rejected, not success', async () => {
    mode = 'signedin';
    postStatus = 403;
    seen.length = 0;
    const result = await lb.submitLog({
      slug: 'the-marvels',
      cookie: 'letterboxd.signed.in=test-cookie',
      rating: 3,
    });
    eq(result.ok, false);
    eq(result.status, 403);
    eq(result.reason, 'rejected');
    ok(seen.some((r) => r.method === 'POST'), 'POST was attempted');
  });

  testAsync('a placeholder CSRF is detected before the save POST', async () => {
    mode = 'signedout';
    postStatus = 200;
    seen.length = 0;
    const result = await lb.submitLog({
      slug: 'the-marvels',
      cookie: 'letterboxd.signed.in=expired',
      rating: 3,
    });
    eq(result.ok, false);
    eq(result.reason, 'session_not_valid');
    ok(seen.some((r) => r.method === 'GET'), 'film GET was attempted');
    notOk(seen.some((r) => r.method === 'POST'), 'no save POST');
  });

  testAsync('an unreachable film page is reported as film_unreachable', async () => {
    mode = 'missing';
    seen.length = 0;
    const result = await lb.submitLog({
      slug: 'the-marvels',
      cookie: 'letterboxd.signed.in=test-cookie',
      rating: 3,
    });
    eq(result.ok, false);
    eq(result.reason, 'film_unreachable');
    notOk(seen.some((r) => r.method === 'POST'), 'no save POST');
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
