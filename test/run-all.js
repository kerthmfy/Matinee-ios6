'use strict';

/*
 * Runs every offline suite in a fresh process.
 *
 *   npm test              # relay, mocks, DOM, write shape, ObjC, package
 *   npm test -- --live     # also hit letterboxd.com
 *
 * The live suite is opt-in because it depends on the network and on
 * Letterboxd's HTML staying recognizable.
 */

const path = require('path');
const { spawnSync } = require('child_process');

const ROOT = path.join(__dirname, '..');
const live = process.env.MATINEE_LIVE === '1' || process.argv.includes('--live');

const suites = [
  ['relay HTTP API', 'test/relay-api.js'],
  ['TMDB search integration', 'test/relay-search.js'],
  ['Letterboxd write integration', 'test/relay-write.js'],
  ['browser mock', 'test/dom-smoke.js'],
  ['browser mock flows', 'test/dom-flows.js'],
  ['service worker', 'test/sw-cache.js'],
  ['write shape', 'test/write-shape.js'],
  ['Objective-C structure', 'test/objc-sanity.js'],
  ['package and assets', 'test/package.js'],
];

if (live) {
  suites.push(['live Letterboxd', 'test/relay-live.js']);
}

let failed = 0;
for (const [label, file] of suites) {
  console.log('\n\u25b6 ' + label + '  (' + file + ')');
  const result = spawnSync(process.execPath, [file], {
    cwd: ROOT,
    stdio: 'inherit',
    env: process.env,
  });
  if (result.status !== 0) failed++;
}

console.log('');
if (failed) {
  console.log('FAILED: ' + failed + ' of ' + suites.length + ' suites');
  process.exit(1);
}
console.log('ok   all ' + suites.length + ' suites passed');
if (!live) console.log('     (run with --live to include letterboxd.com)');
