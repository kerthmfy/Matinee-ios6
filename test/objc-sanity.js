'use strict';

/*
 * Structural checks for the hand-written UIKit target.
 *
 * This suite is structural; it does not compile. The Theos package build is
 * the compile check. Here we verify every source is present, every local
 * import resolves, every .m is in the Xcode target, and no iOS 7+ API slipped
 * in.
 *
 *   node test/objc-sanity.js
 */

const fs = require('fs');
const path = require('path');
const { test, eq, ok, notOk, includes, report } = require('./_assert');

const ROOT = path.join(__dirname, '..');
const SRC = path.join(ROOT, 'Matinee', 'Matinee');
const PBX = path.join(ROOT, 'Matinee', 'Matinee.xcodeproj', 'project.pbxproj');
const PLIST = path.join(SRC, 'Info.plist');
const RESOURCES = path.join(SRC, 'Resources');

const EXPECTED = [
  'MTAppearance', 'MTAppDelegate', 'MTDiaryViewController', 'MTFilmViewController',
  'MTImageCache', 'MTListsViewController', 'MTLogViewController', 'MTMarkView',
  'MTModels', 'MTProfileViewController', 'MTRelay', 'MTSearchViewController',
  'MTStarsView', 'MTStore',
];

const sourceFiles = fs.readdirSync(SRC).filter((name) => /\.(m|h)$/.test(name));
const objcFiles = sourceFiles.filter((name) => name.endsWith('.m'));
const pbx = fs.readFileSync(PBX, 'utf8');
const plist = fs.readFileSync(PLIST, 'utf8');

function read(name) {
  return fs.readFileSync(path.join(SRC, name), 'utf8');
}

