'use strict';

/*
 * Rebuilds the bundled fixtures from live Letterboxd. Run this when the demo
 * feed should move; the relay itself never needs it.
 *
 *   node relay/fixtures/build.js [handle]
 */

const fs = require('fs');
const path = require('path');
const lb = require('../lb');

const HANDLE = process.argv[2] || 'kerthfyadao';
const OUT = __dirname;

async function main() {
  const feed = await lb.fetchFeed(HANDLE);
  const parsed = lb.parseFeed(feed.xml, HANDLE);
  const snapshot = {
    handle: HANDLE,
    member: parsed.member,
    fetchedAt: feed.fetchedAt,
    counts: parsed.counts,
    items: parsed.items,
  };
  fs.writeFileSync(
    path.join(OUT, 'feed-' + HANDLE + '.json'),
    JSON.stringify(snapshot, null, 1)
  );
  console.log(
    'feed-' + HANDLE + '.json',
    parsed.counts.diary + ' diary,',
    parsed.counts.lists + ' lists'
  );

  const filmRes = await lb.fetchFilm('the-marvels');
  const film = lb.parseFilm(filmRes.html, 'the-marvels');
  const filmSnapshot = Object.assign({ ok: true }, film, {
    fetchedAt: filmRes.fetchedAt,
    poster: lb.proxyPath(film.posterCdn, 300),
    posterLarge: lb.proxyPath(film.posterCdn, 600),
  });
  delete filmSnapshot.html;
  fs.writeFileSync(
    path.join(OUT, 'film-the-marvels.json'),
    JSON.stringify(filmSnapshot, null, 1)
  );
  console.log('film-the-marvels.json', film.title, film.rating, film.runtime + 'min');

  // A frozen snippet of the real log form, used to prove the write path's
  // field names and CSRF handling without touching the live site.
  const html = filmRes.html;
  const uidScript = /<script[^>]*>[\s\S]*?viewingable\.uid[\s\S]*?<\/script>/i.exec(html);
  const form = /<form\b[^>]*save-diary-entry[\s\S]*?<\/form>/i.exec(html);
  if (!form) throw new Error('no log form in film page');
  const excerpt =
    (uidScript ? uidScript[0] : '') + '\n' + form[0];
  fs.writeFileSync(path.join(OUT, 'film-form-excerpt.html'), excerpt);
  console.log('film-form-excerpt.html', excerpt.length + 'B');
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
