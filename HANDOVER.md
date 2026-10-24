# Matinee iOS 6 — Handover

Session date: 2026-10-24. Target: jailbroken iOS 6, `armv7`, Theos + Xcode project,
**MRC** (no ARC), `-Werror` on. iPad support requested.

---

## 0. Where things actually stand

**This workspace contains no application source.** `/workspace/chats/67fb08d50268e7277f126f10`
has a git repo with zero tracked files at every commit. The user's project lives on
their own Mac and reaches the agent only by pasting code.

Two artifact sets were produced here and are the deliverables:

| Path | What |
|---|---|
| `tlsprobe/` | Working Mbed TLS 2.28.9 client + measured findings + CA anchor |
| `MatineeUI/` | Ten new iOS 6 / MRC source files: redesigned home screen + real RSS feed service |
| `SYNC-DESIGN.md` | Write-path blocker, relay API contract, offline outbox design |

**Nothing here has been compiled.** There is no iOS SDK, Theos or UIKit in this
environment. All verification was static (brace balance, banned-token grep,
selector declarations, and a Python port of the feed parser run over live RSS).
Never report these files as "builds" or "tested".

**The user compiles and installs themselves** on legacy devices and does not want
compilation caveats repeated. Do not pad replies with verification disclaimers;
say what is known and move on. A `make package install` failure report from the
user is the first real build signal we will get.

User-reported status at end of session (not independently verified here):
**the RSS feed loads in the app**, i.e. `MTSecureClient` can reach
`/<user>/rss/` and `MTFeedService` parses it.

---

## 1. User's project (from their file tree)

Root-level sources: `main.m`, `Matinee-Prefix.pch`, `MTAppDelegate`, `MTAppearance`,
`MTDebugViewController`, `MTDiaryViewController`, `MTDraft`, `MTEntry`,
`MTFilmViewController`, `MTImageCache`, `MTListsViewController`, `MTLogViewController`,
`MTMarkView`, `MTModels`, `MTProfileViewController`, `MTSearchViewController`,
`MTSecureClient`, `MTStarsView`, `MTStore` (all `.h`/`.m` pairs), plus `Makefile`,
`control`, `Info.plist`, `.env.example`.

Folders: `.theos`, `Matinee`, `Matinee.xcodeproj`, `mbedtls`, `packages`, `Resources`,
`packaging`, `relay`, `test`, `web`.

Existing UI: 4 tabs — **Most Recent / Bookmarks / Search / Contacts** — light cream
background, blue nav bar. On device it currently shows
*"Can't reach Letterboxd. Please check your connection or handle."*

Existing transport: `MTSecureClient` speaks TLS 1.2 to `letterboxd.com:443` over raw
sockets using Mbed TLS 2.28.9 (installed in `mbedtls/`). Bodies are split with
`strstr(raw, "\r\n\r\n")`. `MTDebugViewController` + `+[MTSecureClient lastDebugPayload]`
expose raw responses in-app.

---

## 2. What was measured about letterboxd.com (2026-10-24)

Reproduce with `tlsprobe/` (see §6). All figures below are observed, not inferred.

### 2.1 TLS succeeds with stock Mbed TLS 2.28.9

```
handshake: TLSv1.2 / TLS-ECDHE-ECDSA-WITH-CHACHA20-POLY1305-SHA256
verify flags=0x00000000 [ok]
```

- Server cert is **ECDSA**, `CN=letterboxd.com`, issuer `CN=WE1` (Google Trust Services)
- Chain: leaf → WE1 → **GTS Root R4** (cross-signed by GlobalSign Root CA)
- Cert validity **2026-09-16 .. 2026-12-15**
- P-256 (prime256v1) key exchange accepted; X25519 not needed
- Also accepted: `ECDHE-ECDSA-AES128/256-GCM`, `ECDHE-RSA-AES128-GCM`

All required `config.h` flags are already on in the 2.28.9 default config:
`MBEDTLS_SSL_PROTO_TLS1_2`, `ECDSA_C`, `ECDH_C`, `ECP_DP_SECP256R1`, `GCM_C`,
`CHACHAPOLY_C`, `AES_C`, `X509_CRT_PARSE_C`, `HAVE_TIME`.

