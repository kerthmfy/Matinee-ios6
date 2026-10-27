'use strict';

/*
 * DOM smoke tests for the browser mock.
 *
 * The app is loaded into jsdom with a stubbed relay, then driven the way a
 * person would: open a film, rate it, cancel, check the tabs. This is the suite
 * that catches "the sheet re-animates on every star tap" class of bugs.
 *
 *   node test/dom-smoke.js
 */

const fs = require('fs');
const path = require('path');
const { JSDOM } = require('jsdom');
const { test, eq, ok, notOk, includes, report } = require('./_assert');

const ROOT = path.join(__dirname, '..');
const feed = JSON.parse(fs.readFileSync(path.join(ROOT, 'relay', 'fixtures', 'feed-kerthfyadao.json'), 'utf8'));
const film = JSON.parse(fs.readFileSync(path.join(ROOT, 'relay', 'fixtures', 'film-the-marvels.json'), 'utf8'));
const appSource = fs.readFileSync(path.join(ROOT, 'web', 'app.js'), 'utf8');
const html = fs.readFileSync(path.join(ROOT, 'web', 'index.html'), 'utf8')
  .replace('<script src="app.js"></script>', '');

const HEALTH = {
  ok: true,
  service: 'matinee-relay',
  version: '1.0.0',
  member: 'kerthfyadao',
  source: 'live',
  session: false,
  tmdb: false,
  images: { entries: 0, bytes: 0 },
};

function response(body, status) {
  return {
    ok: (status || 200) < 400,
    status: status || 200,
    json: async () => body,
  };
}

const dom = new JSDOM(html, {
  url: 'http://127.0.0.1:3000/',
  runScripts: 'dangerously',
  pretendToBeVisual: true,
  beforeParse(window) {
    window.fetch = async (url) => {
      const u = String(url);
      if (u.indexOf('/api/health') === 0) return response(HEALTH);
      if (u.indexOf('/api/feed') === 0) return response(Object.assign({ source: 'live' }, feed));
      if (u.indexOf('/api/film') === 0) return response(film);
      if (u.indexOf('/api/search') === 0) return response({ ok: false, reason: 'tmdb_key_missing' }, 503);
      return response({ reason: 'not_stubbed', url: u }, 500);
    };
  },
});

const { window } = dom;
const { document } = window;

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function waitFor(fn, label) {
  for (let i = 0; i < 160; i++) {
    const value = fn();
    if (value) return value;
    await sleep(25);
  }
  throw new Error('timed out: ' + label);
}

function $(selector) {
  return document.querySelector('#phone ' + selector);
}

function $$(selector) {
  return [...document.querySelectorAll('#phone ' + selector)];
}

function click(el) {
  ok(el, 'element to click');
  el.dispatchEvent(new window.MouseEvent('click', { bubbles: true, cancelable: true }));
}

function text(el) {
  return (el && el.textContent) || '';
}

