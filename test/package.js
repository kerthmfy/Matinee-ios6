'use strict';

/*
 * Packaging and asset checks.
 *
 * This is the part we can verify without Xcode or an iOS 6 SDK: the Theos
 * scaffold, Info.plist, Xcode build settings, icon dimensions, screenshots,
 * and local documentation links all need to agree before a build is attempted.
 *
 *   node test/package.js
 */

const fs = require('fs');
const path = require('path');
const { spawnSync } = require('child_process');
const { test, eq, ok, notOk, includes, report } = require('./_assert');

const ROOT = path.join(__dirname, '..');

function read(rel) {
  return fs.readFileSync(path.join(ROOT, rel), 'utf8');
}

function exists(rel) {
  return fs.existsSync(path.join(ROOT, rel));
}

function pngSize(rel) {
  const b = fs.readFileSync(path.join(ROOT, rel));
  eq(b.slice(0, 8).toString('hex'), '89504e470d0a1a0a', rel + ' signature');
  return { width: b.readUInt32BE(16), height: b.readUInt32BE(20) };
}

/* ---------- Theos scaffold ---------- */

const makefile = read('packaging/theos/Makefile');
const control = read('packaging/theos/control');

test('Theos Makefile targets iOS 6.0 deployment and armv7 with ARC', () => {
  includes(makefile, 'MATINEE_SDK ?= 11.4');
  includes(makefile, 'TARGET := iphone:clang:$(MATINEE_SDK):6.0');
  includes(makefile, 'ARCHS := armv7');
  includes(makefile, 'Matinee_CFLAGS = -fobjc-arc');
  includes(makefile, 'Wno-error=deprecated-module-dot-map');
  includes(makefile, 'APPLICATION_NAME = Matinee');
  includes(makefile, 'Matinee_INSTALL_PATH = /Applications');
  includes(makefile, 'Matinee_RESOURCE_FILES');
});

test('Theos sources symlink resolves to the Xcode source directory', () => {
  const link = path.join(ROOT, 'packaging', 'theos', 'Matinee');
  ok(fs.lstatSync(link).isSymbolicLink(), 'symlink');
  eq(fs.realpathSync(link), fs.realpathSync(path.join(ROOT, 'Matinee', 'Matinee')));
});

test('Theos control file is a valid iOS 6 app package', () => {
  includes(control, 'Package: com.matinee.app');
  includes(control, 'Architecture: iphoneos-arm');
  includes(control, 'Depends: firmware (>= 6.0)');
  includes(control, 'Section: Entertainment');
  includes(control, 'Version: 1.0');
});

/* ---------- Info.plist ---------- */

const plist = read('Matinee/Matinee/Info.plist');

test('Info.plist declares the iOS 6 floor and armv7 capability', () => {
  includes(plist, '<key>MinimumOSVersion</key>\n\t<string>6.0</string>');
  includes(plist, '<key>UIRequiredDeviceCapabilities</key>');
  includes(plist, '<string>armv7</string>');
  includes(plist, '<key>LSRequiresIPhoneOS</key>');
});

test('Info.plist has literal bundle names, not unexpanded Xcode variables', () => {
  includes(plist, '<key>CFBundleExecutable</key>\n\t<string>Matinee</string>');
  includes(plist, '<key>CFBundleName</key>\n\t<string>Matinee</string>');
  notOk(plist.includes('${'), 'unexpanded build setting');
});

test('Info.plist icon names resolve to files in Resources', () => {
  for (const name of ['Icon', 'Icon@2x', 'Icon-72', 'Icon-72@2x']) {
    ok(exists('Matinee/Matinee/Resources/' + name + '.png'), name + '.png');
  }
});

test('Info.plist allows the iPad split view orientations', () => {
  for (const orientation of [
    'UIInterfaceOrientationPortrait',
    'UIInterfaceOrientationPortraitUpsideDown',
    'UIInterfaceOrientationLandscapeLeft',
    'UIInterfaceOrientationLandscapeRight',
  ]) {
    includes(plist, '<string>' + orientation + '</string>');
  }
});

test('plutil accepts the plist and Xcode project', () => {
  for (const rel of ['Matinee/Matinee/Info.plist', 'Matinee/Matinee.xcodeproj/project.pbxproj']) {
    const result = spawnSync('plutil', ['-lint', path.join(ROOT, rel)], { encoding: 'utf8' });
    if (result.error && result.error.code === 'ENOENT') return;
    eq(result.status, 0, rel + ': ' + (result.stdout || result.stderr));
  }
});

/* ---------- Xcode project ---------- */

const pbx = read('Matinee/Matinee.xcodeproj/project.pbxproj');

test('Xcode project builds armv7 with ARC for iOS 6', () => {
  includes(pbx, 'ARCHS = armv7;');
  includes(pbx, 'VALID_ARCHS = armv7;');
  includes(pbx, 'CLANG_ENABLE_OBJC_ARC = YES;');
  includes(pbx, 'IPHONEOS_DEPLOYMENT_TARGET = 6.0;');
  includes(pbx, 'TARGETED_DEVICE_FAMILY = "1,2";');
});

