'use strict';

/*
 * Secret hygiene.
 *
 * This suite fails if a real credential is tracked. It is deliberately
 * conservative: it looks for high-risk shapes, never prints a value, and, when
 * a local `.env` exists, also checks that none of its values appear in any
 * tracked file. Run it before every push.
 *
 *   node test/secrets.js
 */

const { execSync } = require('child_process');
const fs = require('fs');
const path = require('path');
const { test, ok, notOk, report } = require('./_assert');
const { parse } = require('../relay/env');

const ROOT = path.join(__dirname, '..');

function git(args) {
  return execSync('git ' + args, { cwd: ROOT, encoding: 'buffer' }).toString('utf8');
}

let tracked = [];
try {
  tracked = git('ls-files -z').split('\0').filter(Boolean);
} catch (e) {
  tracked = [];
}

function read(file) {
  const full = path.join(ROOT, file);
  const stat = fs.statSync(full);
  if (!stat.isFile() || stat.size > 2 * 1024 * 1024) return null;
  const text = fs.readFileSync(full, 'utf8');
  return text.indexOf('\0') === -1 ? text : null;
}

function lineAt(text, index) {
  return text.slice(0, index).split('\n').length;
}

function isPlaceholder(value) {
  if (!value || value.length < 20) return true;
  if (/[<>…]/.test(value)) return true;
  if (/(?:placeholder|paste|example|fake|dummy|fixture|test|old|new|xyz|abc)/i.test(value)) return true;
  return false;
}

const textFile = /\.(?:js|mjs|cjs|json|md|m|h|plist|sh|yml|yaml|txt|html|css|example|gitignore)$/i;

const patterns = [
  ['TMDB API key', /TMDB_API_KEY\s*=\s*['"]?([A-Za-z0-9]{20,})/g],
  ['Letterboxd session header', /LB_SESSION_COOKIE\s*=\s*['"]?([^'"\s]{20,})/g],
  ['Letterboxd user token', /letterboxd\.user\.CURRENT\s*=\s*([^;'"\s]{20,})/g],
  ['Letterboxd CSRF token', /supermodelCSRF\s*=\s*['"]([^'"]{12,})['"]/g],
  ['Cloudflare clearance', /cf_clearance\s*=\s*([^;'"\s]{20,})/g],
  ['AWS access key', /AKIA[0-9A-Z]{16}/g],
  ['GitHub token', /gh[pousr]_[A-Za-z0-9]{30,}/g],
  ['OpenAI key', /sk-[A-Za-z0-9]{20,}/g],
  ['Google API key', /AIza[0-9A-Za-z_-]{35}/g],
  ['private key', /-----BEGIN [A-Z ]*PRIVATE KEY-----/g],
];

test('.env and .env.local are not tracked', () => {
  notOk(tracked.includes('.env'), '.env is tracked');
  notOk(tracked.includes('.env.local'), '.env.local is tracked');
});

test('.env is ignored', () => {
  let ignored = false;
  try {
    execSync('git check-ignore -q .env', { cwd: ROOT });
    ignored = true;
  } catch (e) {
    ignored = false;
  }
  ok(ignored, '.env is not in .gitignore');
});

test('tracked text files contain no high-risk secret shapes', () => {
  const findings = [];
  for (const file of tracked) {
    if (file === 'test/secrets.js' || !textFile.test(file)) continue;
    const text = read(file);
    if (!text) continue;
    for (const [label, pattern] of patterns) {
      pattern.lastIndex = 0;
      let match;
      while ((match = pattern.exec(text))) {
        const value = match[1] || match[0];
        if (isPlaceholder(value)) continue;
        // The docs show the variable name inside greps and examples. A real
        // session value always contains a cookie name, not a grep alternation.
        if (label === 'Letterboxd session header' && !/letterboxd\.[a-z]/i.test(value)) continue;
        findings.push(label + ' at ' + file + ':' + lineAt(text, match.index));
      }
    }
  }
  ok(findings.length === 0, findings.join('; '));
});

test('no value from the local .env appears in a tracked file', () => {
  const envFile = path.join(ROOT, '.env');
  if (!fs.existsSync(envFile)) return;

  const env = parse(fs.readFileSync(envFile, 'utf8'));
  const secrets = [];
  if (env.TMDB_API_KEY) secrets.push(env.TMDB_API_KEY);
  if (env.LB_SESSION_COOKIE) {
    secrets.push(env.LB_SESSION_COOKIE);
    for (const part of env.LB_SESSION_COOKIE.split(';')) {
      const pair = part.trim();
      const eq = pair.indexOf('=');
      if (eq < 0) continue;
      const name = pair.slice(0, eq);
      const value = pair.slice(eq + 1);
      // .as is the public handle, not a credential.
      if (name === 'letterboxd.signed.in.as') continue;
      if (value.length >= 12) secrets.push(value);
    }
  }

  const findings = [];
  for (const file of tracked) {
    if (file === '.env' || !textFile.test(file)) continue;
    const text = read(file);
    if (!text) continue;
    for (const secret of secrets) {
      if (text.includes(secret)) findings.push(file);
    }
  }
  ok(findings.length === 0, 'local .env value found in: ' + [...new Set(findings)].join(', '));
});

const failures = report('secrets');
process.exit(failures ? 1 : 0);
