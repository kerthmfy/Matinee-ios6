# Matinee: build, publish, tweak, and Cydia

This is the long-form companion to the README. It covers four things:

1. how the project was built and why it looks the way it does,
2. how to put it on GitHub,
3. how to install it on an iOS 6 device and package it for Cydia,
4. how the rating/log paths work, including the experimental write path.

Everything here assumes you own the device and the Letterboxd account. Nothing here bypasses a login, a paywall, or a rate limit.

---

## 1. How it was built

### 1.1 The constraint

The target is **iOS 6.1**, which means:

- Objective-C and UIKit, not Swift,
- `armv7`, 32-bit,
- ARC, but no modern Objective-C that needs a newer runtime than iOS 6,
- no storyboards, no Auto Layout,
- no `NSURLSession`, `UIAlertController`, `UIVisualEffectView`, `UIStackView`, or `sizeWithAttributes:`,
- `NSURLConnection`, `UIAlertView`, `UINavigationBar` background images,
- text measurement with `sizeWithFont:constrainedToSize:lineBreakMode:`.

The web mock exists because the iOS target cannot be run on a modern Mac. It is the visual and interaction reference: every screen, spacing decision, and state transition is testable in jsdom. The UIKit target mirrors that behavior.

### 1.2 The relay

`relay/server.js` is one Node process with no runtime dependencies. It does four jobs:

| Route | What it does |
| --- | --- |
| `GET /` and static paths | Serves the browser mock from `web/` |
| `GET /api/feed?user=handle` | Fetches and parses the public RSS feed; returns diary entries and lists |
| `GET /api/film?slug=...` | Fetches a film page, parses JSON-LD, runtime, cast, synopsis, CSRF, and `viewingableUid` |
| `GET /api/search?q=...` | TMDB search; returns `tmdb_key_missing` when unconfigured |
| `POST /api/connect` | Normalizes a handle/profile URL/RSS URL and checks the feed |
| `POST /api/log` | Experimental form post using `LB_SESSION_COOKIE` |
| `GET /img?u=...&w=...` | Allowlisted poster proxy with a byte cache |

Why a relay at all?

- The phone should not parse Letterboxd HTML. One parser, one place to fix when the markup moves.
- The phone should not hold a cookie or an API key.
- The image proxy is an SSRF boundary: only `https://a.ltrbxd.com` and `https://image.tmdb.org`, width clamped to 80–900.
- Feed and film responses are cached in memory and on disk, so a 50-row diary does not hammer the site.

`relay/lb.js` has the parsing and the write form. `relay/images.js` is a small FIFO byte cache (300 entries / 64 MB). `relay/fixtures/` contains captured pages so the tests do not need the live site.

### 1.3 The browser mock

`web/app.js` is a tiny state machine:

```
state = { tab, view, feed, film, sheet, alert, drafts, ... }
render() -> phone + iPad
```

Every interaction mutates state, then calls `render()`. The phone and iPad are two render targets of the same state, which is why a change on one is visible on the other.

The iOS 6 look is hand-built CSS:

- a 44px navigation bar with a top highlight, blue gradient, and 1px dark bottom edge,
- a 49px tab bar with a glass highlight and selected-tab gradient,
- grouped tables with inset cards and 1px separators,
- a status bar with time, 3G, and battery,
- the three-orb mark drawn with CSS gradients.

The log sheet is an overlay inside the phone frame, not a route. That made it possible to test the exact bug the user reported: it used to re-animate on every star tap. The fix is one class:

```js
class: 'sheet' + (s.animated ? '' : ' sheet-enter')
```

`animated` is set after the first mount. A star tap calls `paintLogStars()` and updates the caption; it never calls `render()`, so the sheet node, its scroll position, and its animation stay put.

### 1.4 The UIKit target

The app is split the same way as the mock:

| File | Role |
| --- | --- |
| `MTAppDelegate` | Window, four navigation controllers, tab bar |
| `MTDiaryViewController` | Feed table, refresh control, mark-only nav title |
| `MTFilmViewController` | Poster, metadata, average/user stars, synopsis, log button |
| `MTLogViewController` | Header, tappable stars, date picker, review, switches, Save/Send |
| `MTListsViewController` | Lists and list detail |
| `MTSearchViewController` | Search bar, TMDB results, log sheet |
| `MTProfileViewController` | Handle, drafts, CSV export, relay URL, status |
| `MTModels` | `MTEntry`, `MTFilm`, `MTDraft`, CSV row |
| `MTRelay` | The only network client; talks to the relay |
| `MTStore` | `NSUserDefaults`: relay base, handle, drafts |
| `MTImageCache` | Async poster loader + reuse-safe image view |
| `MTMarkView` | Core Graphics orbs |
| `MTStarsView` | Clipped green stars and the tappable rating control |
| `MTAppearance` | Colors, fonts, nav/tab gradients |

There are no storyboards and no nibs. `main.m` calls `UIApplicationMain`; the app delegate builds the tabs. The project file is hand-written OpenStep plist (`project.pbxproj`), which is why `plutil -lint` can validate it.

The log sheet is the most delicate screen. It uses a grouped table:

- section 0: poster + title,
- section 1: five stars and a caption,
- section 2: watched date, review, rewatch, like,
- section 3: Send to Letterboxd.

The star control is a custom `UIView`. It draws five paths, clips the fill to each star's width, and calls a block on tap. It never reloads the table, so the date picker and text view keep their state.

### 1.5 The tests

| Suite | What it proves |
| --- | --- |
| `test/relay-api.js` | Health, static mock, manifest/service worker/icons, feed/film fixtures, connect, missing-key search, no-session log, image allowlist, CORS, 404s, traversal attempts |
| `test/relay-search.js` | Configured search against a local HTTPS TMDB mock: query encoding, movie/TV mapping, poster proxying, empty query, upstream 500, malformed JSON |
| `test/relay-write.js` | Signed-in form post against a local HTTPS Letterboxd mock: cookie/CSRF/uid, field body, 200, 403, expired session, unreachable film, route wiring |
| `test/dom-smoke.js` | The mock renders, the logo-only nav has no text, stars are green and correctly filled, the log sheet does not re-animate, the Connect button is gone, CSV columns are right |
| `test/dom-flows.js` | Search → draft, lists/list detail, connect, phone/iPad back labels, and manifest/touch-icon links |
| `test/sw-cache.js` | Opaque cross-origin poster caching, cache hits, waitUntil, and pass-through for non-posters |
| `test/write-shape.js` | The form body has the right keys, the 0–10 rating conversion, date/tags/rewatch/liked shape, and the image allowlist |
| `test/objc-sanity.js` | Every source exists and is in the target, imports resolve, deployment target is 6.0, ARC is on, no iOS 7+ tokens, the four icons exist |
| `test/package.js` | Theos scaffold, plist/project settings, every icon size, screenshots, and local docs links |
| `test/relay-live.js` | Live RSS/JSON-LD parsing and 50/50 poster fetches |

The Objective-C suite is structural, not a compiler; the Theos package build is the compile check. The search and write suites use local self-signed HTTPS mocks via the test-only `MATINEE_TMDB_ORIGIN`, `MATINEE_LB_ORIGIN`, and `MATINEE_INSECURE_TLS` variables; they prove the request and mapping code, not that a real account accepts the post.

### 1.6 Decisions worth knowing

- **Diary nav is the mark only.** A text title next to the orbs made the bar feel like a template. The orbs are the brand.
- **The back control is shaped.** The old `‹ Diary` was a text glyph in a plain button. It is now an iOS 6 pointed cap with a 1px outline, gradient, and drop shadow. The nav title caps at 46% when a back button is present so the two cannot overlap.
- **No Connect button in Profile's nav.** The connect action lives in the Account section; a second button in the bar was redundant.
- **Stars clip per star.** The gap between stars is not part of any star's fill width. This is why a 4.5 rating fills four stars and half of the fifth, not four stars plus the gap.
- **The sheet animates once.** See above.
- **Poster placeholders are light.** `#e7e9ed` reads as paper. Dark gradient placeholders looked like missing content.
- **The icon is square.** iOS applies the mask. The source is `web/icon.svg`; the PNGs are generated at 57/72/114/144/180/192/512.