test('every Objective-C source is in the Xcode Sources phase', () => {
  const sources = fs.readdirSync(path.join(ROOT, 'Matinee', 'Matinee'))
    .filter((name) => name.endsWith('.m'));
  ok(sources.length >= 10, 'sources: ' + sources.length);
  for (const name of sources) {
    includes(pbx, '/* ' + name + ' in Sources */');
  }
});

/* ---------- configuration ---------- */

test('the relay loads .env without overriding the real environment', () => {
  const pkg = JSON.parse(read('package.json'));
  includes(pkg.scripts.start, 'relay/start.js');
  includes(read('relay/start.js'), "require('./env').load()");
  notOk(/process\.env\.TMDB_API_KEY\s*\|\|\s*'[^']+'/.test(read('relay/server.js')), 'TMDB key fallback');

  const env = require('../relay/env');
  eq(env.parse('A=1\n# comment\nB="two words"\nexport C=3\n'), {
    A: '1',
    B: 'two words',
    C: '3',
  });

  const before = process.env.MATINEE_ENV_KEEP;
  process.env.MATINEE_ENV_KEEP = 'real';
  try {
    env.apply({ MATINEE_ENV_KEEP: 'file', MATINEE_ENV_NEW: 'new' });
    eq(process.env.MATINEE_ENV_KEEP, 'real');
    eq(process.env.MATINEE_ENV_NEW, 'new');
  } finally {
    delete process.env.MATINEE_ENV_NEW;
    if (before === undefined) delete process.env.MATINEE_ENV_KEEP;
    else process.env.MATINEE_ENV_KEEP = before;
  }
});

/* ---------- icons ---------- */

const ICONS = [
  ['Matinee/Matinee/Resources/Icon.png', 57],
  ['Matinee/Matinee/Resources/Icon@2x.png', 114],
  ['Matinee/Matinee/Resources/Icon-72.png', 72],
  ['Matinee/Matinee/Resources/Icon-72@2x.png', 144],
  ['Matinee/Matinee/Resources/iTunesArtwork.png', 512],
  ['web/icon-57.png', 57],
  ['web/icon-72.png', 72],
  ['web/icon-114.png', 114],
  ['web/icon-144.png', 144],
  ['web/icon-180.png', 180],
  ['web/icon-192.png', 192],
  ['web/icon-512.png', 512],
];

test('every app and web icon is a square PNG at the declared size', () => {
  for (const [rel, size] of ICONS) {
    const dim = pngSize(rel);
    eq(dim, { width: size, height: size }, rel);
  }
});

test('the web manifest icons exist and match their declared sizes', () => {
  const manifest = JSON.parse(read('web/manifest.webmanifest'));
  eq(manifest.display, 'standalone');
  eq(manifest.start_url, './');
  for (const icon of manifest.icons) {
    const rel = 'web/' + icon.src;
    ok(exists(rel), icon.src);
    const [w, h] = icon.sizes.split('x').map(Number);
    eq(pngSize(rel), { width: w, height: h }, icon.src);
  }
  ok(exists('web/icon.svg'), 'favicon');
  ok(exists('web/sw.js'), 'service worker');
  const sw = read('web/sw.js');
  includes(sw, "const CACHE = 'matinee-posters-v1'");
  includes(sw, "res.type === 'opaque'");
  includes(sw, '.put(event.request, res.clone())');
  includes(sw, 'event.waitUntil(write)');
});

test('the four README screenshots are the expected 640x960 frames', () => {
  for (const name of ['diary', 'film', 'log-sheet', 'profile']) {
    eq(pngSize('docs/screenshots/' + name + '.png'), { width: 640, height: 960 }, name);
  }
});

/* ---------- docs ---------- */

test('local images and links in README and GUIDE resolve', () => {
  for (const doc of ['README.md', 'docs/GUIDE.md']) {
    const body = read(doc);
    for (const match of body.matchAll(/<img\s+[^>]*src="([^"]+)"/g)) {
      ok(exists(path.join(path.dirname(doc), match[1])), doc + ' -> ' + match[1]);
    }
    const links = [...body.matchAll(/\]\(([^)]+)\)/g)].map((m) => m[1]);
    for (const link of links) {
      if (/^(https?:|mailto:|#)/.test(link)) continue;
      const clean = link.split('#')[0].split('?')[0];
      if (!clean) continue;
      ok(exists(path.join(path.dirname(doc), clean)), doc + ' -> ' + link);
    }
  }
});

test('the offline and live test commands are documented', () => {
  const pkg = JSON.parse(read('package.json'));
  includes(pkg.scripts.test, 'run-all.js');
  includes(pkg.scripts['test:relay'], 'relay-live.js');
  includes(read('README.md'), 'npm test');
  includes(read('docs/GUIDE.md'), 'relay');
});

/* ---------- summary ---------- */

const fails = report('package');
process.exit(fails ? 1 : 0);
