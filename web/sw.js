'use strict';

/*
 * Poster cache.
 *
 * The browser can fetch a.ltrbxd.com directly (modern TLS), but posters are
 * immutable per URL, so caching them means scrolling back never refetches and
 * the mock survives a reload without 50 new requests.
 *
 * Only images are cached. Feeds and API responses stay network-only so the
 * diary is never stale.
 */

const CACHE = 'matinee-posters-v1';

self.addEventListener('install', (event) => {
  self.skipWaiting();
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys().then((keys) =>
      Promise.all(keys.filter((k) => k !== CACHE).map((k) => caches.delete(k)))
    ).then(() => self.clients.claim())
  );
});

function isPoster(url) {
  return (
    url.hostname === 'a.ltrbxd.com' ||
    url.hostname === 'image.tmdb.org' ||
    url.pathname === '/img'
  );
}

self.addEventListener('fetch', (event) => {
  let url;
  try {
    url = new URL(event.request.url);
  } catch (e) {
    return;
  }
  if (event.request.method !== 'GET' || !isPoster(url)) return;

  event.respondWith(
    caches.open(CACHE).then(async (cache) => {
      const hit = await cache.match(event.request);
      if (hit) return hit;
      const res = await fetch(event.request);
      // Cross-origin posters are opaque (status 0, res.ok === false) unless
      // the CDN sends CORS headers. They are still perfectly cacheable, and
      // caching them is the entire point of this worker.
      if (res && (res.ok || res.type === 'opaque')) {
        const write = cache
          .put(event.request, res.clone())
          .then(() =>
            self.clients.matchAll().then((clients) => {
              clients.forEach((c) => c.postMessage({ type: 'poster-cached' }));
            })
          )
          .catch(() => {
            // A failed cache write must not break the image response.
          });
        if (event.waitUntil) event.waitUntil(write);
      }
      return res;
    })
  );
});