---

## 2. Publish on GitHub

### 2.1 Before the first commit

From the project root:

```bash
cd matinee
git status
```

You should not see `.env`, `node_modules`, `relay/.cache`, or a `.deb`. The `.gitignore` covers them. After `git add`, inspect exactly what is staged:

```bash
git add .
git grep --cached -n -i -E 'LB_SESSION_COOKIE=|TMDB_API_KEY=|letterboxd\.signed' || true
```

Comments and docs mention the variable names; that is fine. A value is not. Unstage anything that contains one with `git restore --staged PATH`.

### 2.2 First commit

```bash
git init -b main
git add .
git commit -m "Matinee: iOS 6 Letterboxd client, relay, and browser mock"
```

If your Git is older than 2.28, use `git init` then `git branch -M main`.

### 2.3 Create the remote

With GitHub CLI:

```bash
gh auth login
gh repo create matinee --public --source=. --remote=origin --push
```

Without `gh`, create an empty repository at <https://github.com/new> (no README, no license), then:

```bash
git remote add origin git@github.com:YOURNAME/matinee.git
git push -u origin main
```

HTTPS works too:

```bash
git remote add origin https://github.com/YOURNAME/matinee.git
git push -u origin main
```

### 2.4 Make the repo legible

- Replace `YOURNAME` in the clone command in `README.md`.
- Add a short description on GitHub: “An iOS 6 Letterboxd client: relay, browser mock, and UIKit app.”
- Add topics: `ios6`, `objective-c`, `letterboxd`, `uikit`, `nodejs`, `retro`.
- Keep the screenshots in `docs/screenshots/`; they are the fastest way for someone to understand the project.
- Tag a release once the target builds:

```bash
git tag -a v1.0.0 -m "Matinee 1.0.0"
git push origin v1.0.0
```

### 2.5 GitHub Pages

Pages is a good fit for a Cydia repo (section 5) and for a small project page. It is **not** a good fit for the mock as-is:

- the mock calls `/api/...` relative to its own origin,
- GitHub Pages cannot run the Node relay,
- so a Pages deploy would render the shell and then fail every feed request.

If you want a live demo, host the relay somewhere with HTTPS (Fly.io, Render, a VPS) and add a configurable base URL to `web/app.js`. Until then, the screenshots and a local `npm start` are honest.

For a project page:

1. Settings → Pages → Source: “Deploy from a branch”.
2. Branch `main`, folder `/docs`.
3. Add `docs/index.md` with a short project summary and links.

### 2.6 What not to publish

- `LB_SESSION_COOKIE` values,
- `TMDB_API_KEY` values,
- `.env`,
- captured HTML that contains a signed-in CSRF token or account data,
- `.ipa`/`.deb` artifacts in the source repo (use Releases or the Cydia repo instead).

The fixtures in `relay/fixtures/` are public pages; still, skim them before publishing.

---

## 3. Install on an iOS 6 device

There are three practical routes. Pick based on the hardware you have.

### 3.1 Route A: Xcode 4.6.3 (cleanest)

Xcode 4.6.3 is the last version with the iOS 6.1 SDK. It runs on OS X Mountain Lion (10.8). A VM is common because modern Macs cannot run it.

1. Open `Matinee/Matinee.xcodeproj`.
2. Select the **Matinee** target → Build Settings:
   - `IPHONEOS_DEPLOYMENT_TARGET = 6.0`
   - `ARCHS = armv7` (or leave the default for the 6.1 SDK)
   - `CLANG_ENABLE_OBJC_ARC = YES`
3. Signing: select your developer team, or build unsigned for a jailbroken device.
4. Connect the device, select it, Run.

If you build unsigned:

```bash
xcodebuild -project Matinee/Matinee.xcodeproj -target Matinee \
  -configuration Release -sdk iphoneos \
  SYMROOT="$PWD/build" \
  CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO
```

The app lands in `build/Release-iphoneos/Matinee.app`.

### 3.2 Route B: Xcode 5.1.1

