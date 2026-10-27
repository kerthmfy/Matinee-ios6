'use strict';

/*
 * Test-only TLS plumbing.
 *
 * The relay talks to Letterboxd and TMDB over HTTPS. Integration tests point
 * the test-only origin overrides at a local self-signed server, so the real
 * request code runs without touching the internet.
 */

const { execFileSync } = require('child_process');
const fs = require('fs');
const https = require('https');
const os = require('os');
const path = require('path');

function makeCertificate() {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'matinee-tls-'));
  const keyFile = path.join(dir, 'key.pem');
  const certFile = path.join(dir, 'cert.pem');
  const configFile = path.join(dir, 'openssl.cnf');
  // A config file works on both LibreSSL and OpenSSL 1.1/3.x; `-addext` is
  // not available everywhere the test suite may run.
  fs.writeFileSync(
    configFile,
    '[req]\n' +
      'distinguished_name = dn\n' +
      'x509_extensions = v3\n' +
      'prompt = no\n' +
      '[dn]\n' +
      'CN = 127.0.0.1\n' +
      '[v3]\n' +
      'subjectAltName = IP:127.0.0.1\n'
  );
  execFileSync(
    'openssl',
    [
      'req', '-x509', '-newkey', 'rsa:2048', '-nodes',
      '-keyout', keyFile, '-out', certFile,
      '-days', '1', '-config', configFile,
    ],
    { stdio: 'ignore' }
  );
  return {
    key: fs.readFileSync(keyFile),
    cert: fs.readFileSync(certFile),
    cleanup() {
      fs.rmSync(dir, { recursive: true, force: true });
    },
  };
}

function listen(server) {
  return new Promise((resolve, reject) => {
    server.once('error', reject);
    server.listen(0, '127.0.0.1', () => resolve(server.address().port));
  });
}

function close(server) {
  return new Promise((resolve) => server.close(resolve));
}

async function startTls(handler) {
  const tls = makeCertificate();
  const server = https.createServer({ key: tls.key, cert: tls.cert }, handler);
  const port = await listen(server);
  return {
    server,
    port,
    origin: 'https://127.0.0.1:' + port,
    async stop() {
      await close(server);
      tls.cleanup();
    },
  };
}

module.exports = { makeCertificate, listen, close, startTls };