**Conclusion: the library and server are compatible. TLS config is not the bug.**

### 2.2 SNI is mandatory — proven

Removing `mbedtls_ssl_set_hostname()` fails instantly:

```
HANDSHAKE FAILED -0x7780 SSL - A fatal alert message was received from our peer
```

Cloudflare kills the connection with no server name to route on.

### 2.3 Chunked transfer is real

`Connection: close` does **not** prevent it:

```
chunked=1  rawBody=81398  dechunked=81361   (matches curl exactly)
body starts: 16c5   <!DOCTYPE html> ...
```

The body begins with a hex length. Fixes, both verified:
- **Preferred:** send `HTTP/1.0` in the request line → server replies `HTTP/1.1 200`
  with `chunked=0`, correct 81361-byte body, no dechunking needed.
- Otherwise dechunk first (`MTDechunk` in `tlsprobe/FINDINGS.md` §6).

### 2.4 Single-read truncation

The search page is 81,361 bytes delivered in **48 TLS reads**. One
`mbedtls_ssl_read()` returns at most one record (~16 KB). A one-shot read yields ~20%
of the document, ending mid-tag.

### 2.5 Endpoint availability — the hard constraint

| Endpoint | Result | Usable by non-JS client |
|---|---|---|
| `/` (home) | **403** Cloudflare | No |
| `/search/<q>/` | 200 but JS shell (`#search-table-body` empty) | No |
| `/s/search/<q>/` | **403** "Just a moment…" | No |
| `/search/films/<q>/` | **403** | No |
| `/search/cast-crew/<q>/` | **403** | No |
| `/search/<q>/page/2/` | **403** | No |
| `/films/popular/` | 200 but JS shell (0 `<img>`, 0 film links) | No |
| `/film/<slug>/` | **200**, 205 KB, 74 `<img>`, 19 `/resized/` | **Yes** |
| **`/<username>/rss/`** | **200**, `application/rss+xml`, 100 items | **Yes — primary feed source** |
| `/crew/rss/` | 200, 100 editorial items (no film fields) | Partly |
| `/<username>/reviews/rss/` | **403** | No |
| `/<username>/films/rss/` | **403** | No |
| `a.ltrbxd.com/resized/...` | 200 `image/jpeg` | **Yes** |

The 403s are consistent for both an iOS 6 UA and a modern Chrome UA, with/without
`X-Requested-With`, `Referer`, cookie jar. `/search/<q>/` returns 200 intermittently
but is only a JS shell.

**`data-film-name`, `data-film-slug`, `data-film-release-year` now appear zero times
anywhere on the site.** The HTML parser in `MTSearchViewController.m` targets markup
that no longer exists — search cannot be fixed by improving the parser.

### 2.5b RSS is the working data source (verified)

`https://letterboxd.com/<username>/rss/` is **not** Cloudflare-challenged and returns
RSS 2.0 with 100 items. Verified working for `dave`, `matthew`, `jack`.

Per item:

```xml
<letterboxd:filmTitle>Wildwood</letterboxd:filmTitle>
<letterboxd:filmYear>2026</letterboxd:filmYear>
<letterboxd:memberRating>4.5</letterboxd:memberRating>
<dc:creator>Dave Vis</dc:creator>
<description><![CDATA[
  <p><img src="https://a.ltrbxd.com/resized/film-poster/...-0-600-0-900-crop.jpg?v=e0b4be5769"/></p>
  <p>review text, when the member wrote one</p>
]]></description>
```

Notes:
- `dc:creator` is the **display name**, not the username. No avatar in the feed.
- Poster URLs carry a `?v=<hash>` cache-buster — keep the whole URL.
- Review-less watches contain only `Watched on <date>.`; `MTFeedPlainText` strips
  those lines so the Reviews tab doesn't fill with boilerplate.
- `crew` has an RSS feed but no `letterboxd:film*` fields (editorial stories), so it
  is not usable as a poster rail.

### 2.5c The write path is closed (measured)