Xcode 5.1.1 runs on Mavericks and includes the iOS 6.1 simulator. Its device SDK is iOS 7.1, but it can build a **6.0 deployment target** and `armv7`. This is enough for a jailbroken iOS 6 device; the app will use the iOS 7 SDK's headers, so keep the deployment target at 6.0 and avoid any API newer than 6.0. The source already does.

### 3.3 Route C: Theos (best for a `.deb`)

Theos can compile the app and package it for Cydia in one step. This tree defaults to the armv7 slice of the iOS 11.4 SDK with a 6.0 deployment target; the resulting binary declares `LC_VERSION_MIN_IPHONEOS 6.0`. If you have an extracted iOS 6.1 SDK, override `TARGET=iphone:clang:6.1:6.0`. See `packaging/theos/README.md` and section 5.

### 3.4 Install an unsigned app on a jailbroken device

On the device, make sure it can accept unsigned apps (AppSync Unified or equivalent). Then, from the Mac:

```bash
# Pseudo-sign so the kernel accepts the binary.
ldid -S build/Release-iphoneos/Matinee.app/Matinee

# Copy it into the applications directory.
scp -r build/Release-iphoneos/Matinee.app root@DEVICE_IP:/Applications/

# Fix ownership and permissions.
ssh root@DEVICE_IP 'chown -R mobile:mobile /Applications/Matinee.app && chmod 755 /Applications/Matinee.app/Matinee'

# Refresh SpringBoard.
ssh root@DEVICE_IP 'killall -9 SpringBoard'
```

Alternatively, zip it as an `.ipa` and use `ipainstaller` or a signing service. A `.deb` is cleaner because Cydia handles permissions and upgrades.

### 3.5 Point the app at the relay

The default in `MTStore.m` is `http://192.168.1.50:3000`, a placeholder. Either:

- change it before building, or
- launch the app → Profile → Change server → enter `http://YOUR_MAC_LAN_IP:3000`.

The phone and Mac must be on the same network. macOS may prompt for incoming connections; allow Node. Verify from the phone's Safari first:

```
http://YOUR_MAC_LAN_IP:3000/api/health
```

You should see `{"ok":true,...}`. If that fails, the app cannot work yet.

iOS 6 has no App Transport Security, so plain HTTP on the LAN is fine. Do not expose the relay to the public internet without TLS and authentication; it is a private helper, not a hardened public service.

---

## 4. App, tweak, or both?

### 4.1 Definitions

- **App package**: a normal `.app` installed to `/Applications`. It gets an icon, its own sandbox, and no injection. Matinee is this.
- **Tweak**: a `.dylib` loaded by MobileSubstrate/CydiaSubstrate into another process. It hooks classes at runtime. It needs a `Filter` (which apps) and usually `mobilesubstrate` in `Depends`.
- **Cydia repo**: an apt repository with a `Packages` index and a `Release` file. It can host apps, tweaks, themes, and tools.

If your goal is “Matinee has an icon on my iOS 6 home screen”, you want an **app package**. You do not need a tweak.

If your goal is “add a Matinee button inside the official Letterboxd app”, you want a **tweak**. That is a different project: you have to inspect the Letterboxd binary, find the class and method, and hook it. It is fragile, it violates the app's terms, and it may break on every update. The rest of this section shows the shape of such a tweak, not a working one.

### 4.2 Theos app scaffold

`packaging/theos/` contains:

```
packaging/theos/
├── Makefile
├── control
├── Matinee -> ../../Matinee/Matinee
└── README.md
```

Install Theos:

```bash
export THEOS=$HOME/theos
git clone --recursive https://github.com/theos/theos.git "$THEOS"
```

The scaffold defaults to `$THEOS/sdks/iPhoneOS11.4.sdk`, which still has an armv7 slice. If you have the iOS 6.1 SDK at `$THEOS/sdks/iPhoneOS6.1.sdk`, build with `TARGET=iphone:clang:6.1:6.0` instead. Then:

```bash
cd packaging/theos
make clean package FINALPACKAGE=1
```

The default build also passes `-Wno-error=deprecated-module-dot-map`, because the older SDK's module maps are a warning under current clang, not a code error.

The `.deb` appears in `packages/`. Install it on the device:

```bash
scp packages/com.matinee.app_1.0_iphoneos-arm.deb root@DEVICE_IP:/tmp/
ssh root@DEVICE_IP 'dpkg -i /tmp/com.matinee.app_1.0_iphoneos-arm.deb && killall -9 SpringBoard'
```

If the `Matinee` symlink was lost (for example, a zip download on Windows):

```bash
ln -s ../../Matinee/Matinee Matinee
```

### 4.3 A minimal tweak

This is the standard Theos tweak shape. The class and method names are placeholders; discover the real ones with `class-dump`/`cycript` on a decrypted copy of the app you own.

```
matinee-tweak/
├── Makefile
├── Tweak.xm
├── control
└── MatineeTweak.plist
```

`Makefile`:

```make
TARGET := iphone:clang:6.1:6.0
ARCHS := armv7

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = MatineeTweak
MatineeTweak_FILES = Tweak.xm
MatineeTweak_FRAMEWORKS = UIKit

include $(THEOS_MAKE_PATH)/tweak.mk
```

`Tweak.xm`:

```objc
%hook LBFilmViewController

- (void)viewDidLoad {
    %orig;
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    [button setTitle:@"Matinee" forState:UIControlStateNormal];
    [button addTarget:self action:@selector(matineeOpen) forControlEvents:UIControlEventTouchUpInside];
    // ...place it in the view hierarchy...
}

%end
```

`MatineeTweak.plist`:

```xml
{ Filter = { Bundles = ( "com.letterboxd.letterboxd" ); }; }
```

`control`:

```
Package: com.yourname.matineetweak
Name: Matinee Tweak
Version: 1.0
Architecture: iphoneos-arm
Description: Experimental hook for the Letterboxd app.
Maintainer: Your Name <you@example.com>
Author: Your Name <you@example.com>
Section: Tweaks
Depends: mobilesubstrate, firmware (>= 6.0)
```

Build:

```bash
make package FINALPACKAGE=1
```

Caveats:

- App Store binaries are encrypted; `class-dump` on the raw binary shows nothing useful until it is decrypted.
- Class names change between releases.
- The Letterboxd app may use a web view or a cross-platform framework, in which case UIKit hooks are the wrong layer.
- Hooking a third-party app can violate its terms and can get an account limited.
- A tweak has full access to the host app's memory. Treat that as a security boundary, not a toy.

The recommended path is the standalone app. It does not touch Letterboxd's binary, and the CSV export is officially supported.

---

## 5. Host your own Cydia repo

### 5.1 Build the `.deb`

With Theos:

```bash
cd packaging/theos
make clean package FINALPACKAGE=1
ls packages/
# com.matinee.app_1.0_iphoneos-arm.deb
```

Inspect it before publishing:

```bash
dpkg-deb -I packages/com.matinee.app_1.0_iphoneos-arm.deb
dpkg-deb -c packages/com.matinee.app_1.0_iphoneos-arm.deb | head -30
```

You want to see `./Applications/Matinee.app/Matinee` and the icons. If the binary is there but the app crashes on launch, check `ldid -S` and the deployment target.

### 5.2 Repo layout

```
cydia/
├── .nojekyll
├── debs/
│   └── com.matinee.app_1.0_iphoneos-arm.deb
├── Packages
├── Packages.gz
├── Release
└── index.html        (optional landing page)
```

### 5.3 The `Packages` index

From the repo root:

```bash
dpkg-scanpackages -m debs /dev/null > Packages
gzip -9c Packages > Packages.gz
```

`Packages` will contain a stanza like:

```
Package: com.matinee.app
Name: Matinee
Version: 1.0
Architecture: iphoneos-arm
Description: An iOS 6 Letterboxd client
Homepage: https://github.com/YOURNAME/matinee
Maintainer: Your Name <you@example.com>
Author: Your Name <you@example.com>
Section: Entertainment
Depends: firmware (>= 6.0)
Filename: debs/com.matinee.app_1.0_iphoneos-arm.deb
Size: 123456
MD5sum: ...
SHA1: ...
SHA256: ...
```

If `dpkg-scanpackages` is missing, install `dpkg` (Homebrew: `brew install dpkg`). On Debian/Ubuntu it is part of `dpkg-dev`.

