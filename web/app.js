'use strict';

/* ==========================================================================
   Matinee 6 — iOS 6 browser mock
   One state tree, rendered into an iPhone 4S frame and an iPad 2 frame.
   The iPad gets a real two-pane split instead of a stretched phone column.
   ========================================================================== */

/* ---------- tiny DOM helpers ---------- */

function h(tag, props, ...kids) {
  const el = document.createElement(tag);
  if (props) {
    for (const k in props) {
      if (k === 'class') el.className = props[k];
      else if (k === 'style') Object.assign(el.style, props[k]);
      else if (k === 'html') el.innerHTML = props[k];
      else if (k === 'text') el.textContent = props[k];
      else if (k.startsWith('on') && typeof props[k] === 'function') {
        el.addEventListener(k.slice(2).toLowerCase(), props[k]);
      } else if (props[k] != null) el.setAttribute(k, props[k]);
    }
  }
  for (const kid of kids) {
    if (kid == null || kid === false) continue;
    el.appendChild(typeof kid === 'string' ? document.createTextNode(kid) : kid);
  }
  return el;
}

const MONTHS = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

function shortDate(iso) {
  if (!iso) return '';
  const m = /^(\d{4})-(\d{2})-(\d{2})/.exec(iso);
  if (!m) return iso;
  return parseInt(m[3], 10) + ' ' + MONTHS[parseInt(m[2], 10) - 1] + ' ' + m[1];
}

function todayISO() {
  const d = new Date();
  return (
    d.getFullYear() + '-' +
    String(d.getMonth() + 1).padStart(2, '0') + '-' +
    String(d.getDate()).padStart(2, '0')
  );
}

function plural(n, one, many) {
  return n + ' ' + (n === 1 ? one : many || one + 's');
}

/* ---------- icons ---------- */

let markerSeq = 0;

/*
 * The Matinee mark: three glossy orbs in a shallow arc, an iOS 6 reading of
 * the cinema-diary idea. The arc (rather than a flat row) is the twist, and
 * every orb is built from a radial base, a bottom bounce light and a hard
 * specular. Drawn, never an asset, so it stays crisp at 1x and 2x -- and the
 * same geometry is drawn in LBTheme.m on the device.
 */
function markSVG() {
  const uid = 'm' + ++markerSeq;
  const r = 7.9;
  const orbs = [
    { cx: 8.1, cy: 19.4, g: 'o' },
    { cx: 20, cy: 15.6, g: 'g' },
    { cx: 31.9, cy: 19.4, g: 'b' },
  ];

  const gradients =
    '<radialGradient id="o' + uid + '" cx="34%" cy="26%" r="82%">' +
      '<stop offset="0%" stop-color="#ffe2bd"/><stop offset="34%" stop-color="#ff9f36"/>' +
      '<stop offset="72%" stop-color="#fb7a05"/><stop offset="100%" stop-color="#cf4f00"/>' +
    '</radialGradient>' +
    '<radialGradient id="g' + uid + '" cx="34%" cy="26%" r="82%">' +
      '<stop offset="0%" stop-color="#b9ffd6"/><stop offset="34%" stop-color="#5cf09a"/>' +
      '<stop offset="72%" stop-color="#00d457"/><stop offset="100%" stop-color="#00963e"/>' +
    '</radialGradient>' +
    '<radialGradient id="b' + uid + '" cx="34%" cy="26%" r="82%">' +
      '<stop offset="0%" stop-color="#cdeeff"/><stop offset="34%" stop-color="#7fd2fa"/>' +
      '<stop offset="72%" stop-color="#35b4ef"/><stop offset="100%" stop-color="#0a78b8"/>' +
    '</radialGradient>' +
    '<radialGradient id="s' + uid + '" cx="50%" cy="50%" r="50%">' +
      '<stop offset="0%" stop-color="#fff" stop-opacity=".85"/>' +
      '<stop offset="55%" stop-color="#fff" stop-opacity=".26"/>' +
      '<stop offset="100%" stop-color="#fff" stop-opacity="0"/>' +
    '</radialGradient>' +
    '<radialGradient id="u' + uid + '" cx="50%" cy="100%" r="70%">' +
      '<stop offset="0%" stop-color="#fff" stop-opacity=".42"/>' +
      '<stop offset="70%" stop-color="#fff" stop-opacity="0"/>' +
    '</radialGradient>' +
    '<filter id="d' + uid + '" x="-40%" y="-40%" width="180%" height="180%">' +
      '<feDropShadow dx="0" dy="1.1" stdDeviation=".9" flood-color="#00172b" flood-opacity=".5"/>' +
    '</filter>';

  const bodies = orbs.map((o) =>
    '<circle cx="' + o.cx + '" cy="' + o.cy + '" r="' + r + '" fill="url(#' + o.g + uid + ')"/>' +
    '<circle cx="' + o.cx + '" cy="' + o.cy + '" r="' + r + '" fill="url(#u' + uid + ')"/>' +
    '<ellipse cx="' + (o.cx - 2.3) + '" cy="' + (o.cy - 3.6) + '" rx="4.3" ry="2.8" ' +
      'transform="rotate(-20 ' + (o.cx - 2.3) + ' ' + (o.cy - 3.6) + ')" fill="url(#s' + uid + ')"/>'
  ).join('');

  return (
    '<svg viewBox="0 0 40 32" aria-hidden="true">' +
    '<defs>' + gradients + '</defs>' +
    '<g filter="url(#d' + uid + ')">' + bodies + '</g>' +
    '</svg>'
  );
}

const ICON = {
  diary:
    '<svg viewBox="0 0 24 24" fill="currentColor" aria-hidden="true">' +
    '<path d="M6 3h12a1 1 0 011 1v16a1 1 0 01-1 1H6a2 2 0 01-2-2V5a2 2 0 012-2zm1 3v2h10V6H7zm0 4v2h10v-2H7zm0 4v2h7v-2H7z"/>' +
    '</svg>',
  lists:
    '<svg viewBox="0 0 24 24" fill="currentColor" aria-hidden="true">' +
    '<path d="M4 5h11v2H4V5zm0 4h11v2H4V9zm0 4h11v2H4v-2zm0 4h7v2H4v-2zM17 5h3v2h-3V5zm0 4h3v2h-3V9zm0 4h3v2h-3v-2z"/>' +
    '</svg>',
  search:
    '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true">' +
    '<circle cx="10.5" cy="10.5" r="6"/><path d="M15 15l5 5" stroke-linecap="round"/></svg>',
  profile:
    '<svg viewBox="0 0 24 24" fill="currentColor" aria-hidden="true">' +
    '<circle cx="12" cy="8" r="4"/><path d="M4 21c0-4.4 3.6-7 8-7s8 2.6 8 7H4z"/></svg>',
};

