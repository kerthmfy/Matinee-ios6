'use strict';

/* Tiny assertion harness. No dependencies, deterministic exit code. */

const results = [];
const asyncTests = [];

function test(name, fn) {
  try {
    fn();
    results.push({ name, ok: true });
  } catch (err) {
    results.push({ name, ok: false, error: err && err.message ? err.message : String(err) });
  }
}

/**
 * Queue an async test. Existing suites can keep using test(); suites that need
 * network or timers should call runAsync() once after registering tests.
 */
function testAsync(name, fn) {
  asyncTests.push({ name, fn });
}

async function runAsync(label) {
  for (const item of asyncTests) {
    try {
      await item.fn();
      results.push({ name: item.name, ok: true });
    } catch (err) {
      results.push({ name: item.name, ok: false, error: err && err.message ? err.message : String(err) });
    }
  }
  asyncTests.length = 0;
  return report(label);
}

function eq(actual, expected, label) {
  const a = JSON.stringify(actual);
  const e = JSON.stringify(expected);
  if (a !== e) {
    throw new Error((label ? label + ': ' : '') + 'expected ' + e + ', got ' + a);
  }
}

function ok(value, label) {
  if (!value) throw new Error((label || 'assertion') + ' failed');
}

function notOk(value, label) {
  if (value) throw new Error((label || 'assertion') + ' should be falsy');
}

function includes(haystack, needle, label) {
  if (String(haystack).indexOf(needle) === -1) {
    throw new Error((label || 'includes') + ': missing ' + JSON.stringify(needle));
  }
}

function report(label) {
  const pass = results.filter((r) => r.ok).length;
  const fail = results.length - pass;
  for (const r of results) {
    if (!r.ok) console.log('  FAIL  ' + r.name + '\n        ' + r.error);
  }
  console.log(
    (fail ? 'FAIL ' : 'ok   ') + (label || 'tests') + ': ' +
    pass + '/' + results.length + ' passed'
  );
  return fail;
}

module.exports = { test, testAsync, runAsync, eq, ok, notOk, includes, report, results };
