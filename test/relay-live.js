'use strict';

/*
 * Live tests against letterboxd.com. These are the ones that catch upstream
 * drift: a renamed RSS tag, a moved JSON-LD block, a changed resize path.
 *
 *   node test/relay-live.js
 */

const lb = require('../relay/lb');
const { test, testAsync, runAsync, eq, ok, includes } = require('./_assert');

const HANDLE = process.argv[2] || 'kerthfyadao';

async function main() {
  const feedRes = await lb.fetchFeed(HANDLE);
  const parsed = lb.parseFeed(feedRes.xml, HANDLE);

  test('RSS returns 200 and parses', () => {
    eq(feedRes.status, 200);
    ok(parsed.items.length > 0, 'items');
  });

  test('feed identifies the member', () => {
    ok(parsed.member && parsed.member.length > 0, 'member');
  });

  test('diary and list items are separated', () => {
    const diary = parsed.items.filter((i) => i.kind === 'diary');
    const lists = parsed.items.filter((i) => i.kind === 'list');
    console.log('       ' + parsed.counts.diary + ' diary, ' + parsed.counts.lists + ' lists');
    ok(diary.length > 0, 'diary');
    ok(lists.length > 0, 'lists');
    eq(diary.length + lists.length, parsed.items.length);
  });

  const diary = parsed.items.filter((i) => i.kind === 'diary');
  const first = diary[0];

  test('every diary item has the fields the UI renders', () => {
    for (const item of diary) {
      ok(item.id, 'id');
      ok(item.title, 'title');
      ok(/^\d{4}-\d{2}-\d{2}$/.test(item.watchedDate), 'watchedDate ' + item.id);
      ok(item.slug, 'slug ' + item.id);
      ok(item.link.indexOf('/film/') !== -1, 'link ' + item.id);
    }
  });

  test('posters are present for at least 90% of entries', () => {
    const withPoster = diary.filter((i) => i.posterCdn).length;
    console.log('       ' + withPoster + '/' + diary.length + ' with posters');
    ok(withPoster / diary.length >= 0.9, 'poster coverage');
  });

  test('poster host is the expected CDN', () => {
    for (const item of diary) {
      if (item.posterCdn) includes(item.posterCdn, 'a.ltrbxd.com', 'poster host');
    }
  });

  test('ratings are in the half-star range', () => {
    for (const item of diary) {
      if (item.rating == null) continue;
      ok(item.rating >= 0.5 && item.rating <= 5, 'rating out of range: ' + item.rating);
      eq(item.rating * 2, Math.round(item.rating * 2), 'half-step');
    }
  });

  test('the auto-generated watch stamp is not treated as a review', () => {
    for (const item of diary) {
      ok(!/^(?:re)?watched on .*\d{4}\.??$/i.test(item.review), 'stamp leaked: ' + item.review);
    }
  });

  test('lists carry entries and a real total', () => {
    const list = parsed.items.find((i) => i.kind === 'list');
    ok(list.entries.length > 0, 'entries');
    ok(list.total >= list.entries.length, 'total');
  });

  test('first entry looks sane', () => {
    console.log('       ' + first.title + ' (' + first.year + ') ★' + first.rating + ' ' + first.watchedDate);
    ok(first.year >= 1888, 'year');
  });

  /* film page */
  const filmRes = await lb.fetchFilm('the-marvels');
  const film = lb.parseFilm(filmRes.html, 'the-marvels');

  test('film page returns 200 and has JSON-LD', () => {
    eq(filmRes.status, 200);
    ok(film.parsed, 'JSON-LD parsed');
  });

  test('film metadata is complete', () => {
    eq(film.title, 'The Marvels');
    eq(film.year, 2023);
    eq(film.runtime, 105);
    eq(film.rating, 2.4);
    ok(film.directors.length > 0, 'directors');
    ok(film.cast.length > 0, 'cast');
    ok(film.genres.length > 0, 'genres');
    ok(film.synopsis.length > 40, 'synopsis');
  });

  test('film page exposes the uid needed to log', () => {
    ok(/^film:\d+$/.test(film.uid || ''), 'uid: ' + film.uid);
    ok(film.loggable, 'loggable');
  });

  test('signed-out sessions are detected', () => {
    eq(film.csrf, 'placeholder');
    eq(film.signedIn, false);
  });

  /* images */
  test('image allowlist rejects foreign hosts', () => {
    eq(lb.imageUrl('https://evil.example/a.jpg', 300), null);
    eq(lb.imageUrl('http://a.ltrbxd.com/a-0-600-0-900-crop.jpg', 300), null);
  });

  test('poster resize path is rewritten to the requested width', () => {
    const url = lb.imageUrl(first.posterCdn, 300);
    ok(url.indexOf('-0-300-0-450-crop') !== -1, 'width rewrite: ' + url);
    ok(url.indexOf('-0-600-0-900-crop') === -1, 'old size gone');
  });

  testAsync('proxied poster is a real JPEG', async () => {
    const img = await lb.fetchImage(lb.imageUrl(first.posterCdn, 300));
    eq(img.status, 200);
    includes(img.contentType, 'image/jpeg', 'content type');
    ok(img.body.length > 2000, 'body size ' + img.body.length);
    eq(img.body[0], 0xff);
    eq(img.body[1], 0xd8);
  });

  const fails = await runAsync('relay-live');
  process.exit(fails ? 1 : 0);
}

main().catch((err) => {
  console.error('relay-live: fatal ' + err.message);
  process.exit(1);
});