Reading works; **writing does not**, and this is an architectural constraint, not a
bug to fix. Every page involved in signing in or posting returns the Cloudflare JS
challenge:

| Request | Result |
|---|---|
| `GET /signin/` (iOS 6 UA) | **403** "Just a moment…" |
| `GET /signin/` (Chrome 126 UA + full `Sec-Fetch-*` headers) | **403** |
| `GET /welcome/`, `/about/` | **403** |
| `GET /film/<slug>/rate/` | **403** |
| `GET /film/<slug>/diary/` | **403** |

The app therefore cannot obtain a CSRF token, cannot post credentials, and cannot
post a rating. The official Letterboxd API does not help: it is **read-only** (no
log/rate endpoints). Their API docs pages also 403 us, so that status is prior
knowledge, not a fresh check.

### 2.5d BUT the official API has a write route (tested 2026-10-24)

`api.letterboxd.com` is a **separate host and is NOT Cloudflare-challenged**. It
answers JSON, not challenge pages:

| Request | Result | Meaning |
|---|---|---|
| `GET /api/v0/me` | 401 | route exists, needs auth |
| `GET /api/v0/films` | 401 | route exists |
| `GET /api/v0/log-entries` | 401 | **log-entry read route exists** |
| `POST /api/v0/log-entries` (form body) | 415 | route exists, wants JSON |
| `POST /api/v0/log-entries` (JSON, no CSRF) | 403 `Invalid CSRF token` | CSRF gate |
| `POST /api/v0/log-entries` (JSON + `X-CSRF-Token` echoing `com.xk72.webparts.csrf`) | **401** | **CSRF gate passed, auth is all that's left** |
| `POST /api/v0/lists` (same dance) | 401 | lists write route exists |
| `POST /api/v0/watchlist`, `/films/<id>/like`, `/reviews`, `/comments` | 404 | those routes do **not** exist |

CSRF mechanics, verified:

1. `GET` anything on the API host → sets cookie `com.xk72.webparts.csrf=<value>`
   (`Path=/; HttpOnly; Secure; SameSite=Lax`).
2. Echo that exact value back in an `X-CSRF-Token:` request header → the 403 becomes 401.

Auth: `POST /api/v0/auth/token` accepts `grant_type=password` syntactically, but a
missing/bogus client returns `{"error":"invalid_client"}`. So it needs an **approved
API client (client_id + client_secret)**. TLS: **1.2 only** — TLS 1.0 is rejected with
alert 70, so iOS 6 `NSURLConnection` cannot reach it; it must go through Mbed TLS.

**Consequence:** a relay is *not* the only option. Two architectures:

- **A — official API (preferred if credentials can be obtained).** Apply for API
  access, password-grant to a token, then `POST /api/v0/log-entries` with the CSRF
  cookie + header. No relay, no scraping, no ToS risk. Gated on approval.
- **B — personal relay** holding a browser session. Works without approval, but is
  fragile and ToS-grey. Full design and contract: **`SYNC-DESIGN.md`**.

The log-entry JSON schema is unknown without credentials — the docs pages 403 us.
Do not guess it; capture a real request from a browser session or the official app,
or read it once API access is granted.

### 2.6 Poster URL form changed

Current 2:3 poster crop that works:

```
https://a.ltrbxd.com/resized/film-poster/2/6/8/2/2682-primer-0-600-0-900-crop.jpg
```

`-0-600-0-900-crop.jpg` is the poster ratio. The older `-0-1000-0-1500-crop.jpg`
now returns **403**. Backdrops use `-1200-1200-675-675-crop-000000.jpg` (200).
Avatars use `-0-80-0-80-crop.jpg` / `-0-144-0-144-crop.jpg`.

### 2.7 mbedtls error map (log `-ret` as hex)

| Code | Meaning | Likely cause here |
|---|---|---|
| `-0x0044` | NET_CONNECT_FAILED | DNS/socket |
| `-0x004C` | NET_RECV_FAILED | closed early; often missing SNI |
| `-0x6900` | SSL_WANT_READ | **not an error** — retry loop |
| `-0x2700` | X509_CERT_VERIFY_FAILED | no/stale CA, or **wrong device clock** |
| `-0x7780` | FATAL_ALERT_MESSAGE | **missing SNI** (verified) |
| `-0x7380` | NO_CIPHER_CHOSEN | custom config without ECDSA/GCM/CHACHA |
| `-0x7A00` | BAD_HS_CERTIFICATE | header/lib version mismatch |
| `-0x7880` | PEER_CLOSE_NOTIFY | normal end of a close response |

