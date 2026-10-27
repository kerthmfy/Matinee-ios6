'use strict';

/*
 * Write-path tests.
 *
 * These do not touch the network. They prove the shape of what would be posted
 * against a frozen copy of the real log form, so a field rename on Letterboxd's
 * side shows up as a failing test rather than a silent 200 with no diary entry.
 */

const fs = require('fs');
const path = require('path');

// Keep this suite on the production defaults even when an integration-test
// override is still exported in the shell.
delete process.env.MATINEE_LB_ORIGIN;
delete process.env.MATINEE_INSECURE_TLS;

const lb = require('../relay/lb');
const { test, testAsync, runAsync, eq, ok, notOk, includes } = require('./_assert');

const excerpt = fs.readFileSync(
  path.join(__dirname, '..', 'relay', 'fixtures', 'film-form-excerpt.html'),
  'utf8'
);

const film = lb.parseFilm(excerpt, 'the-marvels');

/* ---------- parsing the real form ---------- */

test('form excerpt exposes the viewingable uid', () => {
  eq(film.uid, 'film:536970');
});

test('form excerpt is recognised as loggable', () => {
  ok(film.loggable, 'loggable');
});

test('signed-out form is detected by its placeholder CSRF', () => {
  eq(film.csrf, 'placeholder');
  notOk(film.signedIn, 'signedIn');
});

test('form field names match the ones we submit', () => {
  const htmlNames = [...excerpt.matchAll(/<(?:input|textarea|select)\b[^>]*\bname="([^"]+)"/gi)]
    .map((m) => m[1]);
  const unique = [...new Set(htmlNames)].sort();
  const submitted = ['__csrf', 'viewingId', 'viewingableUid', 'specifiedDate', 'rewatch',
    'viewingDateStr', 'review', 'containsSpoilers', 'tags', 'rating', 'liked'].sort();
  eq(unique, submitted);
});

/* ---------- body construction ---------- */

const base = { watchedDate: '2026-10-23', review: 'aura', rating: 3.5 };

function body(extra) {
  return new URLSearchParams(lb.buildLogBody(film, Object.assign({}, base, extra || {})));
}

test('rating is doubled from stars to the 0-10 range', () => {
  eq(body({ rating: 4 }).get('rating'), '8');
});

test('half stars survive the doubling', () => {
  eq(body({ rating: 3.5 }).get('rating'), '7');
  eq(body({ rating: 0.5 }).get('rating'), '1');
});

test('an unrated log posts zero', () => {
  eq(body({ rating: null }).get('rating'), '0');
});

test('rating is clamped to 0-10', () => {
  eq(body({ rating: 5.5 }).get('rating'), '10');
  eq(body({ rating: -2 }).get('rating'), '0');
});

test('csrf token is forwarded', () => {
  eq(body().get('__csrf'), 'placeholder');
});

test('viewingId is empty for a new entry', () => {
  eq(body().get('viewingId'), '');
});

test('viewingableUid is the film uid, not the slug', () => {
  eq(body().get('viewingableUid'), 'film:536970');
});

test('date is sent both as a flag and as a date string', () => {
  eq(body().get('specifiedDate'), 'true');
  eq(body().get('viewingDateStr'), '2026-10-23');
});

test('rewatch and like map to the literal true', () => {
  eq(body({ rewatch: true }).get('rewatch'), 'true');
  eq(body({ rewatch: false }).get('rewatch'), '');
  eq(body({ liked: true }).get('liked'), 'true');
  eq(body({ liked: false }).get('liked'), '');
});

test('spoilers map to containsSpoilers', () => {
  eq(body({ spoilers: true }).get('containsSpoilers'), 'true');
  eq(body({ spoilers: false }).get('containsSpoilers'), '');
});

test('review text is preserved and encoded', () => {
  const b = body({ review: 'line one\nline two & "quotes"' });
  eq(b.get('review'), 'line one\nline two & "quotes"');
  includes(b.toString(), 'line+one');
});

test('tags are forwarded', () => {
  eq(body({ tags: 'netflix, 35mm' }).get('tags'), 'netflix, 35mm');
});