### 5.4 The `Release` file

```
Origin: Matinee
Label: Matinee
Suite: stable
Version: 1.0
Codename: ios6
Architectures: iphoneos-arm
Components: main
Description: Matinee packages for iOS 6
```

`Architectures: iphoneos-arm` is the important line. Cydia will hide the repo from devices with a different architecture.

### 5.5 Publish with GitHub Pages

1. Create a public repo named `cydia` (or `repo`).
2. Put the files at the root of `main`.
3. Add an empty `.nojekyll` so Pages serves `Packages` untouched.
4. Settings → Pages → Source: “Deploy from a branch”, branch `main`, folder `/ (root)`.
5. Wait for the green Pages URL, then verify:

```bash
curl -I https://YOURNAME.github.io/cydia/Packages
curl -I https://YOURNAME.github.io/cydia/debs/com.matinee.app_1.0_iphoneos-arm.deb
```

`Packages` should be `200` and `Content-Type: application/octet-stream` or similar. If it is `404`, Pages is not deployed yet or the branch/folder is wrong.

### 5.6 Add the repo in Cydia

On the device:

1. Cydia → Sources → Edit → Add.
2. Enter `https://YOURNAME.github.io/cydia/` (include the trailing slash).
3. Refresh sources.
4. Search for **Matinee** and install.

If the package does not appear:

- check `Architecture: iphoneos-arm` in `Packages`,
- check `Depends: firmware (>= 6.0)` is satisfied,
- check the `Filename:` path is relative to the repo root and the `.deb` is actually there,
- clear Cydia's cache by removing and re-adding the source.

### 5.7 Optional: sign the repo

Cydia does not require a signature, but apt can verify one. Generate a GPG key, sign `Release`:

```bash
gpg --armor --detach-sign -o Release.gpg Release
gpg --clearsign -o InRelease Release
```

Put the public key on the device (Cydia → Sources → Edit → Add key) or in the repo as `key.gpg` with instructions. Skip this for a personal repo; do it if other people will install.

### 5.8 Updating

For every release:

1. bump `Version` in `control`,
2. rebuild the `.deb`,
3. replace the file in `debs/`,
4. regenerate `Packages` and `Packages.gz`,
5. update `Release` if the suite metadata changed,
6. commit and push,
7. refresh sources in Cydia.

Keep the old `.deb` files or clean them up deliberately; `dpkg-scanpackages` indexes everything in `debs/`, including old versions.

---

## 6. Rating and logging, in detail

### 6.1 What the app can do without a cookie

- Read the public diary and lists.
- Read film pages: title, year, runtime, average rating, cast, genres, synopsis.
- Rate a film locally and save a draft.
- Export the drafts as the official Letterboxd CSV.
- Import that CSV at <https://letterboxd.com/import>.

This is the supported path. It works with 2FA, it survives cookie expiry, and it does not put a credential on the phone.

### 6.2 The CSV shape

`MTDraft -csvRow` and `web/app.js` both produce:

```
LetterboxdURI,tmdbID,imdbID,Title,Year,Directors,Rating,Rating10,WatchedDate,Rewatch,Tags,Review
```

Notes:

- `Rating` is 0.5–5.0; `Rating10` is the same value × 2.
- `WatchedDate` is `yyyy-MM-dd`.
- `Rewatch` is `Yes` or empty.
- Fields with commas, quotes, CR, or LF are quoted and internal quotes doubled.
- A search result has a `tmdbID` but no slug, so its `LetterboxdURI` is empty; the importer can still match on `tmdbID`.

### 6.3 The experimental write path

`relay/lb.js` has `submitLog`:

1. If `LB_SESSION_COOKIE` is unset, return `no_session`.
2. Fetch the film page **with the cookie**.
3. Parse the JSON-LD and the log form: `csrf`, `viewingableUid`, `signedIn`.
4. If `signedIn` is false, return `session_not_valid` (Letterboxd rendered a placeholder token).
5. Build the same `application/x-www-form-urlencoded` body the site's own form posts:
   - `__csrf`
   - `viewingableUid`
   - `specifiedDate=true`
   - `viewingDateStr`
   - `rating` (0–10)
   - `rewatch`, `liked`
   - `review`, `tags`, `containsSpoilers`