const STAR_PATH =
  'M12 2.6l2.9 6 6.6.9-4.8 4.6 1.2 6.5L12 17.5 6.1 20.6l1.2-6.5L2.5 9.5l6.6-.9z';

const STAR_GREEN = '#00c853';
const STAR_EMPTY = '#d0d4da';

/*
 * Stars are filled per star, not by clipping a row to a percentage. The old
 * approach divided the total width (including the gaps) so a 4/5 rating cut
 * into the fifth star -- that is what made them look broken.
 */
function starShape(fill) {
  return (
    '<path d="' + STAR_PATH + '" fill="' + fill + '" stroke="' + fill +
    '" stroke-width="0.7" stroke-linejoin="round"/>'
  );
}

function starSVG(size, fraction) {
  const id = 'st' + ++markerSeq;
  const w = Math.max(0, Math.min(1, fraction || 0)) * 24;
  return (
    '<svg width="' + size + '" height="' + size + '" viewBox="0 0 24 24" aria-hidden="true">' +
    '<defs><clipPath id="' + id + '"><rect x="0" y="0" width="' + w + '" height="24"/></clipPath></defs>' +
    starShape(STAR_EMPTY) +
    '<g clip-path="url(#' + id + ')">' + starShape(STAR_GREEN) + '</g>' +
    '</svg>'
  );
}

function starRow(rating, size) {
  const s = size || 11;
  const row = h('span', { class: 'stars', 'data-role': 'stars' });
  for (let i = 0; i < 5; i++) {
    const fraction = Math.max(0, Math.min(1, (rating || 0) - i));
    row.appendChild(h('span', { class: 'star', html: starSVG(s, fraction) }));
  }
  return row;
}

/* ---------- state ---------- */

const state = {
  focus: 'phone',
  handle: 'kerthfyadao',
  relay: 'http://192.168.1.50:3000',
  health: null,
  feed: null,
  feedError: null,
  tab: 'diary',
  view: { kind: 'tab' },
  sheet: null,
  alert: null,
  drafts: [],
  search: { q: '', loading: false, results: null, error: null },
};

const els = {};
let booted = false;

function loadLocal() {
  try {
    const handle = localStorage.getItem('matinee.handle');
    if (handle) state.handle = handle;
    const relay = localStorage.getItem('matinee.relay');
    if (relay) state.relay = relay;
    const drafts = JSON.parse(localStorage.getItem('matinee.drafts') || '[]');
    if (Array.isArray(drafts)) state.drafts = drafts;
  } catch (e) {
    /* private mode */
  }
}

function saveLocal(key, value) {
  try {
    localStorage.setItem(key, typeof value === 'string' ? value : JSON.stringify(value));
  } catch (e) {
    /* ignore */
  }
}

/* ---------- api ---------- */

async function api(path, opts) {
  const res = await fetch(path, opts);
  let body = null;
  try {
    body = await res.json();
  } catch (e) {
    body = null;
  }
  if (!res.ok) {
    const err = new Error((body && body.reason) || 'http_' + res.status);
    err.status = res.status;
    err.body = body;
    throw err;
  }
  return body;
}

/* ---------- event log ---------- */

function logEvent(msg, cls) {
  const list = document.getElementById('eventlog');
  if (!list) return;
  const time = new Date().toTimeString().slice(0, 8);
  const li = h('li', { class: cls || '' }, h('span', { class: 't', text: time }), h('span', { text: msg }));
  list.insertBefore(li, list.firstChild);
  while (list.children.length > 60) list.removeChild(list.lastChild);
}

/* ---------- data loading ---------- */

async function loadFeed(handle) {
  const who = handle || state.handle;
  try {
    const data = await api('/api/feed?user=' + encodeURIComponent(who));
    state.feed = data;
    state.handle = data.handle;
    state.feedError = null;
    saveLocal('matinee.handle', data.handle);
    logEvent('feed: ' + plural(data.counts.diary, 'entry', 'entries') + ', ' + data.counts.lists + ' lists (' + data.source + ')', 'ok');
  } catch (err) {
    state.feedError = (err.body && err.body.detail) || err.message;
    logEvent('feed failed: ' + state.feedError, 'err');
  }
}

async function openFilm(slug, fallback) {
  if (!slug) return;
  state.view = { kind: 'film', slug, item: fallback || null, film: null, error: null, loading: true };
  render();
  try {
    const film = await api('/api/film?slug=' + encodeURIComponent(slug));
    if (state.view.kind !== 'film' || state.view.slug !== slug) return;
    state.view.film = film;
    state.view.loading = false;
    logEvent('film: ' + film.title + ' ★' + film.rating + ' · ' + film.runtime + ' min', 'ok');
  } catch (err) {
    if (state.view.kind !== 'film' || state.view.slug !== slug) return;
    state.view.loading = false;
    state.view.error = (err.body && err.body.detail) || err.message;
    logEvent('film failed: ' + state.view.error, 'err');
  }
  render();
}

/* ---------- components ---------- */

function statusBar() {
  return h(
    'div',
    { class: 'statusbar' },
    h('span', { text: '9:41 AM' }),
    h(
      'span',
      { class: 'sb-right' },
      h('span', { class: 'sb-signal', html: '<i></i><i></i><i></i><i></i><i></i>' }),
      h('span', { text: '3G' }),
      h('span', { class: 'sb-battery', html: '<i></i>' })
    )
  );
}

function navBar(title, opts) {
  const o = opts || {};
  const bar = h('div', { class: 'navbar' + (o.back ? ' has-back' : '') });

  if (o.back) {
    bar.appendChild(
      h('span', { class: 'nav-back' },
        h('button', {
          class: 'nav-btn back nav-left',
          type: 'button',
          'data-role': 'nav-back',
          'aria-label': 'Back to ' + o.backLabel,
          onclick: o.back,
        }, h('span', { class: 'back-label', text: o.backLabel }))
      )
    );
  }

  const titleEl = h('div', {
    class: 'nav-title' + (o.mark && o.logoOnly ? ' logo-only' : ''),
    'aria-label': title,
    title: o.mark && o.logoOnly ? title : null,
  });
  if (o.mark) titleEl.appendChild(h('span', { class: 'nav-mark', html: markSVG() }));
  if (!o.logoOnly) titleEl.appendChild(h('span', { class: 'nav-label', text: title }));
  bar.appendChild(titleEl);

  if (o.right) {
    bar.appendChild(
      h('div', { class: 'nav-right' }, h('button', { class: 'nav-btn', type: 'button', 'data-role': o.rightRole, onclick: o.right.onclick }, o.right.label))
    );
  }
  return bar;
}