function stripComments(source) {
  return source
    .replace(/\/\*[\s\S]*?\*\//g, '')
    .replace(/(^|[^:])\/\/.*$/gm, '$1');
}

/* ------------------------------------------------------------------ */
/* Files                                                              */
/* ------------------------------------------------------------------ */

test('every expected screen and support class exists', () => {
  for (const stem of EXPECTED) {
    ok(fs.existsSync(path.join(SRC, stem + '.h')), stem + '.h');
    ok(fs.existsSync(path.join(SRC, stem + '.m')), stem + '.m');
  }
});

test('app entry point, prefix header, and Info.plist exist', () => {
  ok(fs.existsSync(path.join(SRC, 'main.m')), 'main.m');
  ok(fs.existsSync(path.join(SRC, 'Matinee-Prefix.pch')), 'prefix');
  ok(fs.existsSync(PLIST), 'Info.plist');
  includes(read('main.m'), 'UIApplicationMain', 'main.m');
  includes(read('main.m'), 'MTAppDelegate', 'main.m');
});

test('all Objective-C sources are non-empty', () => {
  for (const name of sourceFiles) {
    ok(fs.statSync(path.join(SRC, name)).size > 120, name + ' is suspiciously small');
  }
});

test('no storyboard, xib, or asset-catalog UI', () => {
  const all = fs.readdirSync(SRC).join('\n') + '\n' + pbx;
  notOk(/\.(storyboard|xib)\b/.test(all), 'nib/storyboard reference');
  notOk(/\.xcassets/.test(all), 'asset catalog');
  notOk(/loadNibNamed|initWithNibName:@"[^"]+"/.test(all), 'nib loading');
});

/* ------------------------------------------------------------------ */
/* Headers and imports                                                */
/* ------------------------------------------------------------------ */

test('every quoted import resolves to a real file', () => {
  const missing = [];
  for (const name of sourceFiles) {
    const source = read(name);
    const imports = source.matchAll(/^#import\s+"([^"]+)"/gm);
    for (const match of imports) {
      const target = path.join(SRC, match[1]);
      if (!fs.existsSync(target)) missing.push(name + ' -> ' + match[1]);
    }
  }
  eq(missing, [], 'unresolved imports');
});

test('every @interface / @implementation has an @end', () => {
  for (const name of sourceFiles.filter((n) => n.endsWith('.m') || n.endsWith('.h'))) {
    const source = stripComments(read(name));
    const opens = (source.match(/@interface\b/g) || []).length +
                  (source.match(/@implementation\b/g) || []).length;
    const closes = (source.match(/@end\b/g) || []).length;
    eq(closes, opens, name + ' @end balance');
  }
});

test('headers use forward declarations for cross-screen detail classes', () => {
  const lists = read('MTListsViewController.m');
  includes(lists, '@interface MTListDetailViewController', 'forward declaration');
  ok(lists.indexOf('@interface MTListDetailViewController') <
     lists.indexOf('MTListDetailViewController alloc'), 'declared before use');
});

/* ------------------------------------------------------------------ */
/* Xcode project                                                      */
/* ------------------------------------------------------------------ */

test('project file is structurally balanced', () => {
  const opens = (pbx.match(/\{/g) || []).length;
  const closes = (pbx.match(/\}/g) || []).length;
  eq(closes, opens, 'brace balance');
  includes(pbx, 'objectVersion = 46', 'objectVersion');
  includes(pbx, 'productType = "com.apple.product-type.application"', 'app target');
});

test('every .m file is in the Sources build phase', () => {
  const phase = pbx.slice(pbx.indexOf('/* Begin PBXSourcesBuildPhase section */'),
                          pbx.indexOf('/* End PBXSourcesBuildPhase section */'));
  for (const name of objcFiles) {
    includes(phase, name, name + ' in Sources');
  }
  const compiled = (phase.match(/in Sources \*\//g) || []).length;
  eq(compiled, objcFiles.length, 'compiled source count');
});

test('every source file has a PBXFileReference', () => {
  for (const name of sourceFiles) {
    includes(pbx, 'path = ' + name + ';', name);
  }
});

test('iOS 6 deployment target and ARC are set', () => {
  const targets = (pbx.match(/IPHONEOS_DEPLOYMENT_TARGET = 6\.0;/g) || []).length;
  eq(targets, 4, 'project and target, Debug and Release');
  includes(pbx, 'CLANG_ENABLE_OBJC_ARC = YES;', 'ARC');
  includes(pbx, 'GCC_PREFIX_HEADER = "Matinee/Matinee-Prefix.pch";', 'prefix header');
  includes(pbx, 'INFOPLIST_FILE = Matinee/Info.plist;', 'Info.plist');
});

test('Info.plist declares armv7 and loose icon files', () => {
  includes(plist, '<string>armv7</string>', 'armv7');
  const match = plist.match(/<key>CFBundleIconFiles<\/key>\s*<array>([\s\S]*?)<\/array>/);
  ok(match, 'CFBundleIconFiles');
  const icons = [...match[1].matchAll(/<string>([^<]+)<\/string>/g)].map((m) => m[1]);
  ok(icons.length >= 4, 'four icon slots');
  for (const icon of icons) {
    ok(fs.existsSync(path.join(RESOURCES, icon + '.png')), icon + '.png');
  }
});

/* ------------------------------------------------------------------ */
/* iOS 6 APIs only                                                    */
/* ------------------------------------------------------------------ */

const BANNED = [
  ['NSURLSession', 'iOS 7 networking'],
  ['UIAlertController', 'iOS 8 alerts'],
  ['UIAlertAction', 'iOS 8 alerts'],
  ['UIVisualEffectView', 'iOS 8 blur'],
  ['UIBlurEffect', 'iOS 8 blur'],
  ['UIStackView', 'iOS 9 layout'],
  ['UISearchController', 'iOS 8 search'],
  ['UIPopoverPresentationController', 'iOS 8 presentation'],
  ['WKWebView', 'iOS 8 web view'],
  ['NSProgress', 'iOS 7 progress'],
  ['NSURLQueryItem', 'iOS 7 URL building'],
  ['NSURLComponents', 'iOS 7 URL building'],
  ['stringByAddingPercentEncodingWithAllowedCharacters:', 'iOS 7 percent encoding'],
  ['sizeWithAttributes:', 'iOS 7 text measuring'],
  ['boundingRectWithSize:options:attributes:context:', 'iOS 7 text measuring'],
  ['drawInRect:withAttributes:', 'iOS 7 text drawing'],
  ['textContainerInset', 'iOS 7 text view inset'],
  ['systemFontOfSize:weight:', 'iOS 8 fonts'],
  ['UIFontDescriptor', 'iOS 7 fonts'],
  ['UIButtonTypeSystem', 'iOS 7 buttons'],
  ['UIBarButtonItemStylePlain', 'iOS 8 bar button style'],
  ['UIGraphicsImageRenderer', 'iOS 10 drawing'],
  ['NSDiffableDataSource', 'iOS 13 tables'],
  ['UIContextualAction', 'iOS 11 swipe actions'],
  ['UIScene', 'iOS 13 lifecycle'],
  ['NSLayoutAnchor', 'iOS 9 layout'],
  ['UIViewPropertyAnimator', 'iOS 10 animation'],
  ['UIFeedbackGenerator', 'iOS 10 haptics'],
  ['UIApplicationOpenSettingsURLString', 'iOS 8 settings'],
  ['base64EncodedStringWithOptions:', 'iOS 7 base64'],
  ['initWithBase64EncodedString:options:', 'iOS 7 base64'],
  ['presentModalViewController:', 'deprecated modal API'],
];

test('no iOS 7+ API tokens in the target', () => {
  const hits = [];
  for (const name of sourceFiles) {
    const source = stripComments(read(name));
    for (const [needle, why] of BANNED) {
      if (source.indexOf(needle) !== -1) {
        hits.push(name + ': ' + needle + ' (' + why + ')');
      }
    }
  }
  eq(hits, [], 'banned APIs');
});

test('ARC: no manual retain/release/dealloc calls', () => {
  for (const name of objcFiles) {
    const source = stripComments(read(name));
    notOk(/\[\s*super\s+dealloc\s*\]/.test(source), name + ' super dealloc');
    notOk(/\[\s*(self|_[a-zA-Z]+)\s+release\s*\]/.test(source), name + ' release');
    notOk(/\[\s*(self|_[a-zA-Z]+)\s+autorelease\s*\]/.test(source), name + ' autorelease');
  }
});

test('rotation callbacks use the iOS 6 UIInterfaceOrientationMask signature', () => {
  for (const name of objcFiles) {
    const source = stripComments(read(name));
    notOk(/-\s*\(NSUInteger\)\s*supportedInterfaceOrientations/.test(source),
          name + ' uses NSUInteger');
  }
  includes(read('MTDiaryViewController.m'),
           '- (UIInterfaceOrientationMask)supportedInterfaceOrientations');
});

test('modal screens use the iOS 5+ presentation API', () => {
  const film = read('MTFilmViewController.m');
  const search = read('MTSearchViewController.m');
  includes(film, 'presentViewController:nav animated:YES completion:nil', 'film modal');
  includes(search, 'presentViewController:nav animated:YES completion:nil', 'search modal');
});

/* ------------------------------------------------------------------ */
/* Write path and privacy                                             */
/* ------------------------------------------------------------------ */

test('the phone never stores a password or session cookie', () => {
  for (const name of sourceFiles) {
    const source = stripComments(read(name)).toLowerCase();
    notOk(source.includes('password'), name + ' password');
    notOk(/setobject:[\s\S]{0,120}forkey:@".*(cookie|token|password)/.test(source),
          name + ' credential persistence');
  }
  includes(read('MTProfileViewController.m'), 'LB_SESSION_COOKIE', 'relay cookie note');
});

test('direct send is guarded and CSV export exists', () => {
  const log = read('MTLogViewController.m');
  includes(log, 'if (!self.draft.slug.length)', 'slug guard');
  includes(log, 'logDraft:', 'relay log call');
  notOk(log.includes('sharedDrafts'), 'stale sharedDrafts call');

  const profile = read('MTProfileViewController.m');
  includes(profile, 'LetterboxdURI,tmdbID,imdbID,Title,Year,Directors,Rating,Rating10,WatchedDate,Rewatch,Tags,Review',
           'Letterboxd CSV header');
  includes(profile, 'MFMailComposeViewController', 'email composer');
});

test('the log sheet has no reload path from a star tap', () => {
  const log = read('MTLogViewController.m');
  includes(log, 'cell.control.onChange', 'rating callback');
  includes(log, 'weakCell.caption.text = MTRatingCaption(rating);', 'caption updated in place');
  notOk(/onChange[\s\S]{0,220}reloadData/.test(log), 'star tap must not reload the table');
});

test('poster images go through the relay proxy when a path is present', () => {
  includes(read('MTDiaryViewController.m'), 'entry.poster.length ? entry.poster : entry.posterCdn', 'diary proxy');
  includes(read('MTFilmViewController.m'), 'self.film.poster.length ? self.film.poster : self.entry.poster', 'film proxy');
  includes(read('MTImageCache.m'), 'NSURLRequestReturnCacheDataElseLoad', 'image cache policy');
});

/* ------------------------------------------------------------------ */
/* Parsing and relay contract                                         */
/* ------------------------------------------------------------------ */

test('feed, film, search, connect, and log endpoints are wired', () => {
  const relay = read('MTRelay.m');
  for (const endpoint of ['/api/health', '/api/feed', '/api/film?slug=', '/api/search?q=', '/api/connect', '/api/log']) {
    includes(relay, endpoint, endpoint);
  }
});

test('rating is sent 0-5 from the phone and kept in stars by the relay', () => {
  const relay = read('MTRelay.m');
  includes(relay, 'body[@"rating"] = draft.rating;', 'rating field');
  const write = fs.readFileSync(path.join(ROOT, 'relay', 'lb.js'), 'utf8');
  includes(write, 'function normalizeRating', 'relay rating normalization');
  includes(write, 'entry.rating = rating', 'rating passed through in stars');
  notOk(write.includes('opts.rating) * 2'), 'relay must not convert back to 0-10');
});

/* ------------------------------------------------------------------ */
/* UI details already verified on the physical device                  */
/* ------------------------------------------------------------------ */

test('stars are green and clipped per star', () => {
  const stars = read('MTStarsView.m');
  includes(stars, 'MTStarPath(starRect)', 'per-star path');
  includes(stars, 'CGContextClipToRect', 'per-star clipping');
  includes(stars, 'starRect.size.width * fraction', 'fraction width');
  includes(read('MTAppearance.m'), '0.00 green:0.78 blue:0.33', 'green #00c853');
});

test('diary nav is the mark only, and the back item says Diary', () => {
  const diary = read('MTDiaryViewController.m');
  includes(diary, 'self.navigationItem.titleView = mark;', 'mark title');
  notOk(/self\.title\s*=\s*@"Diary"/.test(diary), 'no text title on diary');
  includes(diary, 'initWithTitle:@"Diary"', 'back item');
});

test('profile settings lead with the relay-owned session', () => {
  const profile = read('MTProfileViewController.m');
  notOk(/rightbarbuttonitem[\s\S]{0,100}@"connect/i.test(profile), 'no Connect nav button');
  includes(profile, 'Letterboxd session', 'session status row');
  includes(profile, 'Check session', 'recheck action');
  includes(profile, 'Refresh cookie', 'cookie help action');
  includes(profile, 'session:^(id json, NSError *error)', 'session endpoint is queried');
  notOk(profile.includes('Connect a profile'), 'handle is not presented as sign-in');
});

test('four tabs are built in the app delegate', () => {
  const app = read('MTAppDelegate.m');
  for (const screen of ['MTDiaryViewController', 'MTListsViewController', 'MTSearchViewController', 'MTProfileViewController']) {
    includes(app, screen, screen);
  }
  includes(app, 'tabs.viewControllers = @[diary, lists, search, profile];', 'four tabs');
});

const failures = report('objc-sanity');
process.exit(failures ? 1 : 0);
