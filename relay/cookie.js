'use strict';

/*
 * Save a real letterboxd.com session cookie into the relay's .env.
 *
 * Cloudflare blocks the sign-in page, so the cookie has to come from a
 * browser where the member has already signed in. This helper keeps that
 * hand-off boring and safe:
 *
 *   - the value is read from stdin (use `pbpaste` on macOS), never argv,
 *   - it is validated against a public film page before it replaces a
 *     working cookie,
 *   - .env is written with mode 0600,
 *   - the value is never printed.
 *
 * The app and the relay never log the cookie. Treat it like a password.
 */

const fs = require('fs');
const path = require('path');
const lb = require('./lb');

const COOKIE_NAME = 'letterboxd.signed.in.as';
const SESSION_PREFIX = 'letterboxd.signed.in';
const SESSION_COOKIE_RE = /(?:^|;\s*)(letterboxd\.signed\.in(?:\.[A-Za-z0-9_-]+)*)=([^;]*)/;
const SESSION_PAIR_RE = /^letterboxd\.signed\.in(?:\.[A-Za-z0-9_-]+)*=/;
const DEFAULT_ENV = path.join(__dirname, '..', '.env');
const DEFAULT_SLUG = 'primer';

/**
 * Accept either the bare cookie value or a full Cookie header. Returns a
 * header-safe cookie string, or null when the input is not usable. A full
 * header is preferred: Letterboxd's real session spans
 * `letterboxd.signed.in.as` and `letterboxd.user.CURRENT`, so copying the
 * whole header is more reliable than copying one value. Newlines and single
 * quotes are rejected so the value cannot break the .env line or an HTTP
 * header.
 */