function posterThumb(item) {
  const wrap = h('div', { class: 'poster-thumb' });
  const cdn = item.posterCdn;
  if (cdn) {
    const img = h('img', {
      src: cdn,
      alt: item.title || '',
      'data-role': 'poster',
      loading: 'lazy',
    });
    img.addEventListener('error', () => {
      if (item.poster && img.src.indexOf('/img') === -1) {
        img.src = item.poster;
      } else {
        img.remove();
      }
    });
    img.addEventListener('load', scheduleCachePill);
    wrap.appendChild(img);
  } else {
    wrap.appendChild(h('span', { class: 'ph', text: '▤' }));
  }
  return wrap;
}

function emptyState(text) {
  return h('div', { class: 'note' }, h('p', { text }));
}

/* ---------- diary ---------- */

function diaryRows() {
  const feed = state.feed;
  if (!feed) return [emptyState(state.feedError ? 'Relay unavailable: ' + state.feedError : 'Loading diary…')];
  const rows = feed.items.filter((i) => i.kind === 'diary');
  if (!rows.length) return [emptyState('No public diary entries for @' + feed.handle + '.')];

  const group = h('div', { class: 'group' });
  let last = null;
  for (const item of rows) {
    if (item.watchedDate !== last) {
      last = item.watchedDate;
    }
    const row = h(
      'div',
      {
        class: 'row tappable',
        'data-role': 'feed-row',
        'data-slug': item.slug || '',
        onclick: () => openFilm(item.slug, item),
      },
      posterThumb(item),
      h(
        'div',
        { class: 'body' },
        h(
          'div',
          { class: 'title' },
          item.title,
          item.year ? h('span', { class: 'title-meta', text: ' ' + item.year }) : null
        ),
        h(
          'div',
          { class: 'meta-line' },
          h(
            'span',
            {},
            item.rating != null ? starRow(item.rating, 10) : h('span', { class: 'sub', style: { margin: '0' }, text: 'Not rated' }),
            item.rewatch ? h('span', { text: '  ↻' }) : null,
            item.liked ? h('span', { text: '  ♥' }) : null
          ),
          h('span', { class: 'stamp', text: shortDate(item.watchedDate) })
        ),
        item.review ? h('div', { class: 'sub', text: item.review }) : null
      )
    );
    group.appendChild(row);
  }
  return [group];
}

function diaryView() {
  const feed = state.feed;
  const c = h('div', { class: 'content pinstripe' });

  if (feed) {
    const rated = feed.items.filter((i) => i.kind === 'diary' && i.rating != null);
    const avg = rated.length ? rated.reduce((a, b) => a + b.rating, 0) / rated.length : 0;
    c.appendChild(
      h(
        'div',
        { class: 'section-head' },
        feed.member + ' · ' + plural(feed.counts.diary, 'entry', 'entries') + ' · ★ ' + avg.toFixed(2) + ' avg'
      )
    );
  }
  for (const node of diaryRows()) c.appendChild(node);
  return c;
}

/* ---------- film detail ---------- */

function filmDetailView() {
  const v = state.view;
  const item = v.item || {};
  const film = v.film || {};
  const title = film.title || item.title || v.slug;
  const year = film.year || item.year;
  const poster = film.posterCdn || item.posterCdn;
  const wrap = h('div', { class: 'content plain', 'data-role': 'film-detail' });

  const detail = h('div', { class: 'detail' });

  const hero = h('div', { class: 'detail-hero' });
  const p = h('div', { class: 'detail-poster' });
  if (poster) {
    const img = h('img', { src: poster, alt: title, 'data-role': 'detail-poster' });
    img.addEventListener('error', () => {
      if (film.poster) img.src = film.poster;
    });
    img.addEventListener('load', scheduleCachePill);
    p.appendChild(img);
  }
  hero.appendChild(p);

  const head = h('div', { class: 'detail-head' });
  head.appendChild(h('div', { class: 'detail-title', text: title }));
  head.appendChild(h('div', { class: 'detail-year', text: [year, film.runtime ? film.runtime + ' min' : null].filter(Boolean).join(' · ') }));

  if (film.rating != null) {
    head.appendChild(
      h(
        'div',
        { class: 'detail-rating' },
        starRow(film.rating, 12),
        h('span', { class: 'rating-num', text: film.rating.toFixed(2) + ' avg' })
      )
    );
  }
  if (item.rating != null) {
    head.appendChild(
      h(
        'div',
        { class: 'detail-rating' },
        starRow(item.rating, 12),
        h('span', { class: 'rating-num', text: 'your rating' })
      )
    );
  }

  const facts = [];
  if (film.directors && film.directors.length) facts.push('Dir. ' + film.directors.join(', '));
  if (film.genres && film.genres.length) facts.push(film.genres.join(' · '));
  if (film.ratingCount) facts.push(Number(film.ratingCount).toLocaleString('en-US') + ' ratings');
  for (const fact of facts) head.appendChild(h('div', { class: 'detail-facts', text: fact }));

  hero.appendChild(head);
  detail.appendChild(hero);

  if (item.review) {
    detail.appendChild(h('hr', { class: 'detail-hr' }));
    detail.appendChild(h('div', { class: 'detail-synopsis', text: '“' + item.review + '”' }));
  }

  if (film.synopsis) {
    detail.appendChild(h('hr', { class: 'detail-hr' }));
    detail.appendChild(h('div', { class: 'detail-synopsis', text: film.synopsis }));
  }

  if (v.loading) detail.appendChild(h('div', { class: 'note', text: 'Loading film details…' }));
  if (v.error) detail.appendChild(h('div', { class: 'note', text: 'Film page unavailable (' + v.error + '). Showing what the feed carried.' }));

  detail.appendChild(h('hr', { class: 'detail-hr' }));
  detail.appendChild(
    h('button', {
      class: 'btn',
      type: 'button',
      'data-role': 'log-film',
      onclick: () => openLog({ slug: v.slug, title, year, posterCdn: poster, tmdbId: film.tmdbId || item.tmdbId, userRating: item.rating, review: '' }),
    }, 'Log this film')
  );
  detail.appendChild(h('div', { style: { height: '8px' } }));
  detail.appendChild(
    h('button', {
      class: 'btn secondary',
      type: 'button',
      'data-role': 'open-on-letterboxd',
      onclick: () => {
        logEvent('canonical: letterboxd.com/film/' + v.slug + '/');
        showAlert('Letterboxd', 'letterboxd.com/film/' + v.slug + '/', [{ label: 'OK' }]);
      },
    }, 'View on Letterboxd')
  );

  wrap.appendChild(detail);
  return wrap;
}

