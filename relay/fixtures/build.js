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

  // A frozen snippet of the real film page, used to prove uid/CSRF/session
  // parsing without touching the live site. Redact the token: it is session
  // bound and must never enter git or a screenshot.
  const html = filmRes.html;
  const uidScript = /<script[^>]*>[\s\S]*?viewingable\.uid[\s\S]*?<\/script>/i.exec(html);
  const form = /<form\b[^>]*save-diary-entry[\s\S]*?<\/form>/i.exec(html);
  if (!form) throw new Error('no log form in film page');
  const excerpt =
    (uidScript ? uidScript[0] : '') + '\n' + form[0];
  const redacted = excerpt.replace(
    /(supermodelCSRF\s*=\s*['"])[^'"]*([^'"]*['"])/g,
    '$1fixture-csrf$2'
  );
  fs.writeFileSync(path.join(OUT, 'film-form-excerpt.html'), redacted);
  console.log('film-form-excerpt.html', redacted.length + 'B (CSRF redacted)');
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