test('every field Letterboxd expects is present exactly once', () => {
  const params = body();
  const counts = {};
  for (const [k] of params) counts[k] = (counts[k] || 0) + 1;
  eq(Object.keys(counts).length, 11);
  ok(Object.values(counts).every((n) => n === 1), 'no duplicate fields');
});

/* ---------- session handling ---------- */

testAsync('no cookie means no network attempt at all', async () => {
  const previous = process.env.LB_SESSION_COOKIE;
  delete process.env.LB_SESSION_COOKIE;
  const res = await lb.submitLog({ slug: 'the-marvels', rating: 3 });
  if (previous === undefined) delete process.env.LB_SESSION_COOKIE;
  else process.env.LB_SESSION_COOKIE = previous;
  eq(res.ok, false);
  eq(res.reason, 'no_session');
});

/* ---------- handle parsing / SSRF boundary ---------- */

test('accepts a bare handle', () => {
  eq(lb.parseHandle('kerthfyadao'), 'kerthfyadao');
});

test('accepts an @handle', () => {
  eq(lb.parseHandle('@kerthfyadao'), 'kerthfyadao');
});

test('accepts a profile URL', () => {
  eq(lb.parseHandle('https://letterboxd.com/kerthfyadao/'), 'kerthfyadao');
});

test('accepts an RSS URL', () => {
  eq(lb.parseHandle('https://letterboxd.com/kerthfyadao/rss/'), 'kerthfyadao');
});

test('accepts a scheme-less pasted URL', () => {
  eq(lb.parseHandle('letterboxd.com/kerthfyadao/rss/'), 'kerthfyadao');
});

test('rejects a foreign host outright', () => {
  eq(lb.parseHandle('https://evil.example/kerthfyadao'), null);
});

test('rejects a path traversal attempt', () => {
  eq(lb.parseHandle('https://letterboxd.com/../../etc/passwd'), null);
});

test('rejects a handle with a slash injecting a path', () => {
  eq(lb.parseHandle('kerthfyadao/../../admin'), null);
});

test('rejects reserved site paths', () => {
  eq(lb.parseHandle('film'), null);
  eq(lb.parseHandle('import'), null);
});

test('rejects empty and non-string input', () => {
  eq(lb.parseHandle(''), null);
  eq(lb.parseHandle(null), null);
  eq(lb.parseHandle({}), null);
});

/* ---------- upstream origins and image allowlist ---------- */

test('production origins default to letterboxd.com', () => {
  eq(lb.FEED_URL('kerthfyadao'), 'https://letterboxd.com/kerthfyadao/rss/');
  eq(lb.FILM_URL('the-marvels'), 'https://letterboxd.com/film/the-marvels/');
  eq(lb.SAVE_URL, 'https://letterboxd.com/s/save-diary-entry');
});

test('only the two poster hosts over HTTPS are proxied', () => {
  ok(lb.imageUrl('https://a.ltrbxd.com/resized/film-poster/x-0-600-0-900-crop.jpg', 300));
  ok(lb.imageUrl('https://image.tmdb.org/t/p/w342/x.jpg', 300));
  eq(lb.imageUrl('http://a.ltrbxd.com/x.jpg', 300), null);
  eq(lb.imageUrl('https://evil.example/x.jpg', 300), null);
  eq(lb.imageUrl('https://a.ltrbxd.com.evil.example/x.jpg', 300), null);
  eq(lb.imageUrl('not a url', 300), null);
});

test('the image width is clamped and rewrites the crop path', () => {
  const small = lb.imageUrl('https://a.ltrbxd.com/resized/film-poster/1-0-600-0-900-crop.jpg', 1);
  includes(small, '-0-80-0-120-crop');
  const large = lb.imageUrl('https://a.ltrbxd.com/resized/film-poster/1-0-600-0-900-crop.jpg', 5000);
  includes(large, '-0-900-0-1350-crop');
});

/* ---------- summary ---------- */

runAsync('write-path').then((fails) => process.exit(fails ? 1 : 0));
