'use strict';

/*
 * Deeper browser-mock flows.
 *
 * dom-smoke.js covers the original visual regressions (stars, sheet mount,
 * logo-only nav). This suite follows the paths a person actually takes:
 * search -> log -> draft, connect, lists, and the iPad split view with its
 * real back controls.
 *
 *   node test/dom-flows.js
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
  tmdb: true,
  images: { entries: 0, bytes: 0 },
};

const SEARCH = {
  ok: true,
  query: 'marvel',
  count: 2,
  results: [
    {
      tmdbId: 609681,
      kind: 'movie',
      title: 'The Marvels',
      year: 2023,
      rating: 5.9,
      overview: 'Carol Danvers gets her powers entangled.',
      posterCdn: 'https://image.tmdb.org/t/p/w342/9GBhzXMFjgcZ3FdR9w3bUMMTps5.jpg',
      poster: '/img?w=300&u=test',
    },
    {
      tmdbId: 1399,
      kind: 'tv',
      title: 'Game of Thrones',
      year: 2011,
      rating: 8.4,
      overview: 'Seven noble families fight for control.',
      posterCdn: null,
      poster: null,
    },
  ],
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
      if (u.indexOf('/api/search') === 0) {
        if (u.indexOf('q=fail') !== -1) {
          return response({ ok: false, reason: 'search_failed', detail: 'upstream down' }, 502);
        }
        return response(SEARCH);
      }
      if (u.indexOf('/api/connect') === 0) {
        return response({
          ok: true,
          handle: 'kerthfyadao',
          member: 'kerthfyadao',
          counts: feed.counts,
          source: 'live',
        });
      }
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
  for (let i = 0; i < 200; i++) {
    const value = fn();
    if (value) return value;
    await sleep(25);
  }
  throw new Error('timed out: ' + label);
}

function $(selector, root) {
  return (root || document).querySelector(selector);
}

function $$(selector, root) {
  return [...(root || document).querySelectorAll(selector)];
}

function phone(selector) {
  return $('#phone ' + selector);
}

function phoneAll(selector) {
  return $$('#phone ' + selector);
}

function pad(selector) {
  return $('#ipad ' + selector);
}

function padAll(selector) {
  return $$('#ipad ' + selector);
}

function click(el) {
  ok(el, 'element to click');
  el.dispatchEvent(new window.MouseEvent('click', { bubbles: true, cancelable: true }));
}

function input(el, value) {
  ok(el, 'input element');
  el.value = value;
  el.dispatchEvent(new window.Event('input', { bubbles: true }));
}

function text(el) {
  return (el && el.textContent) || '';
}

function backLabel(root) {
  const back = root.querySelector('[data-role=nav-back]');
  return text(back && back.querySelector('.back-label'));
}

async function main() {
  window.eval(appSource);
  document.dispatchEvent(new window.Event('DOMContentLoaded'));
  await waitFor(() => window.__matinee && window.__matinee.state.feed, 'feed load');

  const state = window.__matinee.state;

  /* ---------- phone: real back control ---------- */

  click(phone('[data-role=feed-row]'));
  await waitFor(() => phone('[data-role=film-detail]'), 'phone film');
  test('phone film detail has a real back button labelled Diary', () => {
    eq(backLabel(phone('')), 'Diary');
    ok(phone('.nav-btn.back'), 'shaped back button');
    includes(text(phone('.nav-btn.back')), 'Diary');
  });
  click(phone('[data-role=nav-back]'));
  await waitFor(() => !phone('[data-role=film-detail]'), 'phone diary');

  /* ---------- lists ---------- */

  click(phone('[data-tab=lists]'));
  test('lists tab renders the five RSS lists', () => {
    eq(phoneAll('[data-role=list-row]').length, 5);
    includes(text(phone('.section-head')), '5 lists');
  });
  click(phone('[data-role=list-row]'));
  await waitFor(() => phone('[data-role=list-detail]'), 'list detail');
  test('list detail uses Lists as its back label', () => {
    eq(backLabel(phone('')), 'Lists');
    ok(phoneAll('[data-role=list-entry]').length > 0, 'entries');
  });
  click(phone('[data-role=list-entry]'));
  await waitFor(() => phone('[data-role=film-detail]'), 'film from list');
  test('a film opened from a list keeps the Lists back label', () => {
    eq(backLabel(phone('')), 'Lists');
  });
  click(phone('[data-role=nav-back]'));
  await waitFor(() => phoneAll('[data-role=list-row]').length === 5, 'back to lists');

  /* ---------- search -> log -> draft ---------- */

  click(phone('[data-tab=search]'));
  const searchInput = phone('[data-role=search-input]');
  ok(searchInput, 'search input');
  input(searchInput, 'marvel');
  click(phone('[data-role=search-go]'));
  await waitFor(() => phoneAll('[data-role=search-result]').length === 2, 'search results');

  test('configured search renders movie and TV results', () => {
    const rows = phoneAll('[data-role=search-result]');
    includes(text(rows[0]), 'The Marvels');
    includes(text(rows[0]), 'Film');
    includes(text(rows[1]), 'Game of Thrones');
    includes(text(rows[1]), 'TV');
    notOk(rows[1].querySelector('img'), 'missing poster becomes a placeholder');
  });

  click(phoneAll('[data-role=search-result]')[0]);
  await waitFor(() => phone('[data-role=log-sheet]'), 'search log sheet');
  test('a search result opens a clean draft sheet keyed by tmdbID', () => {
    eq(text(phone('.sheet-film-title')), 'The Marvels');
    eq(text(phone('[data-role=log-caption]')), 'Tap a star to rate');
    includes(text(phone('[data-role=log-sheet]')), 'Search result');
    notOk(text(phone('[data-role=log-sheet]')).indexOf('letterboxd.com/film/') !== -1, 'no slug');
  });
  click(phone('[data-role=save-draft]'));
  await waitFor(() => !phone('[data-role=log-sheet]'), 'draft saved');

  test('saving a search draft stores its tmdbID for CSV import', () => {
    eq(state.drafts.length, 1);
    eq(state.drafts[0].tmdbId, 609681);
    eq(state.drafts[0].title, 'The Marvels');
  });

  click(phone('[data-tab=profile]'));
  test('profile shows the saved draft count', () => {
    eq(text(phone('[data-role=draft-count]')), '1');
  });

  /* ---------- search failure ---------- */

  click(phone('[data-tab=search]'));
  input(phone('[data-role=search-input]'), 'fail');
  click(phone('[data-role=search-go]'));
  await waitFor(() => text(phone('[data-role=search-view]')).indexOf('upstream down') !== -1, 'search failure');
  test('a failed search shows the relay detail and stays on the tab', () => {
    includes(text(phone('[data-role=search-view]')), 'upstream down');
    ok(phone('[data-role=search-input]'), 'input still present');
  });

  /* ---------- connect sheet ---------- */

  click(phone('[data-tab=profile]'));
  click(phone('[data-role=open-connect]'));
  await waitFor(() => phone('[data-role=connect-sheet]'), 'connect sheet');
  test('connect sheet validates an empty handle locally', () => {
    click(phone('[data-role=connect-submit]'));
    includes(text(phone('[data-role=connect-error]')), 'Enter a handle');
  });
  input(phone('[data-role=connect-input]'), 'letterboxd.com/kerthfyadao');
  click(phone('[data-role=connect-submit]'));
  await waitFor(() => phone('[data-role=alert]'), 'connected alert');
  test('connect accepts a profile URL and refreshes the diary', () => {
    includes(text(phone('[data-role=alert]')), 'Connected');
    eq(state.handle, 'kerthfyadao');
    eq(state.tab, 'diary');
  });
  click(phone('.alert-actions button'));
  await waitFor(() => !phone('[data-role=alert]'), 'alert closed');

  /* ---------- iPad split view ---------- */

  click(pad('[data-tab=diary]'));
  click(pad('[data-role=feed-row]'));
  await waitFor(() => pad('[data-role=film-detail]'), 'iPad film');
  test('iPad film detail keeps a Diary back control in the right pane', () => {
    eq(backLabel(pad('')), 'Diary');
    ok(pad('[data-role=film-detail]'), 'right pane film');
    ok(pad('[data-role=feed-row]'), 'left pane diary still visible');
  });
  click(pad('[data-role=nav-back]'));
  await waitFor(() => !pad('[data-role=film-detail]'), 'iPad empty detail');

  click(pad('[data-tab=lists]'));
  click(pad('[data-role=list-row]'));
  await waitFor(() => pad('[data-role=list-detail]'), 'iPad list');
  test('iPad list detail uses the Lists back label', () => {
    eq(backLabel(pad('')), 'Lists');
    ok(pad('[data-role=list-entry]'), 'list entries');
  });

  /* ---------- installable web app ---------- */

  test('the document points at the manifest and Apple touch icon', () => {
    const manifest = $('link[rel=manifest]');
    ok(manifest, 'manifest link');
    eq(manifest.getAttribute('href'), 'manifest.webmanifest');
    const touch = $('link[rel=apple-touch-icon]');
    ok(touch, 'apple touch icon');
    eq(touch.getAttribute('href'), 'icon-180.png');
    eq($('meta[name=theme-color]').getAttribute('content'), '#171a1f');
  });

  const fails = report('dom-flows');
  dom.window.close();
  process.exit(fails ? 1 : 0);
}

main().catch((err) => {
  console.error('dom-flows: fatal ' + (err && err.stack ? err.stack : err));
  process.exit(1);
});
