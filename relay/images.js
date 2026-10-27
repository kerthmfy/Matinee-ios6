'use strict';

/*
 * Byte cache for proxied posters.
 *
 * Why this exists: a 50-row diary asks for 50 images at once. Without a cache
 * every redraw re-fetches the same JPEGs from the CDN, which is both slow and
 * rude. The cache is a small FIFO -- posters are immutable per URL, so there is
 * no expiry to reason about.
 */

const MAX_ENTRIES = 300;
const MAX_BYTES = 64 * 1024 * 1024;

const store = new Map();
let totalBytes = 0;

function stats() {
  return { entries: store.size, bytes: totalBytes, maxEntries: MAX_ENTRIES };
}

function get(key) {
  const hit = store.get(key);
  if (!hit) return null;
  // Re-insert to keep FIFO order meaningful for eviction (oldest first).
  store.delete(key);
  store.set(key, hit);
  return hit;
}

function put(key, value) {
  if (store.has(key)) {
    totalBytes -= store.get(key).body.length;
    store.delete(key);
  }
  store.set(key, value);
  totalBytes += value.body.length;

  while (store.size > MAX_ENTRIES || totalBytes > MAX_BYTES) {
    const oldest = store.keys().next();
    if (oldest.done) break;
    const victim = store.get(oldest.value);
    totalBytes -= victim.body.length;
    store.delete(oldest.value);
  }
}

function clear() {
  store.clear();
  totalBytes = 0;
}

module.exports = { get, put, stats, clear, MAX_ENTRIES };