function normalizeCookie(input) {
  if (typeof input !== 'string') return null;
  let value = input.trim();
  if (!value) return null;
  value = value.replace(/^Cookie:\s*/i, '').trim();
  if (
    (value.charAt(0) === '"' && value.charAt(value.length - 1) === '"') ||
    (value.charAt(0) === "'" && value.charAt(value.length - 1) === "'")
  ) {
    value = value.slice(1, -1).trim();
  }
  if (!value) return null;
  if (/[\r\n']/.test(value)) return null;

  if (value.indexOf(';') !== -1) {
    // A full Cookie header is only useful if it carries a session cookie.
    return SESSION_COOKIE_RE.test(value) ? value : null;
  }
  if (SESSION_PAIR_RE.test(value)) {
    return value;
  }
  // Be forgiving about base64 padding: a bare value is allowed to contain
  // '='. Validation will reject anything that is not actually a session.
  return COOKIE_NAME + '=' + value;
}

/** A safe label for logs. Never return the cookie value. */
function maskCookie(cookie) {
  if (!cookie) return '(none)';
  const match = SESSION_COOKIE_RE.exec(cookie);
  if (match) {
    const others = cookie.indexOf(';') !== -1 ? ' + other cookies' : '';
    return match[1] + '=…(' + match[2].length + ' chars)' + others;
  }
  const eq = cookie.indexOf('=');
  if (eq === -1) return SESSION_PREFIX + '=…';
  return cookie.slice(0, eq + 1) + '…(' + (cookie.length - eq - 1) + ' chars)';
}

/**
 * Replace the active LB_SESSION_COOKIE line, or append one. Everything else
 * in .env, including the TMDB key and comments, is preserved.
 */
function updateEnvText(text, cookie) {
  const line = "LB_SESSION_COOKIE='" + cookie + "'";
  const source = String(text || '').replace(/\r\n/g, '\n');
  const lines = source.split('\n');
  let found = false;
  const out = lines.map((current) => {
    if (/^\s*(?:export\s+)?LB_SESSION_COOKIE\s*=/.test(current)) {
      found = true;
      return line;
    }
    return current;
  });
  if (!found) {
    while (out.length && out[out.length - 1] === '') out.pop();
    if (out.length) out.push('');
    out.push('# Letterboxd session cookie. Gitignored; never commit or share.');
    out.push(line);
    out.push('');
  }
  return out.join('\n');
}

/** Write the cookie into .env with owner-only permissions. */
function writeEnv(file, cookie, options) {
  const target = file || DEFAULT_ENV;
  let current = '';
  try {
    current = fs.readFileSync(target, 'utf8');
  } catch (err) {
    if (err.code !== 'ENOENT') throw err;
  }
  const next = updateEnvText(current, cookie);
  fs.writeFileSync(target, next, { mode: 0o600 });
  try {
    fs.chmodSync(target, 0o600);
  } catch (err) {
    /* best effort on filesystems without chmod */
  }
  return {
    file: target,
    changed: next !== current,
    created: !current,
    mode: options && options.mode,
  };
}

/**
 * Ask Letterboxd whether the cookie is signed in. A public film page is
 * enough: a signed-in page sets person.loggedIn = true and carries a member
 * CSRF token; a signed-out page does not.
 */
async function validateCookie(cookie, options) {
  if (!cookie) return { ok: false, reason: 'no_session' };
  const slug = (options && options.slug) || DEFAULT_SLUG;
  try {
    const film = lb.parseFilm((await lb.fetchFilm(slug, cookie)).html, slug);
    return {
      ok: true,
      signedIn: film.signedIn,
      slug,
      uid: Boolean(film.uid),
      csrf: Boolean(film.csrf),
    };
  } catch (err) {
    return {
      ok: false,
      reason: 'network',
      slug,
      detail: String((err && err.message) || err),
    };
  }
}

function readStdin() {
  return new Promise((resolve, reject) => {
    const chunks = [];
    process.stdin.on('data', (chunk) => chunks.push(chunk));
    process.stdin.on('end', () => resolve(Buffer.concat(chunks).toString('utf8')));
    process.stdin.on('error', reject);
    process.stdin.resume();
  });
}

function usage() {
  return [
    'Usage:',
    '  pbpaste | npm run cookie            # validate and save',
    '  pbpaste | npm run cookie -- --force # save even if validation fails',
    '  pbpaste | npm run cookie -- --no-verify',
    '',
    'Copy the full Cookie request header from your signed-in browser',
    '(DevTools > Network > Headers > Request Headers > Cookie). The value',
    'is read from stdin and never printed.',
  ].join('\n');
}

async function main() {
  const args = process.argv.slice(2);
  const force = args.includes('--force');
  const verify = !args.includes('--no-verify');

  if (process.stdin.isTTY) {
    console.error(usage());
    process.exit(2);
  }

  const raw = await readStdin();
  const cookie = normalizeCookie(raw);
  if (!cookie) {
    console.error('That does not look like a Letterboxd session cookie.');
    console.error(usage());
    process.exit(2);
  }

  let result = null;
  if (verify) {
    result = await validateCookie(cookie);
    if (!result.ok || !result.signedIn) {
      const why = result.reason === 'network'
        ? 'The relay could not reach Letterboxd: ' + result.detail
        : 'Letterboxd did not mark this browser session as signed in.';
      if (!force) {
        console.error('Not saved. ' + why);
        console.error('Log in again, copy the full Cookie header, or re-run with --force.');
        process.exit(1);
      }
      console.error('Warning: ' + why);
      console.error('Saving anyway because --force was passed.');
    }
  }

  const saved = writeEnv(DEFAULT_ENV, cookie);
  console.log('Saved ' + maskCookie(cookie) + ' to ' + saved.file + '.');
  if (result && result.signedIn) {
    console.log('Letterboxd accepted the cookie; the relay can now post diary entries.');
  } else if (!verify) {
    console.log('Validation skipped. Use Profile → Test session after restarting.');
  }
  console.log('Restart the relay (Ctrl-C, then `npm start`) to load it.');
}

if (require.main === module) {
  main().catch((err) => {
    console.error('cookie: ' + ((err && err.message) || err));
    process.exit(1);
  });
}

module.exports = {
  COOKIE_NAME,
  SESSION_PREFIX,
  DEFAULT_ENV,
  DEFAULT_SLUG,
  normalizeCookie,
  maskCookie,
  updateEnvText,
  writeEnv,
  validateCookie,
};