Prime suspect on device for "can't reach": `-0x2700` from a missing/stale CA bundle or
a wrong clock on the jailbroken device. Print `mbedtls_ssl_get_verify_result()` even
under `VERIFY_NONE` — it separates `EXPIRED` / `NOT_YET_VALID` from `NOT_TRUSTED`.

Verified minimal anchor: `tlsprobe/certs/letterboxd-anchor.pem` (765 bytes, GTS Root R4).

---

## 3. UI work delivered (`MatineeUI/`)

Ten files. The view layer is deliberately self-contained (no dependency on `MTEntry`
or `MTAppearance`); `MTFeedService` intentionally reuses `MTSecureClient`, because
that is the only path that speaks TLS 1.2 to letterboxd.com from iOS 6:

| File | Role |
|---|---|
| `MTHomeTheme.h/.m` | Palette `#14181C` bg, `#00E054` green, `#99AABB` text; iPhone/iPad metrics |
| `MTFeedModels.h/.m` | `MTFeedItem`, `MTFeedSection`, `MTStarsString`, `MTPosterURLString`, `MTLoadImage` (NSCache + async fetch) |
| `MTPosterStripView.h/.m` | Horizontal poster rail, optional friend byline (avatar + name + stars) |
| `MTFeedService.h/.m` | Fetches `/<user>/rss/` for each friend via `MTSecureClient`, strips headers/dechunks, parses RSS with `NSXMLParser`, builds the three rails |
| `MTHomeViewController.h/.m` | Segmented Films/Reviews/Lists/Journal, three rails, friend-review list, pull-to-refresh, error+retry |

Design: dark Letterboxd look, 4-tab header with green underline, chevron section
headers, 100×150 posters (140×210 on iPad), rails bleed off-screen so the next poster
peeks. Reviews tab lists friend reviews (poster thumb, name · film (year), green stars,
2-line snippet). iPad: 760 pt centered column, all orientations; phone portrait-only.

The screen loads **real data** on appearance: no demo fixtures. Rails are
"New from friends", "Popular with friends" (films watched by several friends) and
"Highest rated by friends", all derived from the RSS feeds of
`MTFeedService.friendUsernames` (defaults `dave`, `matthew`, `jack` — replace with
real friends). Reviews tab lists items that actually carry review text.

### Integration

- Copy the ten files next to `MTSearchViewController.m` (repo root).
- `Makefile`: `$(wildcard *.m)` picks them up; otherwise add the five `.m` files.
- Link `QuartzCore` (poster corner rounding): `Matinee_FRAMEWORKS = UIKit Foundation QuartzCore`.
- Create `MTHomeViewController` and set it as the first tab's root (usually wrapped in
  a `UINavigationController`) in `MTAppDelegate.m`.
- Real data needs no wiring: the controller calls `MTFeedService` on appearance.
  Set `[MTFeedService sharedService].friendUsernames` to the user's actual friends
  (defaults `dave`, `matthew`, `jack`).
- `MTFeedService` depends on one transport method:
  `[MTSecureClient sendRequestToHost:path:completion:]` — copied from the call already
  present in `MTSearchViewController.m`. If the real header differs, it is one line in
  `-fetchPath:completion:`.
- Manual rows are still possible: `home.sections = @[...]` of `MTFeedSection`, then
  `[home reload]`.

Full integration text: `MatineeUI/README.md`.

### Honest status

Not compiled here (the user builds). Checked statically:

- brace/paren/bracket balance on all four pairs
- zero ARC keywords (`strong`, `weak`, `__weak`, `__strong`)
- zero iOS 7+ APIs (`tintColor`, `NSLayoutConstraint`, `UICollectionView`,
  `stringByAddingPercentEncoding…`, `NSURLSession`, `UIAlertController`)