/* ---------- lists ---------- */

function listsView() {
  const feed = state.feed;
  const c = h('div', { class: 'content pinstripe' });
  if (!feed) return c;
  const lists = feed.items.filter((i) => i.kind === 'list');
  c.appendChild(h('div', { class: 'section-head' }, plural(lists.length, 'list')));
  const group = h('div', { class: 'group' });
  for (const list of lists) {
    group.appendChild(
      h(
        'div',
        {
          class: 'row tappable',
          'data-role': 'list-row',
          onclick: () => {
            state.view = { kind: 'list', list };
            render();
          },
        },
        h(
          'div',
          { class: 'body' },
          h('div', { class: 'title', text: list.title }),
          h('div', { class: 'sub', text: list.shown + ' of ' + list.total + ' films · ' + shortDate(list.published) })
        ),
        h('span', { class: 'chev', text: '›' })
      )
    );
  }
  if (!lists.length) c.appendChild(emptyState('No public lists in this feed.'));
  c.appendChild(group);
  return c;
}

function listDetailView() {
  const list = state.view.list;
  const c = h('div', { class: 'content plain', 'data-role': 'list-detail' });
  const section = h('div', { class: 'detail' });
  section.appendChild(h('div', { class: 'detail-title', text: list.title }));
  section.appendChild(h('div', { class: 'detail-year', text: list.shown + ' of ' + list.total + ' films shown in RSS' }));
  section.appendChild(h('hr', { class: 'detail-hr' }));
  const group = h('div', { class: 'group', style: { margin: '0' } });
  for (const entry of list.entries) {
    group.appendChild(
      h(
        'div',
        {
          class: 'row tappable',
          'data-role': 'list-entry',
          onclick: () => openFilm(entry.slug, { title: entry.title }),
        },
        h('div', { class: 'body' }, h('div', { class: 'title', text: entry.title })),
        h('span', { class: 'chev', text: '›' })
      )
    );
  }
  section.appendChild(group);
  if (list.total > list.shown) {
    section.appendChild(h('div', { class: 'note', text: 'The RSS feed only carries the first ' + list.shown + ' titles. The remaining ' + (list.total - list.shown) + ' need the list page, which is Cloudflare-gated.' }));
  }
  c.appendChild(section);
  return c;
}

/* ---------- search ---------- */

function searchView() {
  const c = h('div', { class: 'content pinstripe', 'data-role': 'search-view' });
  const bar = h('div', { class: 'searchbar' },
    h('span', { class: 'mag', text: '⌕' }),
    h('input', {
      type: 'search',
      placeholder: 'Search films and TV',
      value: state.search.q,
      'data-role': 'search-input',
      oninput: (e) => { state.search.q = e.target.value; },
      onkeydown: (e) => { if (e.key === 'Enter') runSearch(); },
    }),
    h('button', { class: 'search-go', type: 'button', 'data-role': 'search-go', onclick: runSearch }, 'Go')
  );
  c.appendChild(bar);

  if (!state.health || !state.health.tmdb) {
    c.appendChild(
      h('div', { class: 'note', 'data-role': 'search-unconfigured' },
        h('h3', { text: 'Search needs a TMDB key' }),
        h('p', { text: 'Letterboxd’s own search is JavaScript-rendered, so there is nothing to scrape. TMDB is the sanctioned compensation.' }),
        h('p', { html: 'Register free at <b>themoviedb.org</b> → Settings → API, then restart the relay with <code>TMDB_API_KEY=…</code>.' }),
        h('p', { class: 'meta', text: 'Drafts made from search match by tmdbID on CSV import, so no Letterboxd slug is needed.' })
      )
    );
    return c;
  }

  if (state.search.loading) {
    c.appendChild(h('div', { class: 'note', text: 'Searching…' }));
    return c;
  }
  if (state.search.error) {
    c.appendChild(h('div', { class: 'note', text: state.search.error }));
    return c;
  }
  if (!state.search.results) {
    c.appendChild(h('div', { class: 'note', text: 'Type a title and press Go.' }));
    return c;
  }
  if (!state.search.results.length) {
    c.appendChild(h('div', { class: 'note', text: 'No matches.' }));
    return c;
  }

  const group = h('div', { class: 'group' });
  for (const r of state.search.results) {
    group.appendChild(
      h('div', {
        class: 'row tappable',
        'data-role': 'search-result',
        onclick: () => openLog({ slug: null, tmdbId: r.tmdbId, title: r.title, year: r.year, posterCdn: r.posterCdn, userRating: null, review: '' }),
      },
      posterThumb(r),
      h('div', { class: 'body' },
        h('div', { class: 'title' }, r.title, r.year ? h('span', { class: 'title-meta', text: ' ' + r.year }) : null),
        h('div', { class: 'sub' }, (r.kind === 'tv' ? 'TV' : 'Film') + (r.rating != null ? ' · ' + r.rating.toFixed(1) : ''))
      ),
      h('span', { class: 'chev', text: '›' })
    ));
  }
  c.appendChild(group);
  c.appendChild(h('div', { class: 'note', text: 'Tapping a result creates a draft keyed by tmdbID. Letterboxd’s importer matches that column directly.' }));
  return c;
}

async function runSearch() {
  const q = (state.search.q || '').trim();
  if (!q) return;
  state.search.loading = true;
  state.search.error = null;
  state.search.results = null;
  render();
  try {
    const data = await api('/api/search?q=' + encodeURIComponent(q));
    state.search.results = data.results || [];
    logEvent('search: ' + q + ' → ' + state.search.results.length + ' results', 'ok');
  } catch (err) {
    state.search.error = (err.body && err.body.detail) || err.body && err.body.reason || err.message;
    logEvent('search failed: ' + state.search.error, 'err');
  }
  state.search.loading = false;
  render();
}

/* ---------- profile ---------- */