async function main() {
  window.eval(appSource);
  document.dispatchEvent(new window.Event('DOMContentLoaded'));
  await waitFor(() => window.__matinee && window.__matinee.state.feed, 'feed load');

  const state = window.__matinee.state;

  /* ---------- boot / diary ---------- */

  test('relay health is read on boot', () => {
    eq(state.health.service, 'matinee-relay');
    eq(state.health.member, 'kerthfyadao');
  });

  test('feed loads and keeps lists out of the diary', () => {
    eq(state.feed.counts.diary, 50);
    eq(state.feed.counts.lists, 5);
    eq(state.feed.source, 'live');
  });

  test('diary rows are rendered for the phone', () => {
    const rows = $$('.row');
    ok(rows.length >= 10, 'rows: ' + rows.length);
    includes(text(rows[0]), 'Ready or Not 2');
  });

  test('the diary nav is the mark only, no wordmark', () => {
    const title = $('.nav-title');
    eq(title.className, 'nav-title logo-only');
    ok(title.querySelector('.nav-mark svg'), 'mark');
    notOk(title.querySelector('.nav-label'), 'no label');
    eq(text(title).trim(), '');
  });

  test('a four-star entry paints four green stars', () => {
    const row = $$('.row')[0];
    // Every star carries a green path, but the clip rect is what makes it
    // visible. Four full rects = four filled stars.
    eq(row.querySelectorAll('svg defs rect[width="24"]').length, 4);
    eq(row.querySelectorAll('svg').length, 5);
  });

  /* ---------- film detail + log sheet ---------- */

  const marvel = $$('.row').find((r) => text(r).indexOf('The Marvels') !== -1);
  click(marvel);
  await waitFor(() => $('.detail-title'), 'film view');

  test('rows open the film detail view', () => {
    includes(text($('.detail-title')), 'The Marvels');
    includes(text($('.detail-year')), '2023');
  });

  click($('[data-role=log-film]'));

  test('the log sheet opens with the existing rating', () => {
    ok($('[data-role=log-sheet]'), 'sheet');
    eq(text($('[data-role=log-caption]')), '3.5 of 5');
    eq($$('[data-role=log-star]').length, 5);
    eq(text($('.sheet-film-sub')), '2023 · Film');
  });

  test('the sheet does not show a slug or a long URL', () => {
    notOk(text($('[data-role=log-sheet]')).indexOf('letterboxd.com/film/') !== -1, 'slug leaked');
  });

  test('the sheet poster is the CDN image, no dark backing block', () => {
    const poster = $('.sheet-poster');
    ok(poster, 'poster frame');
    const img = poster.querySelector('img');
    ok(img, 'poster image');
    ok(img.getAttribute('src').indexOf('https://a.ltrbxd.com') === 0, 'cdn src');
  });

  test('star taps repaint in place and never re-render the sheet', () => {
    const sheet = $('[data-role=log-sheet]');
    const star = $$('[data-role=log-star]')[1];
    click(star);
    eq(text($('[data-role=log-caption]')), '2.0 of 5');
    ok($('[data-role=log-sheet]') === sheet, 'same sheet node');
    click(star);
    eq(text($('[data-role=log-caption]')), 'Tap a star to rate');
    ok($('[data-role=log-sheet]') === sheet, 'still the same node');
  });

  test('the sheet body is at scroll top when mounted', () => {
    eq($('.sheet-body').scrollTop, 0);
  });

  test('cancel closes the sheet', () => {
    click($('[data-role=log-cancel]'));
    notOk($('[data-role=log-sheet]'), 'sheet closed');
  });

  /* ---------- tabs ---------- */

  test('profile has no redundant Connect nav button', () => {
    click($('[data-tab=profile]'));
    ok($('.profile-name'), 'profile rendered');
    notOk($('[data-role=nav-connect]'), 'nav connect');
    const labels = [...document.querySelectorAll('#phone .navbar button')].map(text).join(' ');
    notOk(labels.indexOf('Connect') !== -1, 'no Connect button');
  });

  test('search explains the missing TMDB key', () => {
    click($('[data-tab=search]'));
    ok($('[data-role=search-unconfigured]'), 'search note');
    includes(text($('[data-role=search-unconfigured]')), 'TMDB');
  });

  /* ---------- export ---------- */

  test('csv export matches the Letterboxd importer columns', () => {
    const csv = window.__matinee.toCSV([{
      slug: 'the-marvels',
      tmdbId: '609681',
      title: 'A, B',
      year: 2023,
      rating: 3.5,
      watchedDate: '2026-01-02',
      rewatch: true,
      tags: 'marvel',
      review: 'say "hi"\nbye',
    }]);
    includes(csv, 'LetterboxdURI,tmdbID,imdbID,Title,Year,Directors,Rating,Rating10,WatchedDate,Rewatch,Tags,Review');
    includes(csv, '"A, B"');
    includes(csv, ',7,2026-01-02,Yes,marvel,');
    includes(csv, '"say ""hi""\nbye"');
    ok(csv.slice(-2) === '\r\n', 'trailing CRLF');
  });

  const fails = report('dom-smoke');
  dom.window.close();
  process.exit(fails ? 1 : 0);
}

main().catch((err) => {
  console.error('dom-smoke: fatal ' + (err && err.stack ? err.stack : err));
  process.exit(1);
});
