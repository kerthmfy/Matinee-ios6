'use strict';

/*
 * Service-worker cache tests.
 *
 * The poster cache is part of the installable mock, but jsdom does not
 * implement service workers. Run web/sw.js in a small fake worker scope
 * instead, so the opaque-response and cache-write behavior is tested without
 * a browser.
 *
 *   node test/sw-cache.js
 */

const fs = require('fs');
const path = require('path');
const vm = require('vm');
const { testAsync, runAsync, eq, ok, notOk } = require('./_assert');

const source = fs.readFileSync(path.join(__dirname, '..', 'web', 'sw.js'), 'utf8');

function makeWorker() {
  const listeners = {};
  const messages = [];
  const store = new Map();
  let fetched = 0;
  let fetchImpl = async () => response({ ok: true, status: 200, type: 'basic' });

  const cache = {
    async match(request) {
      return store.get(request.url);
    },
    async put(request, res) {
      store.set(request.url, res);
      return res;
    },
  };
  const caches = {
    async open() {
      return cache;
    },
    async keys() {
      return [...store.keys()];
    },
    async delete() {
      return true;
    },
  };
  const self = {
    addEventListener(type, fn) {
      listeners[type] = fn;
    },
    skipWaiting() {},
    clients: {
      claim() {},
      async matchAll() {
        return [{ postMessage: (message) => messages.push(message) }];
      },
    },
  };

  const context = vm.createContext({
    self,
    caches,
    URL,
    fetch: async (request) => {
      fetched++;
      return fetchImpl(request);
    },
    console,
  });
  vm.runInContext(source, context, { filename: 'web/sw.js' });

  function dispatch(request) {
    let responsePromise = null;
    const waits = [];
    listeners.fetch({
      request,
      respondWith(promise) {
        responsePromise = promise;
      },
      waitUntil(promise) {
        waits.push(promise);
      },
    });
    return { responsePromise, waits };
  }

  return {
    dispatch,
    store,
    messages,
    get fetched() {
      return fetched;
    },
    setFetch(fn) {
      fetchImpl = fn;
    },
  };
}

function response(fields) {
  return Object.assign(
    {
      clone() {
        return this;
      },
    },
    fields
  );
}

async function main() {
  const request = { url: 'https://a.ltrbxd.com/resized/poster.jpg', method: 'GET' };

  testAsync('an opaque cross-origin poster is cached and announced', async () => {
    const worker = makeWorker();
    const opaque = response({ ok: false, status: 0, type: 'opaque' });
    worker.setFetch(async () => opaque);

    const { responsePromise, waits } = worker.dispatch(request);
    ok(responsePromise, 'respondWith called');
    eq(await responsePromise, opaque);
    await Promise.all(waits);

    eq(worker.fetched, 1);
    ok(worker.store.has(request.url), 'poster in cache');
    eq(worker.messages, [{ type: 'poster-cached' }]);
  });

  testAsync('a cache hit returns without fetching the CDN', async () => {
    const worker = makeWorker();
    const hit = response({ ok: true, status: 200, type: 'basic' });
    worker.store.set(request.url, hit);

    const { responsePromise, waits } = worker.dispatch(request);
    eq(await responsePromise, hit);
    eq(await Promise.all(waits), []);
    eq(worker.fetched, 0);
  });

  testAsync('non-poster and non-GET requests pass through untouched', async () => {
    const worker = makeWorker();
    const foreign = worker.dispatch({ url: 'https://example.com/x.jpg', method: 'GET' });
    const post = worker.dispatch({ url: 'https://a.ltrbxd.com/poster.jpg', method: 'POST' });
    notOk(foreign.responsePromise, 'foreign host');
    notOk(post.responsePromise, 'POST');
    eq(worker.fetched, 0);
  });

  testAsync('a non-OK, non-opaque response is returned but not cached', async () => {
    const worker = makeWorker();
    const notFound = response({ ok: false, status: 404, type: 'basic' });
    worker.setFetch(async () => notFound);

    const { responsePromise, waits } = worker.dispatch(request);
    eq(await responsePromise, notFound);
    await Promise.all(waits);
    eq(worker.store.has(request.url), false);
    eq(worker.messages.length, 0);
  });

  const fails = await runAsync('service-worker');
  process.exit(fails ? 1 : 0);
}

main().catch((err) => {
  console.error('sw-cache: fatal ' + (err && err.stack ? err.stack : err));
  process.exit(1);
});