- every `dealloc` ends with `[super dealloc];`
- every cross-class selector declared in an interface/extension
- `sendSynchronousRequest:` wrapped in a scoped `-Wdeprecated-declarations` pragma

---

## 4. Outstanding work, priority order

### P0 — build is broken before any of this runs
1. **`MTSearchViewController.m` has a spliced `dealloc` inside `MTSearchBodyOnly`.**
   A pasted draft ended the function and injected:

   ```objc
   - (void)dealloc { [_tableView release]; [super dealloc]; }
   ```

   mid-function, leaving unbalanced braces. Delete that orphan block; the real
   `dealloc` exists further down. Also `MTSearchBodyOnly` lacks a `return data;` on
   the no-CRLFCRLF path (`-Wreturn-type` + `-Werror`).

2. **`MTProfileViewController.m:46`** — original `-Wobjc-missing-super-calls` error.
   `dealloc` starts line 43, must end with `[super dealloc];`, or be deleted if empty.

### P1 — transport (this is why the device says "Can't reach Letterboxd")
3. In `MTSecureClient`, in this order:
   - `mbedtls_ssl_set_hostname()` — mandatory (else `-0x7780`)
   - load a CA bundle containing **GTS Root R4** (or `tlsprobe/certs/letterboxd-anchor.pem`)
   - loop all reads until close/EOF; never parse one read
   - treat `-0x6900` / `-0x6880` as retry, not failure
   - send `HTTP/1.0` in the request line (avoids chunking), or dechunk
   - headers: iOS 6 UA, `Accept: text/html,application/xhtml+xml`,
     `Accept-Language`, `Accept-Encoding: identity`, `Connection: close`
   - expose `+lastDebugHeaders` so `MTDebugViewController` shows status + `Content-Type`
4. Log `-ret` hex at every mbedtls call; map with §2.7.

### P1.5 — logging & rating needs a relay (blocked by design, not code)

4a. Scraping/writing against the HTML site is impossible: `/signin/`, `/rate/`,
    `/diary/` are Cloudflare 403 for every client tested (§2.5c). Do not try to code
    around that.
4a-bis. The **JSON API is a different host and is open** (§2.5d): the only missing
    piece is an approved client_id/secret. If the user can obtain API access, prefer
    that over a relay — it is cleaner and does not risk the account.
4b. Fallback direction: a personal relay (the repo already has a `relay/` folder) that
    holds a browser session and exposes `GET /v1/health`, `POST /v1/rate`,
    `POST /v1/diary` — full contract in `SYNC-DESIGN.md`.
4c. Device-side work that is safe to build now and does not need the relay to exist:
    a persistent outbox (`pending → sending → sent`, `failed` surfaced), exponential
    retry surviving relaunch, `clientId` idempotency, and a log/rate composer sheet.
    An offline queue is essential — silently losing a diary entry is the worst
    possible outcome on a flaky legacy device.

### P2 — search needs a redesign, not a parser fix
5. All HTML search routes are challenged or JS shells (§2.5). Options: a JSON movie
   API (free key, `parseJSONResults:` already exists as the fallback path), the
   official Letterboxd API (needs approval), or drop search from the app.
   **Decision belongs to the user — do not silently pick one.**

### P3 — memory hygiene
6. `MTProfileViewController.m` leaks (wrap in `autorelease`): line 29 `UITableView`
   (double retain via property setter), 100/113/125/155/164 `UITableViewCell`,
   202/230/244/282 `UIAlertView`, 272 `MFMailComposeViewController`,
   298/300 `MTDebugViewController` + nav controller.
7. Sweep every VC: `grep -n 'dealloc\|release\|retain\|alloc\]' <file>.m`.

---

## 5. Traps — do not repeat these

- **No ARC keywords.** `strong` on a property is tolerated by clang under MRC (it just
  means `retain`) but contradicts project style — use `retain`. `weak`/`__weak`/
  `__strong` do not exist here. `__block` is fine (unsafe-unretained semantics).
- **`stringByAddingPercentEncodingWithAllowedCharacters:` is iOS 7+.** Use
  `stringByPercentEscapesUsingEncoding:`.
