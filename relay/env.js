'use strict';

/*
 * Minimal .env reader for the relay.
 *
 * `npm start` goes through relay/start.js, which loads `.env` before the
 * server reads its configuration. Keeping this out of server.js means the
 * integration suites can require the server directly and keep their own
 * environment (including an intentionally unset LB_SESSION_COOKIE).
 *
 * Rules: comments and blank lines are ignored, `export KEY=value` is allowed,
 * matching single or double quotes are stripped, and a value already present
 * in the real environment always wins.
 */

const fs = require('fs');
const path = require('path');

const DEFAULT_FILE = path.join(__dirname, '..', '.env');

function parse(text) {
  const values = {};
  const lines = String(text || '').split(/\r?\n/);
  for (const raw of lines) {
    const line = raw.trim();
    if (!line || line.charAt(0) === '#') continue;
    const match = /^(?:export\s+)?([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*)$/.exec(line);
    if (!match) continue;
    let value = match[2].trim();
    const quote = value.charAt(0);
    if ((quote === '"' || quote === "'") && value.charAt(value.length - 1) === quote) {
      value = value.slice(1, -1);
    }
    values[match[1]] = value;
  }
  return values;
}

function apply(values, target) {
  const env = target || process.env;
  for (const key of Object.keys(values || {})) {
    if (env[key] === undefined) env[key] = values[key];
  }
  return env;
}

function load(file, target) {
  const name = file || DEFAULT_FILE;
  let text;
  try {
    text = fs.readFileSync(name, 'utf8');
  } catch (e) {
    return {};
  }
  const values = parse(text);
  apply(values, target);
  return values;
}

module.exports = { DEFAULT_FILE, parse, apply, load };
