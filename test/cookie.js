'use strict';

/*
 * Cookie-capture helper tests.
 *
 * These are pure: normalization, .env editing, permissions, and masking. The
 * network validation is exercised in relay-write.js against the local mock.
 *
 *   node test/cookie.js
 */

const fs = require('fs');
const os = require('os');
const path = require('path');
const { test, eq, notOk, includes, report } = require('./_assert');
const {
  COOKIE_NAME,
  normalizeCookie,
  maskCookie,
  updateEnvText,
  writeEnv,
} = require('../relay/cookie');

test('a bare cookie value gets the Letterboxd name', () => {
  eq(normalizeCookie('abc123'), COOKIE_NAME + '=abc123');
  eq(normalizeCookie(' abc123 \n'), COOKIE_NAME + '=abc123');
  eq(normalizeCookie('abc=='), COOKIE_NAME + '=abc==');
});

test('a full Cookie header is kept, with the Cookie: prefix removed', () => {
  eq(normalizeCookie('letterboxd.signed.in=abc; other=1'), 'letterboxd.signed.in=abc; other=1');
  eq(normalizeCookie('Cookie: letterboxd.signed.in=abc'), 'letterboxd.signed.in=abc');
  eq(normalizeCookie('"letterboxd.signed.in=abc"'), 'letterboxd.signed.in=abc');
});

test('empty, multiline, quoted, or unrelated headers are rejected', () => {
  eq(normalizeCookie(''), null);
  eq(normalizeCookie('   '), null);
  eq(normalizeCookie('other=1; another=2'), null);
  eq(normalizeCookie('letterboxd.signed.in=abc\r\nX-Evil: 1'), null);
  eq(normalizeCookie("letterboxd.signed.in=it's"), null);
});

test('the cookie value is never printed by the mask', () => {
  const masked = maskCookie('letterboxd.signed.in=super-secret');
  includes(masked, 'letterboxd.signed.in=');
  notOk(masked.indexOf('super-secret') !== -1, 'secret leaked');
});

test('.env gets the cookie appended without losing other settings', () => {
  const before = 'PORT=3000\nTMDB_API_KEY=abc\n';
  const after = updateEnvText(before, 'letterboxd.signed.in=xyz');
  includes(after, 'PORT=3000');
  includes(after, 'TMDB_API_KEY=abc');
  includes(after, "LB_SESSION_COOKIE='letterboxd.signed.in=xyz'");
});

test('an existing cookie line is replaced in place', () => {
  const before = "LB_SESSION_COOKIE='old'\nTMDB_API_KEY=abc\n";
  const after = updateEnvText(before, 'letterboxd.signed.in=new');
  notOk(after.indexOf("'old'") !== -1, 'old cookie remains');
  includes(after, "LB_SESSION_COOKIE='letterboxd.signed.in=new'");
  eq(after.split('LB_SESSION_COOKIE=').length - 1, 1);
});

test('an exported cookie line is replaced too', () => {
  const after = updateEnvText("export LB_SESSION_COOKIE='old'\n", 'letterboxd.signed.in=new');
  includes(after, "LB_SESSION_COOKIE='letterboxd.signed.in=new'");
  notOk(after.indexOf('export LB_SESSION_COOKIE') !== -1, 'export left behind');
});

test('writeEnv creates an owner-only file', () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'matinee-cookie-'));
  const file = path.join(dir, '.env');
  const result = writeEnv(file, 'letterboxd.signed.in=xyz');
  eq(result.created, true);
  const text = fs.readFileSync(file, 'utf8');
  includes(text, "LB_SESSION_COOKIE='letterboxd.signed.in=xyz'");
  eq(fs.statSync(file).mode & 0o777, 0o600);
  fs.rmSync(dir, { recursive: true, force: true });
});

test('writeEnv preserves an existing TMDB key and tightens permissions', () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'matinee-cookie-'));
  const file = path.join(dir, '.env');
  fs.writeFileSync(file, 'TMDB_API_KEY=abc\n', { mode: 0o644 });
  writeEnv(file, 'letterboxd.signed.in=xyz');
  const text = fs.readFileSync(file, 'utf8');
  includes(text, 'TMDB_API_KEY=abc');
  includes(text, "LB_SESSION_COOKIE='letterboxd.signed.in=xyz'");
  eq(fs.statSync(file).mode & 0o777, 0o600);
  fs.rmSync(dir, { recursive: true, force: true });
});

const failures = report('cookie');
process.exit(failures ? 1 : 0);