function profileView() {
  const c = h('div', { class: 'content pinstripe', 'data-role': 'profile' });
  const member = (state.feed && state.feed.member) || state.handle;
  const diary = state.feed ? state.feed.items.filter((i) => i.kind === 'diary') : [];
  const rated = diary.filter((i) => i.rating != null);
  const avg = rated.length ? rated.reduce((a, b) => a + b.rating, 0) / rated.length : 0;

  const head = h('div', { class: 'profile-head' },
    h('div', { class: 'avatar', text: (member[0] || '?').toUpperCase() }),
    h('div', {},
      h('div', { class: 'profile-name', text: member }),
      h('div', { class: 'profile-handle', text: '@' + state.handle + ' · letterboxd.com' })
    )
  );
  c.appendChild(head);

  c.appendChild(h('div', { class: 'stat-strip' },
    h('div', { class: 'stat' }, h('b', { text: String(diary.length) }), h('span', { text: 'entries' })),
    h('div', { class: 'stat' }, h('b', { text: String(state.feed ? state.feed.counts.lists : 0) }), h('span', { text: 'lists' })),
    h('div', { class: 'stat' }, h('b', { text: rated.length ? avg.toFixed(2) : '—' }), h('span', { text: 'avg rating' }))
  ));

  c.appendChild(h('div', { class: 'group-title', text: 'Account' }));
  const g1 = h('div', { class: 'group' });
  g1.appendChild(h('div', {
    class: 'row tappable', 'data-role': 'open-connect',
    onclick: () => { state.sheet = { kind: 'connect', input: '', error: null }; render(); },
  },
    h('div', { class: 'body' }, h('div', { class: 'title', text: 'Connect a profile' })),
    h('span', { class: 'chev', text: '›' })
  ));
  g1.appendChild(h('div', { class: 'row' },
    h('div', { class: 'body' }, h('div', { class: 'kv' },
      h('span', { class: 'k', text: 'Relay' }),
      h('span', { class: 'v', text: state.relay.replace(/^https?:\/\//, '') })
    ))
  ));
  c.appendChild(g1);

  c.appendChild(h('div', { class: 'group-title', text: 'Drafts' }));
  const g2 = h('div', { class: 'group' });
  g2.appendChild(h('div', { class: 'row' },
    h('div', { class: 'body' }, h('div', { class: 'kv' },
      h('span', { class: 'k', text: 'Saved drafts' }),
      h('span', { class: 'v', 'data-role': 'draft-count', text: String(state.drafts.length) })
    ))
  ));
  g2.appendChild(h('div', {
    class: 'row tappable', 'data-role': 'export-csv',
    onclick: exportCSV,
  },
    h('div', { class: 'body' }, h('div', { class: 'title', text: 'Export CSV for import' })),
    h('span', { class: 'chev', text: '›' })
  ));
  if (state.drafts.length) {
    g2.appendChild(h('div', {
      class: 'row tappable', 'data-role': 'clear-drafts',
      onclick: () => {
        state.drafts = [];
        saveLocal('matinee.drafts', []);
        logEvent('drafts cleared');
        render();
      },
    },
      h('div', { class: 'body' }, h('div', { class: 'title', style: { color: '#b3352f' }, text: 'Clear drafts' }))
    ));
  }
  c.appendChild(g2);

  c.appendChild(h('div', { class: 'group-title', text: 'Connection' }));
  const g3 = h('div', { class: 'group' });
  g3.appendChild(h('div', { class: 'row' },
    h('div', { class: 'body' }, h('div', { class: 'kv' },
      h('span', { class: 'k', text: 'Feed source' }),
      h('span', { class: 'v', 'data-role': 'source-value', text: state.feed ? state.feed.source : '—' })
    ))
  ));
  g3.appendChild(h('div', { class: 'row' },
    h('div', { class: 'body' }, h('div', { class: 'kv' },
      h('span', { class: 'k', text: 'Write access' }),
      h('span', { class: 'v', text: state.health && state.health.session ? 'session cookie set' : 'drafts only' })
    ))
  ));
  g3.appendChild(h('div', { class: 'row' },
    h('div', { class: 'body' }, h('div', { class: 'kv' },
      h('span', { class: 'k', text: 'Poster cache' }),
      h('span', { class: 'v', text: String((state.health && state.health.images && state.health.images.entries) || 0) + ' on relay' })
    ))
  ));
  c.appendChild(g3);

  c.appendChild(h('div', { class: 'note', style: { marginTop: '14px' } },
    h('p', { text: 'Matinee reads public RSS only. No password, no token, no private data.' }),
    h('p', { class: 'meta', text: 'Not affiliated with Letterboxd.' })
  ));
  return c;
}

/* ---------- log sheet ---------- */

function openLog(film) {
  state.sheet = {
    kind: 'log',
    draft: {
      slug: film.slug || null,
      tmdbId: film.tmdbId || null,
      title: film.title || '',
      year: film.year || null,
      posterCdn: film.posterCdn || null,
      rating: film.userRating != null ? film.userRating : null,
      watchedDate: todayISO(),
      review: film.review || '',
      rewatch: false,
      liked: false,
      tags: '',
    },
    fs: { rating: film.userRating != null ? film.userRating : null, watchedDate: todayISO() },
    error: null,
  };
  render();
}

function logSheet() {
  const s = state.sheet;
  const d = s.draft;
  const scrim = h('div', { class: 'scrim', 'data-role': 'log-scrim' });
  const sheet = h('div', {
    class: 'sheet' + (s.animated ? '' : ' sheet-enter'),
    'data-role': 'log-sheet',
  });
  s.animated = true;

  sheet.appendChild(h('div', { class: 'sheet-bar' },
    h('button', { type: 'button', 'data-role': 'log-cancel', onclick: () => { state.sheet = null; render(); } }, 'Cancel'),
    h('span', { class: 'sheet-title', text: 'Log film' }),
    h('button', { type: 'button', 'data-role': 'save-draft', onclick: saveDraft }, 'Save')
  ));

  /* header: poster + title, no long URL to wrap into three lines */
  const head = h('div', { class: 'sheet-film' });
  const poster = h('div', { class: 'sheet-poster' });
  if (d.posterCdn) {
    const img = h('img', { src: d.posterCdn, alt: '', 'data-role': 'sheet-poster' });
    img.addEventListener('error', () => img.remove());
    poster.appendChild(img);
  } else {
    poster.appendChild(h('span', { class: 'ph', text: '▤' }));
  }
  head.appendChild(poster);
  head.appendChild(h('div', { class: 'sheet-film-body' },
    h('div', { class: 'sheet-film-title', text: d.title }),
    h('div', { class: 'sheet-film-sub', text: [d.year, 'Film'].filter(Boolean).join(' · ') })
  ));
  sheet.appendChild(head);

  const body = h('div', { class: 'sheet-body' });

  /* stars: repaint in place on tap, so the sheet never re-animates */
  const stars = h('div', { class: 'log-stars', 'data-role': 'log-stars' });
  const row = h('div', { class: 'log-stars-row' });
  for (let i = 1; i <= 5; i++) {
    row.appendChild(h('button', {
      class: 'log-star',
      type: 'button',
      'data-star': String(i),
      'data-role': 'log-star',
      'aria-label': i + ' star' + (i === 1 ? '' : 's'),
      onclick: () => {
        s.fs.rating = s.fs.rating === i ? null : i;
        paintLogStars(stars, s);
      },
    }));
  }
  stars.appendChild(row);
  stars.appendChild(h('div', { class: 'log-caption', 'data-role': 'log-caption' }));
  paintLogStars(stars, s);
  body.appendChild(stars);

  body.appendChild(h('div', { class: 'field-row' },
    h('span', { class: 'field-label', text: 'Watched' }),
    h('input', {
      type: 'date', value: s.fs.watchedDate, 'data-role': 'log-date',
      onchange: (e) => { s.fs.watchedDate = e.target.value; },
    })
  ));

  body.appendChild(h('div', { class: 'field-row', style: { alignItems: 'flex-start' } },
    h('span', { class: 'field-label', text: 'Review' }),
    h('textarea', {
      placeholder: 'Optional note', 'data-role': 'log-review',
      oninput: (e) => { d.review = e.target.value; },
    }, d.review || '')
  ));

  body.appendChild(h('div', { class: 'field-row' },
    h('span', { class: 'field-label', text: 'Rewatch' }),
    h('button', {
      class: 'switch ' + (d.rewatch ? 'on' : ''), type: 'button', 'data-role': 'log-rewatch',
      'aria-pressed': d.rewatch ? 'true' : 'false',
      onclick: (e) => { d.rewatch = !d.rewatch; e.currentTarget.classList.toggle('on', d.rewatch); },
    })
  ));

  body.appendChild(h('div', { class: 'field-row' },
    h('span', { class: 'field-label', text: 'Like' }),
    h('button', {
      class: 'switch ' + (d.liked ? 'on' : ''), type: 'button', 'data-role': 'log-like',
      'aria-pressed': d.liked ? 'true' : 'false',
      onclick: (e) => { d.liked = !d.liked; e.currentTarget.classList.toggle('on', d.liked); },
    })
  ));

  if (s.error) body.appendChild(h('div', { class: 'note', text: s.error }));
  sheet.appendChild(body);

  /* footer sits outside the scroll area, so Save is never pushed off-screen */
  const foot = h('div', { class: 'sheet-foot' });
  if (state.health && state.health.session && d.slug) {
    foot.appendChild(h('button', {
      class: 'btn danger', type: 'button', 'data-role': 'send-letterboxd',
      onclick: sendDraft,
    }, 'Send to Letterboxd'));
    foot.appendChild(h('div', { class: 'sheet-note', text: 'Experimental · uses a session cookie on the relay' }));
  } else {
    foot.appendChild(h('div', {
      class: 'sheet-note',
      text: d.slug
        ? 'Saves as a draft on this device · export from Profile'
        : 'Search result · matches by tmdbID on CSV import',
    }));
  }
  sheet.appendChild(foot);

  scrim.appendChild(sheet);
  scrim.addEventListener('click', (e) => { if (e.target === scrim) { state.sheet = null; render(); } });
  return scrim;
}

function paintLogStars(container, s) {
  const rating = s.fs.rating;
  const buttons = container.querySelectorAll('[data-role="log-star"]');
  for (let i = 0; i < buttons.length; i++) {
    const fraction = Math.max(0, Math.min(1, (rating || 0) - i));
    buttons[i].className = 'log-star' + (fraction > 0 ? ' on' : '');
    buttons[i].innerHTML = starSVG(26, fraction);
  }
  const cap = container.querySelector('[data-role="log-caption"]');
  if (cap) {
    cap.textContent = rating == null ? 'Tap a star to rate' : rating.toFixed(1) + ' of 5';
  }
}

function saveDraft() {
  const s = state.sheet;
  if (!s || s.kind !== 'log') return;
  const d = Object.assign({}, s.draft, {
    rating: s.fs.rating,
    watchedDate: s.fs.watchedDate,
    createdAt: new Date().toISOString(),
  });
  state.drafts.unshift(d);
  saveLocal('matinee.drafts', state.drafts);
  state.sheet = null;
  logEvent('draft saved: ' + d.title + (d.rating != null ? ' ★' + d.rating : ''), 'ok');
  showToast('Draft saved');
  render();
}

async function sendDraft() {
  const s = state.sheet;
  if (!s || !s.draft.slug) return;
  const d = Object.assign({}, s.draft, {
    rating: s.fs.rating,
    watchedDate: s.fs.watchedDate,
  });
  s.error = 'Sending…';
  render();
  try {
    const res = await api('/api/log', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(d),
    });
    state.sheet = null;
    logEvent('letterboxd write: ' + (res.reason || 'ok'), 'ok');
    showAlert('Sent', 'Letterboxd accepted the entry. Check your diary to confirm.', [{ label: 'OK' }]);
  } catch (err) {
    const body = err.body || {};
    s.error = (body.detail || body.reason || err.message) + ' — saved as a draft instead.';
    if (s.kind === 'log') {
      state.drafts.unshift(Object.assign({}, d, { createdAt: new Date().toISOString() }));
      saveLocal('matinee.drafts', state.drafts);
    }
    logEvent('letterboxd write failed: ' + (body.reason || err.message), 'err');
    render();
  }
}

/* ---------- connect sheet ---------- */

function connectSheet() {
  const s = state.sheet;
  const scrim = h('div', { class: 'scrim' });
  const sheet = h('div', {
    class: 'sheet' + (s.animated ? '' : ' sheet-enter'),
    'data-role': 'connect-sheet',
  });
  s.animated = true;

  sheet.appendChild(h('div', { class: 'sheet-bar' },
    h('button', { type: 'button', 'data-role': 'connect-cancel', onclick: () => { state.sheet = null; render(); } }, 'Cancel'),
    h('span', { class: 'sheet-title', text: 'Connect profile' }),
    h('span', { style: { width: '46px' } })
  ));

  const body = h('div', { class: 'sheet-body' });
  body.appendChild(h('div', { class: 'note', style: { marginTop: '12px' } },
    h('p', { text: 'Paste your Letterboxd profile link, your RSS URL, or just your handle.' }),
    h('p', { class: 'meta', text: 'example: letterboxd.com/kerthfyadao' })
  ));

  body.appendChild(h('div', { class: 'field-row' },
    h('span', { class: 'field-label', text: 'Handle' }),
    h('input', {
      type: 'text', value: s.input || '', placeholder: 'letterboxd.com/you',
      'data-role': 'connect-input', autocapitalize: 'none', autocorrect: 'off', spellcheck: 'false',
      oninput: (e) => { s.input = e.target.value; },
      onkeydown: (e) => { if (e.key === 'Enter') submitConnect(); },
    })
  ));

  if (s.error) body.appendChild(h('div', { class: 'note', 'data-role': 'connect-error', text: s.error }));

  const actions = h('div', { class: 'sheet-actions' },
    h('button', { class: 'btn', type: 'button', 'data-role': 'connect-submit', onclick: submitConnect }, 'Connect')
  );
  body.appendChild(actions);

  body.appendChild(h('div', { class: 'note', style: { marginTop: '0' } },
    h('p', { class: 'meta', text: 'Read-only. The relay validates the handle, then reads the public RSS feed. Private profiles have no public feed and are rejected.' })
  ));

  sheet.appendChild(body);
  scrim.appendChild(sheet);
  scrim.addEventListener('click', (e) => { if (e.target === scrim) { state.sheet = null; render(); } });
  return scrim;
}

async function submitConnect() {
  const s = state.sheet;
  if (!s || s.kind !== 'connect') return;
  const input = (s.input || '').trim();
  if (!input) { s.error = 'Enter a handle or profile link.'; render(); return; }
  s.error = 'Checking…';
  render();
  try {
    const res = await api('/api/connect', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ input }),
    });
    state.handle = res.handle;
    saveLocal('matinee.handle', res.handle);
    state.sheet = null;
    state.view = { kind: 'tab' };
    state.tab = 'diary';
    logEvent('connected: @' + res.handle + ' (' + res.member + ')', 'ok');
    await loadFeed(res.handle);
    showAlert('Connected', '@' + res.handle + ' · ' + plural(res.counts.diary, 'entry', 'entries') + ', ' + res.counts.lists + ' lists.', [{ label: 'OK' }]);
  } catch (err) {
    const body = err.body || {};
    s.error = body.detail || 'Could not connect @' + input.replace(/^.*\//, '') + '.';
    logEvent('connect failed: ' + (body.reason || err.message), 'err');
    render();
  }
}