- **`[super dealloc]` goes last**, always.
- **`dequeueReusableCellWithIdentifier:` returns not-owned** — autorelease every
  `alloc/init` cell.
- **`UIAlertView show` does not retain on iOS 6** — autorelease it.
- **Do not target `data-film-*` selectors** — removed from the site.
- **Do not use `/s/search/`** — Cloudflare 403 for every UA.
- **Do not try to sign in from the device.** `/signin/` is 403 for every UA tested;
  it needs JavaScript. Writes go through a relay (`SYNC-DESIGN.md`).
- **Do not hardcode Letterboxd form field or CSRF parameter names.** They rotate;
  the relay must read them from the live form on each write.
- **Do not assume `cf_clearance` is portable.** It is bound to IP + user agent and
  expires within hours, so importing a desktop browser session into the app is not a
  dependable design.
- **Do not use `-0-1000-0-1500-crop.jpg`** — 403; use `-0-600-0-900-crop.jpg`.
- **Do not claim visual verification.** No simulator, no device, no screenshots here.

---

## 6. Reproducing the TLS measurements

```bash
cd tlsprobe
curl -sSL -o mbedtls.tar.gz \
  https://github.com/Mbed-TLS/mbedtls/archive/refs/tags/v2.28.9.tar.gz
tar xzf mbedtls.tar.gz && (cd mbedtls-2.28.9 && make -j4 lib)

gcc -O1 -I mbedtls-2.28.9/include -o probe probe.c \
    mbedtls-2.28.9/library/libmbedtls.a \
    mbedtls-2.28.9/library/libmbedx509.a \
    mbedtls-2.28.9/library/libmbedcrypto.a

./probe required /film/primer/ sni http10
MT_CA=certs/letterboxd-anchor.pem ./probe required /film/primer/ sni http10
./probe none /search/primer/ nosni        # demonstrates the SNI failure
```

`probe.c` prints handshake version/cipher, verify flags, header dump, chunked vs
dechunked sizes, and marker counts (`data-film-name`, `<img`, `href="/film/`,
`/resized/`) in the body — reuse it whenever the parser or transport is in doubt.

---

## 7. Open questions for the user

1. Does the project build at all right now (after the `MTSearchViewController.m` splice)?
2. Which search backend do they want (HTTP JSON API / official API / drop search)?
3. Do they have any authenticated Letterboxd session, or is the client anonymous?
4. Does `MTEntry` really expose `title` / `yearText` / `poster` as assumed?
5. Is `Makefile` using `$(wildcard *.m)` or an explicit file list?
6. Tab bar: keep the current four tabs and swap "Most Recent" for the new home screen,
   or move to Letterboxd's five-tab layout?
7. What is already in the `relay/` folder — existing server to extend, or empty
   scaffolding?
8. Where will the relay run? Playwright/Puppeteer need a real runtime, which rules
   out Cloudflare Workers.
9. For logging v1: is rating enough, or must reviews/tags ship in the first version?
10. Are there build errors from the user's first `make` of the new home screen?

---

## 8. Files in this workspace

```
tlsprobe/
  FINDINGS.md                  measured TLS + endpoint report (source of §2)
  probe.c                      Mbed TLS 2.28.9 reference client
  certs/letterboxd-anchor.pem  765-byte GTS Root R4 anchor (verified)
  certs/gts-r4-only.pem        same file, older name
  certs/ca-letterboxd.pem      4-anchor variant (also verified)

MatineeUI/
  MTHomeTheme.h/.m             palette + iPhone/iPad metrics
  MTFeedModels.h/.m            MTFeedItem / MTFeedSection / stars / cached image loader
  MTFeedService.h/.m           RSS fetch via MTSecureClient + NSXMLParser + rail building
  MTPosterStripView.h/.m       horizontal poster rail with friend byline
  MTHomeViewController.h/.m    segmented tabs, rails, review list, refresh, error+retry
  README.md                    integration + data-mapping notes

SYNC-DESIGN.md                 write-path blocker + relay API contract + outbox design
HANDOVER.md                    this file
```
