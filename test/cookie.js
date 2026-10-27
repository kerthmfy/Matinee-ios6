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

test('a bare cookie value gets the real session cookie name', () => {
  eq(normalizeCookie('abc123'), COOKIE_NAME + '=abc123');
  eq(normalizeCookie(' abc123 \n'), COOKIE_NAME + '=abc123');
  eq(normalizeCookie('abc=='), COOKIE_NAME + '=abc==');
});

test('a full Cookie header is kept, with the Cookie: prefix removed', () => {
  const full = 'letterboxd.signed.in.as=abc; letterboxd.user.CURRENT=def; cf_clearance=ghi';
  eq(normalizeCookie(full), full);
  eq(normalizeCookie('Cookie: ' + full), full);
  eq(normalizeCookie('"' + full + '"'), full);
});

test('the legacy letterboxd.signed.in name is accepted too', () => {
  eq(normalizeCookie('letterboxd.signed.in=abc'), 'letterboxd.signed.in=abc');
  eq(normalizeCookie('letterboxd.signed.in=abc; other=1'), 'letterboxd.signed.in=abc; other=1');
});

test('empty, multiline, quoted, or unrelated headers are rejected', () => {
  eq(normalizeCookie(''), null);
  eq(normalizeCookie('   '), null);
  eq(normalizeCookie('other=1; another=2'), null);
  eq(normalizeCookie('letterboxd.signed.in.as=abc\r\nX-Evil: 1'), null);
  eq(normalizeCookie("letterboxd.signed.in.as=it's"), null);
});

test('the cookie value is never printed by the mask', () => {
  const masked = maskCookie('letterboxd.signed.in.as=super-secret');
  includes(masked, 'letterboxd.signed.in.as=');
  notOk(masked.indexOf('super-secret') !== -1, 'secret leaked');
});

test('the mask keeps only the name and length of a full header', () => {
  const masked = maskCookie(
    'useMobileSite=no; letterboxd.signed.in.as=super-secret; letterboxd.user.CURRENT=other-secret'
  );
  includes(masked, 'letterboxd.signed.in.as=');
  includes(masked, 'other cookies');
  notOk(masked.indexOf('super-secret') !== -1, 'session value leaked');
  notOk(masked.indexOf('other-secret') !== -1, 'other cookie value leaked');
});

test('.env gets the cookie appended without losing other settings', () => {
  const before = 'PORT=3000\nTMDB_API_KEY=abc\n';
  const cookie = 'letterboxd.signed.in.as=xyz; letterboxd.user.CURRENT=def';
  const after = updateEnvText(before, cookie);
  includes(after, 'PORT=3000');
  includes(after, 'TMDB_API_KEY=abc');
  includes(after, "LB_SESSION_COOKIE='" + cookie + "'");
});

test('an existing cookie line is replaced in place', () => {
  const before = "LB_SESSION_COOKIE='old'\nTMDB_API_KEY=abc\n";
  const after = updateEnvText(before, 'letterboxd.signed.in.as=new');
  notOk(after.indexOf("'old'") !== -1, 'old cookie remains');
  includes(after, "LB_SESSION_COOKIE='letterboxd.signed.in.as=new'");
  eq(after.split('LB_SESSION_COOKIE=').length - 1, 1);
});

test('an exported cookie line is replaced too', () => {
  const after = updateEnvText("export LB_SESSION_COOKIE='old'\n", 'letterboxd.signed.in.as=new');
  includes(after, "LB_SESSION_COOKIE='letterboxd.signed.in.as=new'");
  notOk(after.indexOf('export LB_SESSION_COOKIE') !== -1, 'export left behind');
});

test('writeEnv creates an owner-only file', () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'matinee-cookie-'));
  const file = path.join(dir, '.env');
  const result = writeEnv(file, 'letterboxd.signed.in.as=xyz');
  eq(result.created, true);
  const text = fs.readFileSync(file, 'utf8');
  includes(text, "LB_SESSION_COOKIE='letterboxd.signed.in.as=xyz'");
  eq(fs.statSync(file).mode & 0o777, 0o600);
  fs.rmSync(dir, { recursive: true, force: true });
});

test('writeEnv preserves an existing TMDB key and tightens permissions', () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'matinee-cookie-'));
  const file = path.join(dir, '.env');
  fs.writeFileSync(file, 'TMDB_API_KEY=abc\n', { mode: 0o644 });
  writeEnv(file, 'letterboxd.signed.in.as=xyz');
  const text = fs.readFileSync(file, 'utf8');
  includes(text, 'TMDB_API_KEY=abc');
  includes(text, "LB_SESSION_COOKIE='letterboxd.signed.in.as=xyz'");
  eq(fs.statSync(file).mode & 0o777, 0o600);
  fs.rmSync(dir, { recursive: true, force: true });
});

const failures = report('cookie');
process.exit(failures ? 1 : 0);
