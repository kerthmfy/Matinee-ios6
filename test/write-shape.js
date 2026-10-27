'use strict';

/*
 * Write-path tests.
 *
 * These do not touch the network. They prove the shape of the film JSON we
 * read and the JSON log entry we post, so a field rename on Letterboxd's side
 * shows up as a failing test rather than a silent 200 with no diary entry.
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

/* ---------- parsing the real film page ---------- */

test('film excerpt exposes the viewingable uid', () => {
  eq(film.uid, 'film:536970');
});

test('film excerpt is recognised as loggable', () => {
  ok(film.loggable, 'loggable');
});

test('a page without person.loggedIn is treated as signed out', () => {
  notOk(film.signedIn, 'signedIn');
});

const signedInExcerpt = excerpt +
  "<script>supermodelCSRF = 'test-csrf'; person.loggedIn = true;</script>";
const signedInFilm = lb.parseFilm(signedInExcerpt, 'the-marvels');

test('a signed-in page is detected from person.loggedIn', () => {
  ok(signedInFilm.signedIn, 'signedIn');
  eq(signedInFilm.csrf, 'test-csrf');
});

/* ---------- the film JSON endpoint ---------- */

const filmJson = JSON.stringify({
  result: true,
  csrf: 'json-csrf',
  lid: '6YA',
  uid: 'film:2682',
  type: 'film',
  typeName: 'film',
  slug: 'primer',
  name: 'Primer',
  releaseYear: 2004,
});
const meta = lb.parseFilmJson(filmJson);

test('film JSON exposes the production lid and fresh CSRF', () => {
  ok(meta, 'parsed');
  eq(meta.lid, '6YA');
  eq(meta.csrf, 'json-csrf');
  eq(meta.uid, 'film:2682');
  eq(meta.slug, 'primer');
  eq(meta.name, 'Primer');
});

test('film JSON must be an object with result true', () => {
  eq(lb.parseFilmJson('<html>Just a moment...</html>'), null);
  eq(lb.parseFilmJson('{'), null);
  eq(lb.parseFilmJson(JSON.stringify({ result: false, lid: '6YA' })), null);
  eq(lb.parseFilmJson(null), null);
});

test('a missing lid or CSRF is surfaced as null, not invented', () => {
  const bare = lb.parseFilmJson(JSON.stringify({ result: true }));
  eq(bare.lid, null);
  eq(bare.csrf, null);
});

/* ---------- log-entry construction ---------- */

const base = { watchedDate: '2026-10-23', review: 'aura', rating: 3.5 };

function entry(extra) {
  return lb.buildLogEntry(meta, Object.assign({}, base, extra || {}));
}

test('productionId is the film lid, not the uid or slug', () => {
  eq(entry().productionId, '6YA');
});

test('ratings stay in stars; they are not doubled', () => {
  eq(entry({ rating: 4 }).rating, 4);
  eq(entry({ rating: 3.5 }).rating, 3.5);
  eq(entry({ rating: 0.5 }).rating, 0.5);
});

test('an unrated log omits rating instead of posting zero', () => {
  notOk('rating' in entry({ rating: null }), 'rating key');
  notOk('rating' in entry({ rating: 0 }), 'zero rating key');
  notOk('rating' in entry({ rating: 'nope' }), 'invalid rating key');
});

test('ratings are clamped to 0.5-5 and rounded to half stars', () => {
  eq(entry({ rating: 5.5 }).rating, 5);
  eq(entry({ rating: -2 }).rating, undefined);
  eq(entry({ rating: 4.8 }).rating, 5);
  eq(entry({ rating: 0.1 }).rating, 0.5);
});

test('diaryDetails carries the ISO date and rewatch flag', () => {
  eq(entry({ rewatch: true }).diaryDetails, {
    diaryDate: '2026-10-23',
    rewatch: true,
  });
  eq(entry({ rewatch: false }).diaryDetails, {
    diaryDate: '2026-10-23',
    rewatch: false,
  });
});

test('an undated log has no diaryDetails', () => {
  const undated = entry({ watchedDate: '' });
  notOk('diaryDetails' in undated, 'diaryDetails key');
});

test('like is always a boolean', () => {
  eq(entry({ liked: true }).like, true);
  eq(entry({ liked: false }).like, false);
  eq(entry().like, false);
});

test('review becomes an object with containsSpoilers', () => {
  eq(entry({ review: 'line one\nline two & "quotes"', spoilers: true }).review, {
    text: 'line one\nline two & "quotes"',
    containsSpoilers: true,
  });
  eq(entry({ spoilers: false }).review, {
    text: 'aura',
    containsSpoilers: false,
  });
});

test('a blank review is omitted entirely', () => {
  notOk('review' in entry({ review: '' }), 'empty review key');
  notOk('review' in entry({ review: '   \n ' }), 'whitespace review key');
  notOk('review' in entry({ review: null }), 'null review key');
});

test('tags split on commas, trim, and drop duplicates', () => {
  eq(entry({ tags: 'marvel, 35mm' }).tags, ['marvel', '35mm']);
  eq(entry({ tags: ' marvel , , 35mm, Marvel ' }).tags, ['marvel', '35mm']);
  eq(entry({ tags: '' }).tags, []);
  eq(entry({ tags: null }).tags, []);
});

test('tags already in an array are preserved in order', () => {
  eq(entry({ tags: ['netflix', '35mm'] }).tags, ['netflix', '35mm']);
});

test('the entry never carries the cookie, uid, or CSRF token', () => {
  const e = entry();
  notOk('csrf' in e, 'csrf');
  notOk('uid' in e, 'uid');
  notOk('cookie' in e, 'cookie');
  eq(Object.keys(e).sort(), ['diaryDetails', 'like', 'productionId', 'rating', 'review', 'tags']);
});

test('the serialized body matches the endpoint contract', () => {
  const body = JSON.parse(JSON.stringify(entry({
    rating: 4,
    watchedDate: '2026-10-24',
    review: 'line one & "quotes"',
    rewatch: true,
    liked: true,
    tags: 'marvel, 35mm',
    spoilers: true,
  })));
  eq(body, {
    productionId: '6YA',
    tags: ['marvel', '35mm'],
    like: true,
    rating: 4,
    diaryDetails: { diaryDate: '2026-10-24', rewatch: true },
    review: { text: 'line one & "quotes"', containsSpoilers: true },
  });
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
  eq(lb.FILM_JSON_URL('the-marvels'), 'https://letterboxd.com/film/the-marvels/json/');
  eq(lb.LOG_ENTRY_URL, 'https://letterboxd.com/api/v0/production-log-entries');
});

test('the relay has a modern default UA and honors the env override', () => {
  includes(lb.DEFAULT_UA, 'Mozilla/5.0');
  includes(lb.UA, 'Mozilla/5.0');
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