/* ---------- alert / toast ---------- */

function showAlert(title, body, actions) {
  state.alert = { title, body, actions: actions || [{ label: 'OK' }] };
  render();
}

function alertView() {
  const a = state.alert;
  const wrap = h('div', { class: 'alert-wrap', 'data-role': 'alert' });
  const box = h('div', { class: 'alert' },
    h('div', { class: 'alert-title', text: a.title }),
    h('div', { class: 'alert-body', text: a.body })
  );
  const acts = h('div', { class: 'alert-actions' });
  for (const action of a.actions) {
    acts.appendChild(h('button', {
      type: 'button',
      onclick: () => {
        state.alert = null;
        render();
        if (action.onclick) action.onclick();
      },
    }, action.label));
  }
  box.appendChild(acts);
  wrap.appendChild(box);
  return wrap;
}

let toastTimer = null;
function showToast(text) {
  logEvent(text);
}

/* ---------- drafts / csv ---------- */

function csvCell(value) {
  const s = value == null ? '' : String(value);
  if (/[",\r\n]/.test(s)) return '"' + s.replace(/"/g, '""') + '"';
  return s;
}

function toCSV(drafts) {
  const head = ['LetterboxdURI', 'tmdbID', 'imdbID', 'Title', 'Year', 'Directors', 'Rating', 'Rating10', 'WatchedDate', 'Rewatch', 'Tags', 'Review'];
  const rows = drafts.map((d) => [
    d.slug ? 'https://letterboxd.com/film/' + d.slug + '/' : '',
    d.tmdbId || '',
    '',
    d.title || '',
    d.year || '',
    d.directors || '',
    d.rating != null ? d.rating : '',
    d.rating != null ? d.rating * 2 : '',
    d.watchedDate || '',
    d.rewatch ? 'Yes' : '',
    d.tags || '',
    d.review || '',
  ]);
  return [head].concat(rows).map((r) => r.map(csvCell).join(',')).join('\r\n') + '\r\n';
}

function exportCSV() {
  if (!state.drafts.length) {
    showAlert('No drafts', 'Log a film first. Drafts export as a CSV that Letterboxd’s importer accepts.', [{ label: 'OK' }]);
    return;
  }
  const csv = toCSV(state.drafts);
  logEvent('csv export: ' + state.drafts.length + ' drafts, ' + csv.length + ' bytes', 'ok');
  try {
    const blob = new Blob([csv], { type: 'text/csv;charset=utf-8' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = 'matinee-drafts.csv';
    document.body.appendChild(a);
    a.click();
    a.remove();
    setTimeout(() => URL.revokeObjectURL(url), 2000);
  } catch (e) {
    showAlert('CSV export', csv.slice(0, 180) + '…', [{ label: 'OK' }]);
  }
  showAlert('Export ready', plural(state.drafts.length, 'draft') + ' saved as matinee-drafts.csv. Import it at letterboxd.com/import.', [{ label: 'OK' }]);
}

/* ---------- poster cache pill ---------- */

let pillTimer = null;
function scheduleCachePill() {
  clearTimeout(pillTimer);
  pillTimer = setTimeout(updateCachePill, 400);
}

async function updateCachePill() {
  const pill = document.getElementById('cache-pill');
  if (!pill) return;
  if (!('caches' in window)) {
    pill.textContent = 'poster cache: unavailable';
    pill.classList.add('pill-warn');
    return;
  }
  try {
    const cache = await caches.open('matinee-posters-v1');
    const keys = await cache.keys();
    pill.textContent = 'poster cache: ' + keys.length + ' saved';
    pill.classList.toggle('pill-good', keys.length > 0);
    pill.classList.remove('pill-warn');
  } catch (e) {
    pill.textContent = 'poster cache: unavailable';
  }
}

function updateSourcePill() {
  const pill = document.getElementById('source-pill');
  if (!pill) return;
  if (!state.feed) { pill.textContent = 'source: —'; return; }
  pill.textContent = 'source: ' + state.feed.source + ' · @' + state.feed.handle;
  pill.classList.toggle('pill-warn', state.feed.source !== 'live');
}

/* ---------- render ---------- */

function render() {
  renderDevice(els.phone, 'phone');
  renderDevice(els.ipad, 'ipad');
  updateSourcePill();
  scheduleCachePill();
  window.__matinee = { state, render, openLog, saveDraft, toCSV, loadFeed, openFilm, submitConnect, runSearch };
}

function renderDevice(root, mode) {
  if (!root) return;
  root.innerHTML = '';

  const app = h('div', { class: 'ios' });
  app.appendChild(statusBar());

  if (mode === 'ipad') {
    app.appendChild(renderPadBody());
  } else {
    app.appendChild(renderPhoneBody());
  }

  if (state.focus === mode && state.sheet) {
    app.appendChild(state.sheet.kind === 'log' ? logSheet() : connectSheet());
  }
  if (state.focus === mode && state.alert) {
    app.appendChild(alertView());
  }
  root.appendChild(app);
}

function navFor(kind) {
  if (kind === 'film') {
    const v = state.view;
    return navBar((v.film && v.film.title) || (v.item && v.item.title) || v.slug, {
      back: () => { state.view = { kind: 'tab' }; render(); },
      backLabel: state.tab === 'lists' ? 'Lists' : 'Diary',
      right: {
        label: 'Log',
        onclick: () => {
          const film = v.film || {};
          const item = v.item || {};
          openLog({
            slug: v.slug,
            title: film.title || item.title,
            year: film.year || item.year,
            posterCdn: film.posterCdn || item.posterCdn,
            tmdbId: film.tmdbId || item.tmdbId,
            userRating: item.rating,
            review: '',
          });
        },
      },
      rightRole: 'nav-log',
    });
  }
  if (kind === 'list') {
    return navBar(state.view.list.title, {
      back: () => { state.view = { kind: 'tab' }; render(); },
      backLabel: 'Lists',
    });
  }
  const titles = { diary: 'Matinee', lists: 'Lists', search: 'Search', profile: 'Profile' };
  return navBar(titles[state.tab] || 'Matinee', {
    mark: state.tab === 'diary',
    logoOnly: state.tab === 'diary',
  });
}

function contentFor(kind) {
  if (kind === 'film') return filmDetailView();
  if (kind === 'list') return listDetailView();
  if (state.tab === 'lists') return listsView();
  if (state.tab === 'search') return searchView();
  if (state.tab === 'profile') return profileView();
  return diaryView();
}

function tabBar() {
  const tabs = [
    ['diary', 'Diary', ICON.diary],
    ['lists', 'Lists', ICON.lists],
    ['search', 'Search', ICON.search],
    ['profile', 'Profile', ICON.profile],
  ];
  const bar = h('div', { class: 'tabbar' });
  for (const [id, label, icon] of tabs) {
    bar.appendChild(h('button', {
      class: 'tab' + (state.tab === id ? ' active' : ''),
      type: 'button',
      'data-tab': id,
      'aria-current': state.tab === id ? 'page' : 'false',
      onclick: () => {
        state.tab = id;
        state.view = { kind: 'tab' };
        state.alert = null;
        render();
      },
      html: icon + '<span class="tab-label">' + label + '</span>',
    }));
  }
  return bar;
}

function screenKind() {
  return state.view.kind === 'film' || state.view.kind === 'list' ? state.view.kind : 'tab';
}

function renderPhoneBody() {
  const frag = document.createDocumentFragment();
  const kind = screenKind();
  frag.appendChild(navFor(kind));
  frag.appendChild(contentFor(kind));
  frag.appendChild(tabBar());
  return frag;
}

function renderPadBody() {
  const split = h('div', { class: 'split' });

  const left = h('div', { class: 'pane-left' });
  const leftNav = navFor('tab');
  // Left pane always shows the list for the current tab.
  left.appendChild(leftNav);
  const leftContent = state.tab === 'lists' ? listsView() : state.tab === 'search' ? searchView() : state.tab === 'profile' ? profileView() : diaryView();
  left.appendChild(leftContent);

  const right = h('div', { class: 'pane-right' });
  if (state.view.kind === 'film') {
    right.appendChild(
      navBar((state.view.film && state.view.film.title) || (state.view.item && state.view.item.title) || 'Film', {
        back: () => { state.view = { kind: 'tab' }; render(); },
        backLabel: state.tab === 'lists' ? 'Lists' : 'Diary',
      })
    );
    right.appendChild(filmDetailView());
  } else if (state.view.kind === 'list') {
    right.appendChild(navBar(state.view.list.title, { back: () => { state.view = { kind: 'tab' }; render(); }, backLabel: 'Lists' }));
    right.appendChild(listDetailView());
  } else {
    right.appendChild(navBar('Detail', {}));
    right.appendChild(h('div', { class: 'pane-empty', text: 'Select a film to see its page.' }));
  }

  split.appendChild(left);
  split.appendChild(right);
  const frag = document.createDocumentFragment();
  frag.appendChild(split);
  frag.appendChild(tabBar());
  return frag;
}

/* ---------- service worker ---------- */

async function registerCache() {
  if (!('serviceWorker' in navigator)) return;
  try {
    await navigator.serviceWorker.register('sw.js');
    navigator.serviceWorker.addEventListener('message', () => updateCachePill());
    updateCachePill();
  } catch (e) {
    const pill = document.getElementById('cache-pill');
    if (pill) pill.textContent = 'poster cache: unavailable';
  }
}

/* ---------- boot ---------- */

async function boot() {
  els.phone = document.getElementById('phone');
  els.ipad = document.getElementById('ipad');
  loadLocal();

  for (const el of [els.phone, els.ipad]) {
    if (!el) continue;
    el.addEventListener('pointerdown', () => {
      const mode = el === els.phone ? 'phone' : 'ipad';
      if (state.focus !== mode) { state.focus = mode; render(); }
    });
  }

  const brand = document.getElementById('brand-mark');
  if (brand) brand.innerHTML = markSVG();

  render();

  try {
    state.health = await api('/api/health');
    if (!localStorage.getItem('matinee.handle') && state.health.member) {
      state.handle = state.health.member;
    }
    logEvent('relay: ' + state.health.service + ' v' + state.health.version + ' · member @' + state.health.member, 'ok');
  } catch (e) {
    logEvent('relay unreachable', 'err');
  }

  await loadFeed();
  render();
  registerCache();
  booted = true;
}

document.addEventListener('DOMContentLoaded', boot);

// The console's clear button is outside the device frames.
document.addEventListener('click', (e) => {
  if (e.target && e.target.id === 'console-clear') {
    const list = document.getElementById('eventlog');
    if (list) list.innerHTML = '';
  }
});