6. POST to `https://letterboxd.com/s/save-diary-entry` with `Origin` and `Referer`.

The form shape is tested against a captured film page (`relay/fixtures/film-form-excerpt.html`). The full request path is tested against a local HTTPS mock with a signed-in CSRF token (`test/relay-write.js`), including the 200, 403, and expired-session cases. A real member cookie was not available, so real-account acceptance is still unverified. Treat a live `200` as “the site accepted the post”, then check the diary.

To enable it:

```bash
# Put the cookie in .env (gitignored).
umask 077
cat >> .env <<'EOF'
LB_SESSION_COOKIE='letterboxd.signed.in=<paste-the-value-here>'
EOF

npm start
```

`npm start` loads `.env` automatically. If you run `node relay/server.js` directly, source it first with `set -a; . ./.env; set +a`.

Get the cookie from your own browser's developer tools after signing in. It expires; when it does, the relay returns `session_not_valid`. Do not put it in the app, a screenshot, an issue, or a commit.

### 6.4 Why there is no “rate directly” button without a cookie

Letterboxd has no public write API for this. The site's own form is the only route, and it needs:

- a signed-in cookie,
- a CSRF token tied to that session,
- the film's `viewingableUid`.

There is no safe way to do that from the phone without storing the cookie on the phone. The relay keeps it server-side, which is why the app offers **Send to Letterboxd** only as an experimental row and defaults to drafts.

If you want a one-tap rating inside the official app, that is a tweak (section 4), not a Matinee feature. It is also the most fragile possible integration.

### 6.5 Search and TMDB

`/api/search` needs `TMDB_API_KEY`. The key stays on the relay. Without it, the app shows the explanatory note instead of an empty list. Search results are loggable as drafts because they carry a `tmdbID`; they cannot use the direct write path because they have no Letterboxd slug.

---

## 7. Troubleshooting

| Symptom | Check |
| --- | --- |
| Mock shows “relay unreachable” | `curl http://127.0.0.1:3000/api/health`; restart with `npm start` |
| Phone cannot reach the relay | Same Wi-Fi, Mac firewall, use the LAN IP not `localhost`; open `/api/health` in phone Safari |
| Search says “TMDB key missing” | Put `TMDB_API_KEY` in `.env` and restart; it is read at boot |
| Posters are gray boxes | `/img` returns 403 for a non-allowlisted host; check the console and `relay/lb.js` `imageUrl` |
| Log sheet shows a date in the wrong format | The mock uses a browser date input; the app uses `UIDatePicker` and stores ISO `yyyy-MM-dd` |
| `Send to Letterboxd` says `no_session` | `LB_SESSION_COOKIE` is unset; this is expected. Use CSV |
| `session_not_valid` | The cookie expired or is not signed in; refresh it from the browser |
| The back button and title collide | The nav title caps at 46% when `.has-back` is present; check that class is on the bar |
| Xcode says armv7 is unsupported | You are on a modern Xcode. Use 4.6.3/5.1.1 or Theos |
| Theos cannot find UIKit | The SDK is missing from `$THEOS/sdks`; the default is `iPhoneOS11.4.sdk` |
| Theos link error about `libobjc.A.tbd` or simulator | The 9.3 SDK's stub is mixed; use the 11.4 SDK or a device-only 6.1 SDK |
| Cydia does not see the package | Architecture, `Depends`, `Filename`, and Pages deployment; re-add the source |

### A final checklist

- [ ] `npm test` passes (and `npm test -- --live` when the network is friendly).
- [ ] No `.env`, cookie, key, `node_modules`, or cache in `git status`.
- [ ] README screenshots are current.
- [ ] The relay address is changed for the target network.
- [ ] The app builds against the iOS 6 SDK (or you have accepted the structural-only state).
- [ ] The `.deb` installs and launches on a real device before you publish the repo.
- [ ] The Cydia `Packages` index points at the `.deb` you actually uploaded.
- [ ] You have read Letterboxd's terms and are using your own account.

MIT licensed. Have fun, and keep the relay on your own network.
