#!/bin/sh
# Matinee iOS 6 — installer
# Writes the home-screen sources, measurement tooling and docs into
# the current directory. Run it inside your project root:
#
#   sh install-matinee-ui.sh
#
# Re-running overwrites the files it creates. No network access or build is performed.
set -e

mkdir -p MatineeUI tlsprobe/certs

echo "  writing README-BUNDLE.md"
cat > 'README-BUNDLE.md' <<'MT_FILE_EOF_1'
# Matinee iOS 6 — deliverables bundle

Everything produced in this session: the redesigned home screen source, the
measurement tooling, and the handover documents.

## Start here

1. **`HANDOVER.md`** — project state, measured facts about letterboxd.com, what's
   built, what's blocked, exact next actions. Read this first.
2. **`SYNC-DESIGN.md`** — how to log/rate films: the HTML write path is closed by
   Cloudflare, the JSON API has an open log-entry route gated on API credentials,
   and the relay is the documented fallback.
3. **`MatineeUI/README.md`** — how to drop the new screen into the project.

## MatineeUI — add these to the app

Ten files, iOS 6 / MRC, `-Werror`-conscious, no ARC keywords.

```
MTHomeTheme.h/.m          palette (#14181C, #00E054, #99AABB) + iPhone/iPad metrics
MTFeedModels.h/.m         MTFeedItem / MTFeedSection / stars / cached image loader
MTFeedService.h/.m        real RSS feed loading via MTSecureClient + NSXMLParser
MTPosterStripView.h/.m    horizontal poster rail with friend byline
MTHomeViewController.h/.m segmented Films/Reviews/Lists/Journal, rails, reviews, refresh
```

Install:

- copy all ten files next to `MTSearchViewController.m` (repo root)
- `Makefile`: `$(wildcard *.m)` picks them up; otherwise add the five `.m` files
- ensure `QuartzCore` is linked: `Matinee_FRAMEWORKS = UIKit Foundation QuartzCore`
- set the home screen as a tab root in `MTAppDelegate.m`
- set real friends: `[MTFeedService sharedService].friendUsernames = @[@"you", @"friend1"];`

The screen loads live data — no demo fixtures. If the transport isn't healthy it shows
the error with "Tap to retry" rather than inventing content.

## tlsprobe — measurement tooling

```
FINDINGS.md                  measured TLS + endpoint report
probe.c                      Mbed TLS 2.28.9 reference client
certs/letterboxd-anchor.pem  765-byte GTS Root R4 anchor (verified to validate the chain)
certs/gts-r4-only.pem        same file, older name
certs/ca-letterboxd.pem      4-anchor variant (also verified)
```

Rebuild and re-run (see FINDINGS.md §7):

```bash
curl -sSL -o mbedtls.tar.gz https://github.com/Mbed-TLS/mbedtls/archive/refs/tags/v2.28.9.tar.gz
tar xzf mbedtls.tar.gz && (cd mbedtls-2.28.9 && make -j4 lib)
gcc -O1 -I mbedtls-2.28.9/include -o probe probe.c \
    mbedtls-2.28.9/library/libmbedtls.a \
    mbedtls-2.28.9/library/libmbedx509.a \
    mbedtls-2.28.9/library/libmbedcrypto.a
MT_CA=certs/letterboxd-anchor.pem ./probe required /film/primer/ sni http10
```

## Quick facts worth knowing before touching anything

- TLS works with stock Mbed TLS 2.28.9 — TLS 1.2, `ECDHE-ECDSA-CHACHA20-POLY1305`.
  The server cert is **ECDSA** (Google Trust Services `WE1`).
- **SNI is mandatory** — without `mbedtls_ssl_set_hostname()` you get `-0x7780`.
- Responses are **chunked**; sending `HTTP/1.0` avoids it entirely.
- A 81 KB page arrives in ~48 TLS reads — loop the reads, never parse one.
- `/<username>/rss/` is the only rich data source that isn't challenged.
- `data-film-*` attributes are gone from the site; the old search parser cannot work.
- `api.letterboxd.com` is a separate host, not challenged, TLS 1.2 only, and has a
  `POST /api/v0/log-entries` route (415 on form body, 401 once CSRF is satisfied).

## Not included

The app's own sources (`MTAppDelegate`, `MTSecureClient`, `MTEntry`, etc.) — they live
on the user's machine and were never uploaded here. Wiring instructions assume the
class names from the project tree in `HANDOVER.md` §1.
MT_FILE_EOF_1

echo "  writing HANDOVER.md"
cat > 'HANDOVER.md' <<'MT_FILE_EOF_2'
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
MT_FILE_EOF_2

echo "  writing SYNC-DESIGN.md"
cat > 'SYNC-DESIGN.md' <<'MT_FILE_EOF_3'
# Logging & rating from Matinee — architecture

Question: how does the app rate a film / add a diary entry without CSV export?

**Updated 2026-10-24.** The *HTML* write path is closed to non-browser clients
(Cloudflare JS challenge). But the **JSON API host is open and has a log-entry write
route** — see Option A. A relay is the fallback, not the only answer.

---

## 1. Measured blocker (2026-10-24)

Every page involved in signing in or writing is behind Cloudflare's JS challenge:

| Request | Result |
|---|---|
| `GET /signin/` (iOS 6 UA) | **403** "Just a moment…" |
| `GET /signin/` (Chrome 126 UA + full Sec-Fetch headers) | **403** |
| `GET /welcome/`, `/about/` | **403** |
| `GET /film/primer/diary/` | **403** |
| `GET /film/primer/rate/` | **403** |
| `GET /film/primer/` | 200 (works) |
| `GET /<user>/rss/` | 200 (works) |

So the app cannot fetch a CSRF token, cannot POST credentials, and cannot POST a
rating. This is not a parser or TLS problem — the response is a challenge page
requiring JavaScript execution, and no amount of Mbed TLS work changes that.

The official Letterboxd API does not solve it either: it is **read-only** (no
log/rate endpoints). Their API docs pages themselves return 403 to us, so that
status is from prior knowledge rather than a fresh check.

---

## 2. Options

### Option A — official JSON API (preferred, gated on credentials)

`api.letterboxd.com` is a separate host, **not** Cloudflare-challenged, TLS 1.2 only
(so it must go through Mbed TLS, not `NSURLConnection`). Measured:

| Request | Result |
|---|---|
| `GET /api/v0/log-entries` | 401 (route exists) |
| `POST /api/v0/log-entries` (form body) | 415 (wants JSON) |
| `POST /api/v0/log-entries` (JSON, no CSRF) | 403 `Invalid CSRF token` |
| `POST /api/v0/log-entries` (JSON + `X-CSRF-Token` echoing the cookie) | **401** — CSRF passed |
| `POST /api/v0/lists` (same dance) | 401 (exists) |
| `POST /api/v0/watchlist`, `/films/<id>/like`, `/reviews` | 404 (do not exist) |

Flow the app would implement:

1. `GET /api/v0/films` on the API host → capture `com.xk72.webparts.csrf` cookie.
2. `POST /api/v0/auth/token` with `grant_type=password` + client_id/secret → bearer token.
3. `POST /api/v0/log-entries` (JSON) with `Authorization: Bearer …` **and**
   `X-CSRF-Token: <cookie value>`.

The only blocker: `/auth/token` returns `{"error":"invalid_client"}` without an
**approved API client**. That is an application/approval process, not a technical gap.
The JSON schema for a log entry is unknown until we have credentials — capture a real
request rather than guessing.

Advantages: no server to run, no session to keep alive, no ToS-grey scraping, and the
account is far less likely to be rate-limited or flagged.

### Option B — personal relay (fallback, works without approval)

A small server you control that holds the browser session and performs the writes.
The device never sees credentials and never has to beat Cloudflare.

```
[Matinee on iOS 6]  --HTTPS/JSON-->  [your relay]  --browser session-->  letterboxd.com
```

- The relay logs in once with a real browser engine (Puppeteer/Playwright) or a
  stored, refreshed session, keeps cookies + CSRF token, and reuses them.
- The app gets a tiny, stable JSON API and an offline queue.
- Works with the existing `relay/` folder in the project.

Cost: you must run a server. Benefit: it actually works and stays working.

### Option C — imported browser session

User signs in in Safari, exports `letterboxd.user.CURRENT` and `cf_clearance`,
pastes them into the app. The app then POSTs directly with those cookies.

- `cf_clearance` is bound to **IP + user agent** and expires in roughly 30 min–24 h.
  The app's UA is not the browser's, and on cellular the IP differs → likely rejected.
- Session dies silently and the app looks broken.

Treat as an experiment, not the plan.

### Option D — CSV / manual import
Explicitly what the user wants to avoid. Not considered.

---

## 3. Relay API contract

Keep it dumb and versioned. All requests `Content-Type: application/json`,
`Authorization: Bearer <device-token>`.

### `GET /v1/health`
```json
{ "ok": true, "signedIn": true, "member": "dave" }
```
The app pings this to decide whether to flush the queue.

### `POST /v1/rate`
```json
{ "slug": "primer", "rating": 4.5 }
```
`rating` is 0.5–5.0 in half steps, or `null` to clear.

### `POST /v1/diary`
```json
{
  "slug": "primer",
  "viewingDate": "2026-10-23",
  "rating": 4.5,
  "review": "Still the best thing Carruth has done.",
  "rewatch": false,
  "liked": true,
  "tags": ["sci-fi", "low-budget"],
  "containsSpoilers": false
}
```

### Responses
```json
{ "ok": true, "id": "abc123" }
{ "ok": false, "error": "csrf_expired", "retry": true }
```
`retry: true` means the app should keep the item queued; `false` means drop it and
surface the error (e.g. unknown slug, invalid rating).

### Idempotency
The app sends `"clientId": "<uuid>"` on every write. The relay stores the last N
ids so a retried request cannot double-post a diary entry. **Important**: duplicates
are the main failure mode of an offline queue.

### Relay internals (not the app's concern)
1. `GET /signin/` in the browser context → CSRF token from the form.
2. `POST /signin/` with credentials → session cookies.
3. For a rate: `GET /film/<slug>/` → confirm CSRF + film id; `POST /film/<slug>/rate/`.
4. For a diary entry: `GET /film/<slug>/diary/`, read the form's hidden fields,
   `POST` them back with the values above.
5. Re-login when the session 302s to `/signin/`, surfacing `csrf_expired`.

Field names must be read from the live form, not hard-coded — Letterboxd changes them.
That is exactly why the browser context matters.

---

## 4. App-side design (buildable today, no relay needed)

The device side is useful before the relay exists: it queues and retries.

```
MTLogEntry        slug, rating, date, review, rewatch, liked, tags, clientId, state
MTLogQueue        persistent outbox
  states:          pending -> sending -> sent
                   pending -> failed (permanent, surfaced in UI)
  storage:         NSKeyedArchiver to Documents/MTLogQueue.plist
  retry:           exponential 30s, 2m, 10m, 1h; capped; survives relaunch
MTLogClient       POSTs JSON, one item at a time, via MTSecureClient
MTLogComposerViewController
                  stars (reuse MTStarsView), date picker, rewatch/like switches,
                  review text view, tags field, "Save" -> enqueue
```

UI touchpoints:
- Film/entry screens get a **Log / Rate** button.
- Pending count badge (e.g. on the Films tab) so writes are never invisible.
- A queue list screen: each item shows pending/failed and allows retry or delete.

Why an outbox rather than fire-and-forget: a jailbroken iPhone on iOS 6 will lose
network mid-write, and the relay may be unreachable for hours. Silent loss of a
diary entry is the worst possible outcome.

---

## 5. Risks

- **Terms of service.** Automating writes against Letterboxd is not a supported use
  of their site; they can change markup, add stricter bot rules, or rate-limit the
  account. The relay reduces risk but does not remove it.
- **Session fragility.** Any logout/password change invalidates the relay session.
- **CSRF rotation.** Tokens are per-session and change; the relay must re-read them.
- **Duplicates.** Mitigate with `clientId` idempotency on the relay.
- **No offline login.** The app authenticates to *your relay*, not to Letterboxd.

---

## 6. Open questions

1. What is already in the `relay/` folder — is there an existing server to extend?
2. Where will the relay run (VPS, home box, Cloudflare Worker)? Playwright needs a
   real runtime, which rules out Workers.
3. Does the user want reviews in the app, or is rating enough for v1?
4. Should failures retry forever or surface after N attempts?
MT_FILE_EOF_3

echo "  writing MatineeUI/MTFeedModels.h"
cat > 'MatineeUI/MTFeedModels.h' <<'MT_FILE_EOF_4'
//
//  MTFeedModels.h
//  Matinee
//
//  Lightweight feed model for the Letterboxd-style home screen.
//  Deliberately independent of MTEntry so this screen can be dropped in and
//  populated from any source (existing parser, JSON API, local cache).
//

#import <UIKit/UIKit.h>

@interface MTFeedItem : NSObject
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *yearText;
@property (nonatomic, copy) NSString *slug;
// Either a full https URL or the fragment after "/resized/"
// (e.g. "film-poster/2/6/8/2/2682-primer-0-600-0-900-crop.jpg").
@property (nonatomic, copy) NSString *posterPath;
@property (nonatomic, copy) NSString *reviewerName;
@property (nonatomic, copy) NSString *avatarPath;   // same fragment rules
@property (nonatomic, assign) CGFloat rating;       // 0 = unrated, up to 5.0
@property (nonatomic, copy) NSString *reviewSnippet;
@property (nonatomic, assign) NSTimeInterval timestamp; // feed order; 0 if unknown
+ (id)itemWithTitle:(NSString *)title
               year:(NSString *)year
             poster:(NSString *)poster;
@end

@interface MTFeedSection : NSObject
@property (nonatomic, copy) NSString *title;
@property (nonatomic, retain) NSArray *items;
@property (nonatomic, assign) BOOL showsByline;
+ (id)sectionWithTitle:(NSString *)title
                 items:(NSArray *)items
            showsByline:(BOOL)showsByline;
@end

// "★★★★☆" for 4.0, rounded to the nearest whole star.
NSString *MTStarsString(CGFloat rating);

// Prefixes a /resized/ fragment; passes full URLs through untouched.
NSString *MTPosterURLString(NSString *path);

// Async image fetch with an NSCache. Safe to call repeatedly during reuse.
// Returns immediately; the view's image is set on the main queue.
void MTLoadImage(NSString *URLString, UIImageView *imageView);
MT_FILE_EOF_4

echo "  writing MatineeUI/MTFeedModels.m"
cat > 'MatineeUI/MTFeedModels.m' <<'MT_FILE_EOF_5'
//
//  MTFeedModels.m
//  Matinee
//

#import "MTFeedModels.h"
#import <math.h>

@implementation MTFeedItem

+ (id)itemWithTitle:(NSString *)title year:(NSString *)year poster:(NSString *)poster
{
    MTFeedItem *item = [[[MTFeedItem alloc] init] autorelease];
    item.title = title;
    item.yearText = year;
    item.posterPath = poster;
    return item;
}

- (void)dealloc
{
    [_title release];
    [_yearText release];
    [_slug release];
    [_posterPath release];
    [_reviewerName release];
    [_avatarPath release];
    [_reviewSnippet release];
    [super dealloc];
}

@end

@implementation MTFeedSection

+ (id)sectionWithTitle:(NSString *)title items:(NSArray *)items showsByline:(BOOL)showsByline
{
    MTFeedSection *section = [[[MTFeedSection alloc] init] autorelease];
    section.title = title;
    section.items = items;
    section.showsByline = showsByline;
    return section;
}

- (void)dealloc
{
    [_title release];
    [_items release];
    [super dealloc];
}

@end

NSString *MTStarsString(CGFloat rating)
{
    NSInteger full = (NSInteger)floor((double)rating + 0.5);
    if (full < 0) full = 0;
    if (full > 5) full = 5;

    NSMutableString *stars = [NSMutableString stringWithCapacity:5];
    NSInteger i = 0;
    for (i = 0; i < 5; i++) {
        [stars appendString:(i < full) ? @"\u2605" : @"\u2606"];
    }
    return stars;
}

NSString *MTPosterURLString(NSString *path)
{
    if (!path.length) return nil;
    if ([path hasPrefix:@"http://"] || [path hasPrefix:@"https://"]) return path;
    return [@"https://a.ltrbxd.com/resized/" stringByAppendingString:path];
}

static NSCache *MTFeedImageCache(void)
{
    static NSCache *cache = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        cache = [[NSCache alloc] init];
        [cache setCountLimit:120];
    });
    return cache;
}

void MTLoadImage(NSString *URLString, UIImageView *imageView)
{
    if (!imageView) return;

    imageView.image = nil;
    if (!URLString.length) return;

    NSString *key = [[URLString copy] autorelease];
    UIImage *cached = [MTFeedImageCache() objectForKey:key];
    if (cached) {
        imageView.image = cached;
        return;
    }

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        @autoreleasepool {
            NSURL *url = [NSURL URLWithString:key];
            if (!url) return;

            NSMutableURLRequest *request =
                [NSMutableURLRequest requestWithURL:url
                                        cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                                    timeoutInterval:20.0];
            [request setValue:@"Mozilla/5.0 (iPhone; CPU iPhone OS 6_1 like Mac OS X) "
                              @"AppleWebKit/536.26 (KHTML, like Gecko) Version/6.0 "
                              @"Mobile/10B329 Safari/8536.25"
           forHTTPHeaderField:@"User-Agent"];

            // +sendSynchronousRequest: is the right call for this deployment target
            // (iOS 5/6) but is marked deprecated in newer SDKs; keep the warning
            // scoped to this line instead of disabling it project-wide.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
            NSData *data = [NSURLConnection sendSynchronousRequest:request
                                                 returningResponse:NULL
                                                             error:NULL];
#pragma clang diagnostic pop
            UIImage *image = data ? [UIImage imageWithData:data] : nil;
            if (!image) return;

            [MTFeedImageCache() setObject:image forKey:key];

            dispatch_async(dispatch_get_main_queue(), ^{
                imageView.image = image;
            });
        }
    });
}
MT_FILE_EOF_5

echo "  writing MatineeUI/MTFeedService.h"
cat > 'MatineeUI/MTFeedService.h' <<'MT_FILE_EOF_6'
//
//  MTFeedService.h
//  Matinee
//
//  Loads the home feed from Letterboxd's public RSS endpoints.
//
//  Why RSS: as of 2026-10, every HTML route on letterboxd.com is either a
//  Cloudflare JS challenge (403) or a JavaScript shell with an empty results
//  container. The per-user RSS feeds are NOT challenged and return real data:
//
//      https://letterboxd.com/<username>/rss/   -> 100 items, RSS 2.0
//
//  Each item carries letterboxd:filmTitle, letterboxd:filmYear,
//  letterboxd:memberRating, dc:creator and a description containing the
//  poster <img src="https://a.ltrbxd.com/resized/...-0-600-0-900-crop.jpg">.
//

#import <UIKit/UIKit.h>

typedef void (^MTFeedCompletionBlock)(NSArray *sections, NSError *error);

@interface MTFeedService : NSObject

// Letterboxd usernames whose /rss/ feed is merged into the home screen.
// Defaults to a few real public accounts so the screen works out of the box;
// replace with the signed-in user's actual friends.
@property (nonatomic, retain) NSArray *friendUsernames;

+ (MTFeedService *)sharedService;

// Fetches every friend feed, parses, merges, and returns NSArray of
// MTFeedSection on the main queue. On total failure, sections is nil and
// error describes the first failure.
- (void)loadFeedWithCompletion:(MTFeedCompletionBlock)completion;

@end
MT_FILE_EOF_6

echo "  writing MatineeUI/MTFeedService.m"
cat > 'MatineeUI/MTFeedService.m' <<'MT_FILE_EOF_7'
//
//  MTFeedService.m
//  Matinee
//

#import "MTFeedService.h"
#import "MTFeedModels.h"
#import "MTSecureClient.h"

#define MT_FEED_RAIL_LIMIT 12

static NSString *const MTFeedErrorDomain = @"MTFeedErrorDomain";

#pragma mark - response decoding

// Pulls the body out of a raw HTTP response and undoes chunked framing.
// Safe if MTSecureClient already handed us a clean body.
static NSData *MTFeedBodyFromResponse(NSData *response)
{
    if (!response.length) return nil;

    const unsigned char *bytes = (const unsigned char *)response.bytes;
    NSUInteger length = response.length;
    NSUInteger bodyStart = 0;
    BOOL split = NO;
    NSUInteger i = 0;

    for (i = 0; i + 3 < length; i++) {
        if (bytes[i] == '\r' && bytes[i + 1] == '\n' &&
            bytes[i + 2] == '\r' && bytes[i + 3] == '\n') {
            bodyStart = i + 4;
            split = YES;
            break;
        }
    }
    if (!split) {
        // Already body-only.
        return response;
    }

    NSData *headerData = [response subdataWithRange:NSMakeRange(0, bodyStart)];
    NSString *headers = [[[NSString alloc] initWithData:headerData
                                               encoding:NSISOLatin1StringEncoding] autorelease];
    NSData *body = [response subdataWithRange:NSMakeRange(bodyStart, length - bodyStart)];

    if ([headers rangeOfString:@"chunked" options:NSCaseInsensitiveSearch].location == NSNotFound) {
        return body;
    }

    // Dechunk: hex length line + CRLF framing.
    NSMutableData *out = [NSMutableData dataWithCapacity:body.length];
    const unsigned char *in = (const unsigned char *)body.bytes;
    NSUInteger inLength = body.length;
    NSUInteger offset = 0;

    while (offset < inLength) {
        while (offset < inLength && (in[offset] == '\r' || in[offset] == '\n')) offset++;
        if (offset >= inLength) break;

        long size = 0;
        int digits = 0;
        while (offset < inLength) {
            int c = in[offset];
            int value = -1;
            if (c >= '0' && c <= '9') value = c - '0';
            else if (c >= 'a' && c <= 'f') value = c - 'a' + 10;
            else if (c >= 'A' && c <= 'F') value = c - 'A' + 10;
            if (value < 0) break;
            size = size * 16 + value;
            digits++;
            offset++;
        }
        if (!digits) break;

        while (offset < inLength && in[offset] != '\n') offset++;
        offset++;

        if (size <= 0) break;
        if (offset + (NSUInteger)size > inLength) break;

        [out appendBytes:(in + offset) length:(NSUInteger)size];
        offset += (NSUInteger)size;
    }

    if (!out.length) return body;
    return out;
}

#pragma mark - HTML helpers

static NSString *MTFeedDecodeEntities(NSString *text)
{
    if (!text.length) return @"";

    NSMutableString *s = [[text mutableCopy] autorelease];
    [s replaceOccurrencesOfString:@"&lt;" withString:@"<"
                          options:0 range:NSMakeRange(0, s.length)];
    [s replaceOccurrencesOfString:@"&gt;" withString:@">"
                          options:0 range:NSMakeRange(0, s.length)];
    [s replaceOccurrencesOfString:@"&quot;" withString:@"\""
                          options:0 range:NSMakeRange(0, s.length)];
    [s replaceOccurrencesOfString:@"&#39;" withString:@"'"
                          options:0 range:NSMakeRange(0, s.length)];
    [s replaceOccurrencesOfString:@"&apos;" withString:@"'"
                          options:0 range:NSMakeRange(0, s.length)];
    [s replaceOccurrencesOfString:@"&nbsp;" withString:@" "
                          options:0 range:NSMakeRange(0, s.length)];
    [s replaceOccurrencesOfString:@"&amp;" withString:@"&"
                          options:0 range:NSMakeRange(0, s.length)];
    return s;
}

// First <img src="..."> in the description; letterboxd puts the poster there.
static NSString *MTFeedFirstImageURL(NSString *html)
{
    NSRange img = [html rangeOfString:@"<img"];
    if (img.location == NSNotFound) return nil;

    NSRange src = [html rangeOfString:@"src=\""
                              options:0
                                range:NSMakeRange(img.location, html.length - img.location)];
    if (src.location == NSNotFound) return nil;

    NSUInteger start = NSMaxRange(src);
    NSRange close = [html rangeOfString:@"\""
                                options:0
                                  range:NSMakeRange(start, html.length - start)];
    if (close.location == NSNotFound) return nil;

    return [html substringWithRange:NSMakeRange(start, close.location - start)];
}

// Flattens the description HTML into readable text, dropping the
// "Watched on ..." boilerplate lines Letterboxd appends.
static NSString *MTFeedPlainText(NSString *html)
{
    if (!html.length) return @"";

    NSMutableString *stripped = [NSMutableString stringWithCapacity:html.length];
    NSUInteger i = 0;
    NSUInteger n = html.length;
    BOOL inTag = NO;

    for (i = 0; i < n; i++) {
        unichar c = [html characterAtIndex:i];
        if (c == '<') {
            inTag = YES;
            // Block-level boundaries become newlines so words don't run together.
            if (i + 2 < n && [html characterAtIndex:i + 1] == 'b' &&
                [html characterAtIndex:i + 2] == 'r') {
                [stripped appendString:@"\n"];
            } else if (i + 2 < n && [html characterAtIndex:i + 1] == '/' &&
                       ([html characterAtIndex:i + 2] == 'p' ||
                        [html characterAtIndex:i + 2] == 'h')) {
                [stripped appendString:@"\n"];
            }
            continue;
        }
        if (c == '>') { inTag = NO; continue; }
        if (!inTag) [stripped appendFormat:@"%C", c];
    }

    NSString *decoded = MTFeedDecodeEntities(stripped);

    NSMutableArray *kept = [NSMutableArray array];
    for (NSString *line in [decoded componentsSeparatedByString:@"\n"]) {
        NSString *trimmed = [line stringByTrimmingCharactersInSet:
                             [NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (!trimmed.length) continue;
        if ([trimmed hasPrefix:@"Watched on"] || [trimmed hasPrefix:@"Rewatched"]) continue;
        [kept addObject:trimmed];
    }

    return [kept componentsJoinedByString:@" "];
}

#pragma mark - RSS parser

@interface MTFeedRSSParser : NSObject <NSXMLParserDelegate> {
    NSMutableArray *_items;
    NSMutableDictionary *_current;
    NSMutableString *_buffer;
    NSString *_element;
    NSDateFormatter *_dateFormatter;
}
- (NSArray *)parseData:(NSData *)data;
@end

@implementation MTFeedRSSParser

- (id)init
{
    self = [super init];
    if (self) {
        _items = [[NSMutableArray alloc] init];
        _buffer = [[NSMutableString alloc] init];
        _dateFormatter = [[NSDateFormatter alloc] init];
        [_dateFormatter setLocale:[[[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"] autorelease]];
        [_dateFormatter setDateFormat:@"EEE, dd MMM yyyy HH:mm:ss Z"];
    }
    return self;
}

- (void)dealloc
{
    [_items release];
    [_current release];
    [_buffer release];
    [_element release];
    [_dateFormatter release];
    [super dealloc];
}

- (NSArray *)parseData:(NSData *)data
{
    if (!data.length) return nil;

    NSXMLParser *parser = [[NSXMLParser alloc] initWithData:data];
    [parser setDelegate:self];
    [parser setShouldProcessNamespaces:NO];
    [parser setShouldReportNamespacePrefixes:NO];
    [parser parse];
    [parser release];

    return _items;
}

- (void)parser:(NSXMLParser *)parser
didStartElement:(NSString *)elementName
  namespaceURI:(NSString *)namespaceURI
 qualifiedName:(NSString *)qName
    attributes:(NSDictionary *)attributeDict
{
    (void)parser; (void)namespaceURI; (void)qName; (void)attributeDict;

    if ([elementName isEqualToString:@"item"]) {
        [_current release];
        _current = [[NSMutableDictionary alloc] init];
    }

    [_element release];
    _element = [elementName copy];
    [_buffer setString:@""];
}

- (void)parser:(NSXMLParser *)parser foundCharacters:(NSString *)string
{
    (void)parser;
    if (_element && string) [_buffer appendString:string];
}

- (void)parser:(NSXMLParser *)parser foundCDATA:(NSData *)CDATABlock
{
    (void)parser;
    if (!_element || !CDATABlock) return;
    NSString *text = [[NSString alloc] initWithData:CDATABlock encoding:NSUTF8StringEncoding];
    if (text) {
        [_buffer appendString:text];
        [text release];
    }
}

- (void)parser:(NSXMLParser *)parser
 didEndElement:(NSString *)elementName
  namespaceURI:(NSString *)namespaceURI
 qualifiedName:(NSString *)qName
{
    (void)parser; (void)namespaceURI; (void)qName;

    if (_current && _element) {
        [_current setObject:[[_buffer copy] autorelease] forKey:_element];
    }

    if ([elementName isEqualToString:@"item"]) {
        [self finishItem];
        [_current release];
        _current = nil;
    }

    [_element release];
    _element = nil;
    [_buffer setString:@""];
}

- (void)finishItem
{
    if (!_current) return;

    NSString *title = [_current objectForKey:@"letterboxd:filmTitle"];
    if (!title.length) title = [_current objectForKey:@"title"];
    if (!title.length) return;

    NSString *year = [_current objectForKey:@"letterboxd:filmYear"];
    NSString *description = [_current objectForKey:@"description"];
    NSString *poster = MTFeedFirstImageURL(description);
    NSString *creator = [_current objectForKey:@"dc:creator"];
    NSString *ratingText = [_current objectForKey:@"letterboxd:memberRating"];

    MTFeedItem *item = [MTFeedItem itemWithTitle:title year:year poster:poster];
    item.slug = [_current objectForKey:@"link"];
    item.reviewerName = creator;
    item.reviewSnippet = MTFeedPlainText(description);
    if (ratingText.length) item.rating = (CGFloat)[ratingText doubleValue];

    NSString *dateText = [_current objectForKey:@"pubDate"];
    if (dateText.length) {
        NSDate *date = [_dateFormatter dateFromString:dateText];
        if (date) item.timestamp = [date timeIntervalSince1970];
    }

    [_items addObject:item];
}

@end

#pragma mark - service

@interface MTFeedService ()
- (void)fetchPath:(NSString *)path completion:(void (^)(NSData *data, NSError *error))completion;
- (NSArray *)parseFeedData:(NSData *)data;
- (void)fetchUsers:(NSArray *)users
             index:(NSUInteger)index
              into:(NSMutableArray *)items
        completion:(MTFeedCompletionBlock)completion;
- (NSArray *)sectionsFromItems:(NSArray *)items;
@end

@implementation MTFeedService

@synthesize friendUsernames = _friendUsernames;

+ (MTFeedService *)sharedService
{
    static MTFeedService *service = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        service = [[MTFeedService alloc] init];
    });
    return service;
}

- (id)init
{
    self = [super init];
    if (self) {
        _friendUsernames = [[NSArray alloc] initWithObjects:@"dave", @"matthew", @"jack", nil];
    }
    return self;
}

- (void)dealloc
{
    [_friendUsernames release];
    [super dealloc];
}

#pragma mark transport

- (void)fetchPath:(NSString *)path completion:(void (^)(NSData *data, NSError *error))completion
{
    // Single place that touches the transport. MTSecureClient is the only path
    // that speaks TLS 1.2 to letterboxd.com from iOS 6.
    [MTSecureClient sendRequestToHost:@"letterboxd.com"
                                 path:path
                           completion:^(NSData *data, NSError *connectionError) {
        if (!completion) return;

        if (connectionError || !data.length) {
            completion(nil, connectionError);
            return;
        }

        NSData *body = MTFeedBodyFromResponse(data);
        if (body.length >= 2) {
            const unsigned char *b = (const unsigned char *)body.bytes;
            if (b[0] == 0x1f && b[1] == 0x8b) {
                NSError *gzipError = [NSError errorWithDomain:MTFeedErrorDomain
                                                         code:-2
                                                     userInfo:[NSDictionary dictionaryWithObject:
                                                               @"Feed came back gzip-compressed; send Accept-Encoding: identity."
                                                                                          forKey:NSLocalizedDescriptionKey]];
                completion(nil, gzipError);
                return;
            }
        }

        completion(body, nil);
    }];
}

- (NSArray *)parseFeedData:(NSData *)data
{
    if (!data.length) return nil;
    MTFeedRSSParser *parser = [[MTFeedRSSParser alloc] init];
    NSArray *items = [parser parseData:data];
    [items retain];
    [parser release];
    return [items autorelease];
}

#pragma mark loading

- (void)loadFeedWithCompletion:(MTFeedCompletionBlock)completion
{
    if (!completion) return;

    NSArray *users = self.friendUsernames;
    if (!users.count) {
        users = [NSArray arrayWithObjects:@"dave", nil];
    }

    MTFeedCompletionBlock copied = [[completion copy] autorelease];
    NSMutableArray *items = [NSMutableArray array];

    [self fetchUsers:users index:0 into:items completion:copied];
}

- (void)fetchUsers:(NSArray *)users
             index:(NSUInteger)index
              into:(NSMutableArray *)items
        completion:(MTFeedCompletionBlock)completion
{
    if (index >= users.count) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!items.count) {
                NSError *error = [NSError errorWithDomain:MTFeedErrorDomain
                                                     code:-1
                                                 userInfo:[NSDictionary dictionaryWithObject:
                                                           @"Could not load any friend feed."
                                                                                      forKey:NSLocalizedDescriptionKey]];
                completion(nil, error);
                return;
            }
            completion([self sectionsFromItems:items], nil);
        });
        return;
    }

    NSString *username = [users objectAtIndex:index];
    NSString *path = [NSString stringWithFormat:@"/%@/rss/", username];

    [self fetchPath:path completion:^(NSData *data, NSError *error) {
        (void)error;
        NSArray *parsed = [self parseFeedData:data];
        if (parsed.count) [items addObjectsFromArray:parsed];

        [self fetchUsers:users index:(index + 1) into:items completion:completion];
    }];
}

#pragma mark section building

static NSInteger MTFeedCompareNewest(id a, id b, void *context)
{
    (void)context;
    MTFeedItem *left = (MTFeedItem *)a;
    MTFeedItem *right = (MTFeedItem *)b;
    if (left.timestamp > right.timestamp) return NSOrderedAscending;
    if (left.timestamp < right.timestamp) return NSOrderedDescending;
    return NSOrderedSame;
}

static NSInteger MTFeedCompareRating(id a, id b, void *context)
{
    (void)context;
    MTFeedItem *left = (MTFeedItem *)a;
    MTFeedItem *right = (MTFeedItem *)b;
    if (left.rating > right.rating) return NSOrderedAscending;
    if (left.rating < right.rating) return NSOrderedDescending;
    return NSOrderedSame;
}

- (NSArray *)sectionsFromItems:(NSArray *)items
{
    if (!items.count) return nil;

    // Newest first, one entry per film.
    NSArray *sortedNewest = [items sortedArrayUsingFunction:MTFeedCompareNewest context:NULL];
    NSMutableArray *recent = [NSMutableArray array];
    NSMutableSet *seenTitles = [NSMutableSet set];
    for (MTFeedItem *item in sortedNewest) {
        if (!item.title.length) continue;
        if ([seenTitles containsObject:item.title]) continue;
        [seenTitles addObject:item.title];
        [recent addObject:item];
        if (recent.count >= MT_FEED_RAIL_LIMIT) break;
    }

    // Films several friends watched, most-watched first.
    NSMutableDictionary *counts = [NSMutableDictionary dictionary];
    NSMutableDictionary *representative = [NSMutableDictionary dictionary];
    for (MTFeedItem *item in items) {
        if (!item.title.length) continue;
        NSNumber *count = [counts objectForKey:item.title];
        [counts setObject:[NSNumber numberWithInteger:([count integerValue] + 1)]
                   forKey:item.title];
        if (![representative objectForKey:item.title]) {
            [representative setObject:item forKey:item.title];
        }
    }
    NSArray *titlesByCount = [[counts allKeys] sortedArrayUsingComparator:
        ^NSComparisonResult(id a, id b) {
            NSInteger left = [[counts objectForKey:a] integerValue];
            NSInteger right = [[counts objectForKey:b] integerValue];
            if (left > right) return NSOrderedAscending;
            if (left < right) return NSOrderedDescending;
            return NSOrderedSame;
        }];
    NSMutableArray *popular = [NSMutableArray array];
    for (NSString *title in titlesByCount) {
        [popular addObject:[representative objectForKey:title]];
        if (popular.count >= MT_FEED_RAIL_LIMIT) break;
    }

    // Highest rated by friends.
    NSArray *sortedRating = [items sortedArrayUsingFunction:MTFeedCompareRating context:NULL];
    NSMutableArray *topRated = [NSMutableArray array];
    NSMutableSet *seenRated = [NSMutableSet set];
    for (MTFeedItem *item in sortedRating) {
        if (!item.title.length || item.rating <= 0.0f) continue;
        if ([seenRated containsObject:item.title]) continue;
        [seenRated addObject:item.title];
        [topRated addObject:item];
        if (topRated.count >= MT_FEED_RAIL_LIMIT) break;
    }

    NSMutableArray *sections = [NSMutableArray array];

    if (recent.count) {
        [sections addObject:[MTFeedSection sectionWithTitle:@"New from friends"
                                                      items:recent
                                                 showsByline:YES]];
    }
    if (popular.count) {
        [sections addObject:[MTFeedSection sectionWithTitle:@"Popular with friends"
                                                      items:popular
                                                 showsByline:YES]];
    }
    if (topRated.count) {
        [sections addObject:[MTFeedSection sectionWithTitle:@"Highest rated by friends"
                                                      items:topRated
                                                 showsByline:YES]];
    }

    return sections;
}

@end
MT_FILE_EOF_7

echo "  writing MatineeUI/MTHomeTheme.h"
cat > 'MatineeUI/MTHomeTheme.h' <<'MT_FILE_EOF_8'
//
//  MTHomeTheme.h
//  Matinee
//
//  Letterboxd-style dark palette + metrics for the redrawn home screen.
//  MRC-safe: every function returns a retained-forever cached singleton.
//

#import <UIKit/UIKit.h>

UIColor *MTHomeBackgroundColor(void);   // #14181C
UIColor *MTHomeSurfaceColor(void);      // #1B2228 (poster placeholders)
UIColor *MTHomeSeparatorColor(void);    // #2C3440
UIColor *MTHomeTextColor(void);         // #FFFFFF
UIColor *MTHomeSecondaryTextColor(void); // #99AABB
UIColor *MTHomeGreenColor(void);        // #00E054
UIColor *MTHomeOrangeColor(void);       // #FF8000
UIColor *MTHomeBlueColor(void);         // #40BCF4

BOOL    MTHomeIsPad(void);
CGFloat MTHomePosterWidth(void);        // 100 phone / 140 pad
CGFloat MTHomePosterHeight(void);       // 3:2 poster ratio
CGFloat MTHomeGutter(void);             // gap between posters
CGFloat MTHomeScreenInset(void);        // leading/trailing inset
CGFloat MTHomeContentMaxWidth(void);    // 0 on phone, 760 on pad
CGFloat MTHomeBarHeight(void);          // segmented header height
MT_FILE_EOF_8

echo "  writing MatineeUI/MTHomeTheme.m"
cat > 'MatineeUI/MTHomeTheme.m' <<'MT_FILE_EOF_9'
//
//  MTHomeTheme.m
//  Matinee
//

#import "MTHomeTheme.h"

static UIColor *MTHomeCachedColor(CGFloat r, CGFloat g, CGFloat b, UIColor **slot, dispatch_once_t *once)
{
    dispatch_once(once, ^{
        *slot = [[UIColor alloc] initWithRed:(r / 255.0f)
                                       green:(g / 255.0f)
                                        blue:(b / 255.0f)
                                       alpha:1.0f];
    });
    return *slot;
}

UIColor *MTHomeBackgroundColor(void)
{
    static UIColor *color = nil;
    static dispatch_once_t once;
    return MTHomeCachedColor(20.0f, 24.0f, 28.0f, &color, &once);
}

UIColor *MTHomeSurfaceColor(void)
{
    static UIColor *color = nil;
    static dispatch_once_t once;
    return MTHomeCachedColor(27.0f, 34.0f, 40.0f, &color, &once);
}

UIColor *MTHomeSeparatorColor(void)
{
    static UIColor *color = nil;
    static dispatch_once_t once;
    return MTHomeCachedColor(44.0f, 52.0f, 64.0f, &color, &once);
}

UIColor *MTHomeTextColor(void)
{
    static UIColor *color = nil;
    static dispatch_once_t once;
    return MTHomeCachedColor(255.0f, 255.0f, 255.0f, &color, &once);
}

UIColor *MTHomeSecondaryTextColor(void)
{
    static UIColor *color = nil;
    static dispatch_once_t once;
    return MTHomeCachedColor(153.0f, 170.0f, 187.0f, &color, &once);
}

UIColor *MTHomeGreenColor(void)
{
    static UIColor *color = nil;
    static dispatch_once_t once;
    return MTHomeCachedColor(0.0f, 224.0f, 84.0f, &color, &once);
}

UIColor *MTHomeOrangeColor(void)
{
    static UIColor *color = nil;
    static dispatch_once_t once;
    return MTHomeCachedColor(255.0f, 128.0f, 0.0f, &color, &once);
}

UIColor *MTHomeBlueColor(void)
{
    static UIColor *color = nil;
    static dispatch_once_t once;
    return MTHomeCachedColor(64.0f, 188.0f, 244.0f, &color, &once);
}

BOOL MTHomeIsPad(void)
{
    return UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad;
}

CGFloat MTHomePosterWidth(void)
{
    return MTHomeIsPad() ? 140.0f : 100.0f;
}

CGFloat MTHomePosterHeight(void)
{
    return MTHomePosterWidth() * 1.5f;
}

CGFloat MTHomeGutter(void)
{
    return MTHomeIsPad() ? 14.0f : 10.0f;
}

CGFloat MTHomeScreenInset(void)
{
    return MTHomeIsPad() ? 24.0f : 16.0f;
}

CGFloat MTHomeContentMaxWidth(void)
{
    return MTHomeIsPad() ? 760.0f : 0.0f;
}

CGFloat MTHomeBarHeight(void)
{
    return 44.0f;
}
MT_FILE_EOF_9

echo "  writing MatineeUI/MTHomeViewController.h"
cat > 'MatineeUI/MTHomeViewController.h' <<'MT_FILE_EOF_10'
//
//  MTHomeViewController.h
//  Matinee
//
//  Letterboxd-style home screen: segmented Films/Reviews/Lists/Journal header,
//  poster rails ("Popular this week", "New from friends", "Popular with friends")
//  and a friend-review list. Same controller drives iPhone and iPad.
//

#import <UIKit/UIKit.h>

@interface MTHomeViewController : UIViewController

// Array of MTFeedSection. Setting it rebuilds the screen.
@property (nonatomic, retain) NSArray *sections;

- (id)initWithSections:(NSArray *)sections;

// Rebuild from the current `sections`.
- (void)reload;

@end
MT_FILE_EOF_10

echo "  writing MatineeUI/MTHomeViewController.m"
cat > 'MatineeUI/MTHomeViewController.m' <<'MT_FILE_EOF_11'
//
//  MTHomeViewController.m
//  Matinee
//

#import "MTHomeViewController.h"
#import "MTFeedModels.h"
#import "MTFeedService.h"
#import "MTHomeTheme.h"
#import "MTPosterStripView.h"
#import <QuartzCore/QuartzCore.h>
#import <math.h>

#pragma mark - row bookkeeping

typedef enum {
    MTHomeRowKindHeader = 0,
    MTHomeRowKindStrip,
    MTHomeRowKindReview,
    MTHomeRowKindPlaceholder
} MTHomeRowKind;

@interface MTHomeRow : NSObject
@property (nonatomic, retain) UIView *view;
@property (nonatomic, assign) MTHomeRowKind kind;
@property (nonatomic, assign) BOOL showsByline;
@end

@implementation MTHomeRow
- (void)dealloc
{
    [_view release];
    [super dealloc];
}
@end

#pragma mark - segmented header

@protocol MTHomeSegmentedBarDelegate <NSObject>
- (void)segmentedBarDidChangeSelection:(id)bar;
@end

@interface MTHomeSegmentedBar : UIView {
    NSArray *_titles;
    NSMutableArray *_buttons;
    UIView *_underline;
    UIView *_hairline;
}
@property (nonatomic, assign) id <MTHomeSegmentedBarDelegate> delegate;
@property (nonatomic, assign) NSInteger selectedIndex;
- (id)initWithTitles:(NSArray *)titles;
- (void)layoutForWidth:(CGFloat)width;
- (void)updateButtonSelection;
- (void)positionUnderline;
@end

@implementation MTHomeSegmentedBar

@synthesize delegate = _delegate;
@synthesize selectedIndex = _selectedIndex;

- (id)initWithTitles:(NSArray *)titles
{
    self = [super initWithFrame:CGRectZero];
    if (self) {
        self.backgroundColor = MTHomeBackgroundColor();
        _titles = [titles copy];
        _buttons = [[NSMutableArray alloc] init];

        NSUInteger i = 0;
        for (i = 0; i < _titles.count; i++) {
            UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
            [button setTitle:[_titles objectAtIndex:i] forState:UIControlStateNormal];
            [button setTitleColor:MTHomeSecondaryTextColor() forState:UIControlStateNormal];
            [button setTitleColor:MTHomeTextColor() forState:UIControlStateSelected];
            button.titleLabel.font = [UIFont systemFontOfSize:14.0f];
            button.tag = (NSInteger)i;
            [button addTarget:self
                       action:@selector(buttonTapped:)
             forControlEvents:UIControlEventTouchUpInside];
            [self addSubview:button];
            [_buttons addObject:button];
        }

        _underline = [[UIView alloc] initWithFrame:CGRectZero];
        _underline.backgroundColor = MTHomeGreenColor();
        [self addSubview:_underline];

        _hairline = [[UIView alloc] initWithFrame:CGRectZero];
        _hairline.backgroundColor = MTHomeSeparatorColor();
        [self addSubview:_hairline];

        _selectedIndex = 0;
        [self updateButtonSelection];
    }
    return self;
}

- (void)dealloc
{
    [_titles release];
    [_buttons release];
    [_underline release];
    [_hairline release];
    [super dealloc];
}

- (void)buttonTapped:(UIButton *)sender
{
    if (sender.tag == _selectedIndex) return;

    _selectedIndex = sender.tag;
    [self updateButtonSelection];
    [self positionUnderline];

    if ([_delegate respondsToSelector:@selector(segmentedBarDidChangeSelection:)]) {
        [_delegate segmentedBarDidChangeSelection:self];
    }
}

- (void)updateButtonSelection
{
    UIButton *button = nil;
    for (button in _buttons) {
        button.selected = (button.tag == _selectedIndex);
    }
}

- (void)positionUnderline
{
    if (_selectedIndex < 0 || (NSUInteger)_selectedIndex >= _buttons.count) return;

    UIButton *button = [_buttons objectAtIndex:(NSUInteger)_selectedIndex];
    CGRect frame = button.frame;
    _underline.frame = CGRectMake(CGRectGetMidX(frame) - 18.0f,
                                  CGRectGetHeight(self.bounds) - 3.0f,
                                  36.0f, 3.0f);
}

- (void)layoutForWidth:(CGFloat)width
{
    CGFloat height = CGRectGetHeight(self.bounds);
    NSUInteger count = _buttons.count;
    if (count == 0) return;

    CGFloat each = floorf(width / (CGFloat)count);
    NSUInteger i = 0;
    for (i = 0; i < count; i++) {
        UIButton *button = [_buttons objectAtIndex:i];
        button.frame = CGRectMake(each * (CGFloat)i, 0.0f, each, height - 3.0f);
    }

    _hairline.frame = CGRectMake(0.0f, height - 1.0f, width, 1.0f);
    [self positionUnderline];
}

@end

#pragma mark - section header

@interface MTSectionHeader : UIView {
    UILabel *_titleLabel;
    UILabel *_chevronLabel;
}
- (id)initWithTitle:(NSString *)title;
- (void)layoutForWidth:(CGFloat)width;
@end

@implementation MTSectionHeader

- (id)initWithTitle:(NSString *)title
{
    self = [super initWithFrame:CGRectZero];
    if (self) {
        _titleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _titleLabel.text = title;
        _titleLabel.font = [UIFont boldSystemFontOfSize:17.0f];
        _titleLabel.textColor = MTHomeTextColor();
        _titleLabel.backgroundColor = [UIColor clearColor];
        [self addSubview:_titleLabel];

        _chevronLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _chevronLabel.text = @"\u203A";
        _chevronLabel.font = [UIFont boldSystemFontOfSize:22.0f];
        _chevronLabel.textColor = MTHomeSecondaryTextColor();
        _chevronLabel.textAlignment = NSTextAlignmentRight;
        _chevronLabel.backgroundColor = [UIColor clearColor];
        [self addSubview:_chevronLabel];
    }
    return self;
}

- (void)dealloc
{
    [_titleLabel release];
    [_chevronLabel release];
    [super dealloc];
}

- (void)layoutForWidth:(CGFloat)width
{
    CGFloat height = CGRectGetHeight(self.bounds);
    CGFloat inset = MTHomeScreenInset();

    _titleLabel.frame = CGRectMake(inset, 0.0f, width - (inset * 2.0f) - 24.0f, height);
    _chevronLabel.frame = CGRectMake(width - inset - 24.0f, 0.0f, 24.0f, height);
}

@end

#pragma mark - review row

@interface MTReviewRowView : UIView {
    UIImageView *_poster;
    UILabel *_nameLabel;
    UILabel *_starsLabel;
    UILabel *_snippetLabel;
}
- (void)configureWithItem:(MTFeedItem *)item;
- (void)layoutForWidth:(CGFloat)width;
@end

@implementation MTReviewRowView

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = MTHomeBackgroundColor();

        _poster = [[UIImageView alloc] initWithFrame:CGRectZero];
        _poster.backgroundColor = MTHomeSurfaceColor();
        _poster.contentMode = UIViewContentModeScaleAspectFill;
        _poster.clipsToBounds = YES;
        _poster.layer.cornerRadius = 3.0f;
        [self addSubview:_poster];

        _nameLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _nameLabel.font = [UIFont boldSystemFontOfSize:13.0f];
        _nameLabel.textColor = MTHomeTextColor();
        _nameLabel.backgroundColor = [UIColor clearColor];
        _nameLabel.lineBreakMode = NSLineBreakByTruncatingTail;
        [self addSubview:_nameLabel];

        _starsLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _starsLabel.font = [UIFont systemFontOfSize:11.0f];
        _starsLabel.textColor = MTHomeGreenColor();
        _starsLabel.backgroundColor = [UIColor clearColor];
        [self addSubview:_starsLabel];

        _snippetLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _snippetLabel.font = [UIFont systemFontOfSize:12.0f];
        _snippetLabel.textColor = MTHomeSecondaryTextColor();
        _snippetLabel.backgroundColor = [UIColor clearColor];
        _snippetLabel.numberOfLines = 2;
        [self addSubview:_snippetLabel];
    }
    return self;
}

- (void)dealloc
{
    [_poster release];
    [_nameLabel release];
    [_starsLabel release];
    [_snippetLabel release];
    [super dealloc];
}

- (void)configureWithItem:(MTFeedItem *)item
{
    MTLoadImage(MTPosterURLString(item.posterPath), _poster);

    NSString *name = item.reviewerName.length ? item.reviewerName : @"friend";
    if (item.yearText.length) {
        _nameLabel.text = [NSString stringWithFormat:@"%@ \u00B7 %@ (%@)",
                           name, item.title, item.yearText];
    } else {
        _nameLabel.text = [NSString stringWithFormat:@"%@ \u00B7 %@", name, item.title];
    }

    _starsLabel.text = (item.rating > 0.0f) ? MTStarsString(item.rating) : @"";
    _snippetLabel.text = item.reviewSnippet;

    [self setNeedsLayout];
}

- (void)layoutForWidth:(CGFloat)width
{
    CGFloat inset = MTHomeScreenInset();

    _poster.frame = CGRectMake(inset, 8.0f, 44.0f, 66.0f);

    CGFloat textX = inset + 44.0f + 12.0f;
    CGFloat textWidth = width - textX - inset;
    if (textWidth < 0.0f) textWidth = 0.0f;

    _nameLabel.frame = CGRectMake(textX, 7.0f, textWidth, 16.0f);
    _starsLabel.frame = CGRectMake(textX, 25.0f, textWidth, 12.0f);
    _snippetLabel.frame = CGRectMake(textX, 41.0f, textWidth, 34.0f);
}

@end

#pragma mark - controller

@interface MTHomeViewController () <MTHomeSegmentedBarDelegate> {
    MTHomeSegmentedBar *_bar;
    UIScrollView *_scrollView;
    UIView *_contentView;
    NSMutableArray *_rows;
    UILabel *_placeholderLabel;
    UILabel *_statusLabel;
    UIRefreshControl *_refreshControl;
    MTFeedService *_service;
    BOOL _loading;
}
- (void)rebuildContent;
- (void)addRowView:(UIView *)view
              kind:(MTHomeRowKind)kind
      showsByline:(BOOL)showsByline;
- (void)showPlaceholder:(NSString *)text;
- (CGFloat)heightForRow:(MTHomeRow *)row width:(CGFloat)width;
- (void)layoutRowsForWidth:(CGFloat)viewWidth;
- (void)loadFeed;
- (void)refreshPulled:(id)sender;
- (void)statusTapped:(id)sender;
@end

@implementation MTHomeViewController

@synthesize sections = _sections;

- (id)init
{
    return [self initWithSections:nil];
}

- (id)initWithSections:(NSArray *)sections
{
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _sections = [sections retain];
        _rows = [[NSMutableArray alloc] init];
        self.title = @"Matinee";
    }
    return self;
}

- (void)dealloc
{
    [_bar release];
    [_scrollView release];
    [_contentView release];
    [_rows release];
    [_sections release];
    [_placeholderLabel release];
    [_statusLabel release];
    [_refreshControl release];
    [_service release];
    [super dealloc];
}

- (void)setSections:(NSArray *)sections
{
    if (_sections == sections) return;

    [_sections release];
    _sections = [sections retain];

    if ([self isViewLoaded]) {
        [self rebuildContent];
    }
}

- (void)reload
{
    [self loadFeed];
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.view.backgroundColor = MTHomeBackgroundColor();

    _bar = [[MTHomeSegmentedBar alloc] initWithTitles:
            [NSArray arrayWithObjects:@"Films", @"Reviews", @"Lists", @"Journal", nil]];
    _bar.delegate = self;
    [self.view addSubview:_bar];

    _scrollView = [[UIScrollView alloc] initWithFrame:CGRectZero];
    _scrollView.backgroundColor = MTHomeBackgroundColor();
    _scrollView.alwaysBounceVertical = YES;
    _scrollView.showsVerticalScrollIndicator = NO;
    [self.view addSubview:_scrollView];

    _contentView = [[UIView alloc] initWithFrame:CGRectZero];
    _contentView.backgroundColor = MTHomeBackgroundColor();
    [_scrollView addSubview:_contentView];

    _placeholderLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _placeholderLabel.font = [UIFont systemFontOfSize:14.0f];
    _placeholderLabel.textColor = MTHomeSecondaryTextColor();
    _placeholderLabel.backgroundColor = [UIColor clearColor];
    _placeholderLabel.textAlignment = NSTextAlignmentCenter;
    _placeholderLabel.numberOfLines = 0;
    _placeholderLabel.hidden = YES;
    [_contentView addSubview:_placeholderLabel];

    _statusLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _statusLabel.font = [UIFont systemFontOfSize:14.0f];
    _statusLabel.textColor = MTHomeSecondaryTextColor();
    _statusLabel.backgroundColor = [UIColor clearColor];
    _statusLabel.textAlignment = NSTextAlignmentCenter;
    _statusLabel.numberOfLines = 0;
    _statusLabel.hidden = YES;
    _statusLabel.userInteractionEnabled = YES;
    [self.view addSubview:_statusLabel];

    UITapGestureRecognizer *tap =
        [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(statusTapped:)];
    [_statusLabel addGestureRecognizer:tap];
    [tap release];

    _refreshControl = [[UIRefreshControl alloc] init];
    [_refreshControl addTarget:self
                        action:@selector(refreshPulled:)
              forControlEvents:UIControlEventValueChanged];
    [_scrollView addSubview:_refreshControl];

    _service = [[MTFeedService sharedService] retain];

    if (_sections) {
        [self rebuildContent];
    } else {
        [self loadFeed];
    }
}

- (void)viewWillLayoutSubviews
{
    [super viewWillLayoutSubviews];

    CGFloat width = CGRectGetWidth(self.view.bounds);
    CGFloat height = CGRectGetHeight(self.view.bounds);
    CGFloat barHeight = MTHomeBarHeight();

    _bar.frame = CGRectMake(0.0f, 0.0f, width, barHeight);
    [_bar layoutForWidth:width];

    _scrollView.frame = CGRectMake(0.0f, barHeight, width, height - barHeight);

    _statusLabel.frame = CGRectMake(24.0f, barHeight + 40.0f, width - 48.0f, 120.0f);

    [self layoutRowsForWidth:width];
}

#pragma mark - loading

- (void)loadFeed
{
    if (_loading) {
        [_refreshControl endRefreshing];
        return;
    }

    _loading = YES;
    _statusLabel.hidden = NO;
    _statusLabel.text = @"Loading your feed\u2026";

    MTHomeViewController *controller = self;
    [_service loadFeedWithCompletion:^(NSArray *sections, NSError *error) {
        controller->_loading = NO;
        [controller->_refreshControl endRefreshing];

        if (error || !sections.count) {
            controller->_statusLabel.hidden = NO;
            NSString *message = error ? [error localizedDescription] : @"No friend activity found.";
            controller->_statusLabel.text =
                [NSString stringWithFormat:@"%@\n\nTap to retry.", message];
            controller.sections = nil;
            [controller.view setNeedsLayout];
            return;
        }

        controller->_statusLabel.hidden = YES;
        controller.sections = sections;
        [controller.view setNeedsLayout];
    }];
}

- (void)refreshPulled:(id)sender
{
    (void)sender;
    [self loadFeed];
}

- (void)statusTapped:(id)sender
{
    (void)sender;
    if (_statusLabel.hidden || _loading) return;
    [self loadFeed];
}

#pragma mark - content

- (void)addRowView:(UIView *)view kind:(MTHomeRowKind)kind showsByline:(BOOL)showsByline
{
    MTHomeRow *row = [[MTHomeRow alloc] init];
    row.view = view;
    row.kind = kind;
    row.showsByline = showsByline;

    [_contentView addSubview:view];
    [_rows addObject:row];
    [row release];
}

- (void)rebuildContent
{
    MTHomeRow *row = nil;
    for (row in _rows) {
        [row.view removeFromSuperview];
    }
    [_rows removeAllObjects];

    _placeholderLabel.hidden = YES;

    NSInteger tab = _bar.selectedIndex;

    if (tab == 0) {
        for (MTFeedSection *section in _sections) {
            MTSectionHeader *header = [[MTSectionHeader alloc] initWithTitle:section.title];
            [self addRowView:header kind:MTHomeRowKindHeader showsByline:NO];
            [header release];

            MTPosterStripView *strip = [[MTPosterStripView alloc] initWithFrame:CGRectZero];
            [strip setItems:section.items showsByline:section.showsByline];
            [self addRowView:strip kind:MTHomeRowKindStrip showsByline:section.showsByline];
            [strip release];
        }
    } else if (tab == 1) {
        for (MTFeedSection *section in _sections) {
            for (MTFeedItem *item in section.items) {
                if (!item.reviewSnippet.length) continue;

                MTReviewRowView *review = [[MTReviewRowView alloc] initWithFrame:CGRectZero];
                [review configureWithItem:item];
                [self addRowView:review kind:MTHomeRowKindReview showsByline:YES];
                [review release];
            }
        }
        if (_rows.count == 0) {
            [self showPlaceholder:@"No friend reviews yet."];
        }
    } else if (tab == 2) {
        [self showPlaceholder:@"Lists from friends will land here."];
    } else {
        [self showPlaceholder:@"Journal entries will land here."];
    }

    [self.view setNeedsLayout];
}

- (void)showPlaceholder:(NSString *)text
{
    _placeholderLabel.text = text;
    _placeholderLabel.hidden = NO;
    [self addRowView:_placeholderLabel kind:MTHomeRowKindPlaceholder showsByline:NO];
}

#pragma mark - layout

- (CGFloat)heightForRow:(MTHomeRow *)row width:(CGFloat)width
{
    switch (row.kind) {
        case MTHomeRowKindHeader:
            return 34.0f;
        case MTHomeRowKindStrip:
            return [MTPosterStripView heightForWidth:width showsByline:row.showsByline] + 20.0f;
        case MTHomeRowKindReview:
            return 84.0f;
        case MTHomeRowKindPlaceholder:
        default:
            return 260.0f;
    }
}

- (void)layoutRowsForWidth:(CGFloat)viewWidth
{
    CGFloat maxWidth = MTHomeContentMaxWidth();
    CGFloat contentWidth = viewWidth;
    if (maxWidth > 0.0f && maxWidth < viewWidth) {
        contentWidth = maxWidth;
    }
    CGFloat originX = floorf((viewWidth - contentWidth) / 2.0f);

    CGFloat y = 0.0f;
    MTHomeRow *row = nil;
    for (row in _rows) {
        CGFloat rowHeight = [self heightForRow:row width:contentWidth];
        row.view.frame = CGRectMake(originX, y, contentWidth, rowHeight);

        if ([row.view respondsToSelector:@selector(layoutForWidth:)]) {
            [(id)row.view layoutForWidth:contentWidth];
        }
        y += rowHeight;
    }

    if (y < 1.0f) y = 1.0f;

    _contentView.frame = CGRectMake(0.0f, 0.0f, viewWidth, y + 24.0f);
    _scrollView.contentSize = CGSizeMake(viewWidth, y + 24.0f);
}

#pragma mark - segmented bar

- (void)segmentedBarDidChangeSelection:(id)bar
{
    (void)bar;
    [self rebuildContent];
}

#pragma mark - orientation

- (NSUInteger)supportedInterfaceOrientations
{
    return MTHomeIsPad() ? UIInterfaceOrientationMaskAll : UIInterfaceOrientationMaskPortrait;
}

@end
MT_FILE_EOF_11

echo "  writing MatineeUI/MTPosterStripView.h"
cat > 'MatineeUI/MTPosterStripView.h' <<'MT_FILE_EOF_12'
//
//  MTPosterStripView.h
//  Matinee
//
//  Horizontally scrolling row of film posters, exactly like Letterboxd's
//  "Popular this week" / "New from friends" rails.
//

#import <UIKit/UIKit.h>

@interface MTPosterStripView : UIView

// Total height for a strip at the given width (poster + optional byline).
+ (CGFloat)heightForWidth:(CGFloat)width showsByline:(BOOL)showsByline;

- (void)setItems:(NSArray *)items showsByline:(BOOL)showsByline;

// Call from the owner's layout pass, after the view's frame is set.
- (void)layoutForWidth:(CGFloat)width;

@end
MT_FILE_EOF_12

echo "  writing MatineeUI/MTPosterStripView.m"
cat > 'MatineeUI/MTPosterStripView.m' <<'MT_FILE_EOF_13'
//
//  MTPosterStripView.m
//  Matinee
//

#import "MTPosterStripView.h"
#import "MTFeedModels.h"
#import "MTHomeTheme.h"
#import <QuartzCore/QuartzCore.h>
#import <math.h>

#define MT_BYLINE_HEIGHT 26.0f

#pragma mark - card

@interface MTPosterCardView : UIView {
    UIImageView *_poster;
    UIImageView *_avatar;
    UILabel *_nameLabel;
    UILabel *_starsLabel;
    BOOL _showsByline;
}
- (void)configureWithItem:(MTFeedItem *)item showsByline:(BOOL)showsByline;
@end

@implementation MTPosterCardView

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        _poster = [[UIImageView alloc] initWithFrame:CGRectZero];
        _poster.backgroundColor = MTHomeSurfaceColor();
        _poster.contentMode = UIViewContentModeScaleAspectFill;
        _poster.clipsToBounds = YES;
        _poster.layer.cornerRadius = 3.0f;
        [self addSubview:_poster];

        _avatar = [[UIImageView alloc] initWithFrame:CGRectZero];
        _avatar.backgroundColor = MTHomeSurfaceColor();
        _avatar.contentMode = UIViewContentModeScaleAspectFill;
        _avatar.clipsToBounds = YES;
        _avatar.layer.cornerRadius = 9.0f;
        _avatar.hidden = YES;
        [self addSubview:_avatar];

        _nameLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _nameLabel.font = [UIFont systemFontOfSize:11.0f];
        _nameLabel.textColor = MTHomeSecondaryTextColor();
        _nameLabel.backgroundColor = [UIColor clearColor];
        _nameLabel.lineBreakMode = NSLineBreakByTruncatingTail;
        _nameLabel.hidden = YES;
        [self addSubview:_nameLabel];

        _starsLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _starsLabel.font = [UIFont systemFontOfSize:9.0f];
        _starsLabel.textColor = MTHomeGreenColor();
        _starsLabel.backgroundColor = [UIColor clearColor];
        _starsLabel.hidden = YES;
        [self addSubview:_starsLabel];
    }
    return self;
}

- (void)dealloc
{
    [_poster release];
    [_avatar release];
    [_nameLabel release];
    [_starsLabel release];
    [super dealloc];
}

- (void)configureWithItem:(MTFeedItem *)item showsByline:(BOOL)showsByline
{
    _showsByline = showsByline;

    // RSS feeds carry a display name but no avatar; collapse the avatar slot
    // so the name starts at the card edge instead of leaving a blank circle.
    _avatar.hidden = (!showsByline || !item.avatarPath.length);
    _nameLabel.hidden = !showsByline;
    _starsLabel.hidden = !showsByline;

    MTLoadImage(MTPosterURLString(item.posterPath), _poster);

    if (showsByline) {
        _nameLabel.text = item.reviewerName;
        _starsLabel.text = (item.rating > 0.0f) ? MTStarsString(item.rating) : @"";
        MTLoadImage(MTPosterURLString(item.avatarPath), _avatar);
    }

    [self setNeedsLayout];
}

- (void)layoutSubviews
{
    [super layoutSubviews];

    CGFloat width = CGRectGetWidth(self.bounds);
    CGFloat posterHeight = width * 1.5f;

    _poster.frame = CGRectMake(0.0f, 0.0f, width, posterHeight);

    if (!_showsByline) {
        _avatar.frame = CGRectZero;
        _nameLabel.frame = CGRectZero;
        _starsLabel.frame = CGRectZero;
        return;
    }

    CGFloat y = posterHeight + 7.0f;
    CGFloat textX = _avatar.hidden ? 0.0f : 23.0f;

    _avatar.frame = _avatar.hidden ? CGRectZero : CGRectMake(0.0f, y, 18.0f, 18.0f);
    _nameLabel.frame = CGRectMake(textX, y - 1.0f, width - textX, 12.0f);
    _starsLabel.frame = CGRectMake(textX, y + 10.0f, width - textX, 11.0f);
}

@end

#pragma mark - strip

@interface MTPosterStripView () {
    UIScrollView *_scrollView;
    NSMutableArray *_cards;
    BOOL _showsByline;
}
@end

@implementation MTPosterStripView

+ (CGFloat)heightForWidth:(CGFloat)width showsByline:(BOOL)showsByline
{
    CGFloat posterWidth = MTHomePosterWidth();
    if (posterWidth > width) posterWidth = width;
    CGFloat height = posterWidth * 1.5f;
    if (showsByline) height += MT_BYLINE_HEIGHT;
    return height;
}

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = MTHomeBackgroundColor();

        _scrollView = [[UIScrollView alloc] initWithFrame:CGRectZero];
        _scrollView.backgroundColor = MTHomeBackgroundColor();
        _scrollView.showsHorizontalScrollIndicator = NO;
        _scrollView.showsVerticalScrollIndicator = NO;
        _scrollView.alwaysBounceHorizontal = YES;
        _scrollView.decelerationRate = UIScrollViewDecelerationRateFast;
        [self addSubview:_scrollView];

        _cards = [[NSMutableArray alloc] init];
    }
    return self;
}

- (void)dealloc
{
    [_scrollView release];
    [_cards release];
    [super dealloc];
}

- (void)setItems:(NSArray *)items showsByline:(BOOL)showsByline
{
    _showsByline = showsByline;

    for (MTPosterCardView *card in _cards) {
        [card removeFromSuperview];
    }
    [_cards removeAllObjects];

    for (MTFeedItem *item in items) {
        MTPosterCardView *card = [[MTPosterCardView alloc] initWithFrame:CGRectZero];
        [card configureWithItem:item showsByline:showsByline];
        [_scrollView addSubview:card];
        [_cards addObject:card];
        [card release];
    }

    [self setNeedsLayout];
}

- (void)layoutForWidth:(CGFloat)width
{
    CGFloat height = CGRectGetHeight(self.bounds);
    _scrollView.frame = CGRectMake(0.0f, 0.0f, width, height);

    CGFloat posterWidth = MTHomePosterWidth();
    if (posterWidth > width) posterWidth = width;

    CGFloat gutter = MTHomeGutter();
    CGFloat inset = MTHomeScreenInset();
    CGFloat x = inset;

    for (MTPosterCardView *card in _cards) {
        card.frame = CGRectMake(x, 0.0f, posterWidth, height);
        x += posterWidth + gutter;
    }

    if (_cards.count == 0) {
        _scrollView.contentSize = CGSizeMake(width, height);
        return;
    }
    _scrollView.contentSize = CGSizeMake(x - gutter + inset, height);
}

@end
MT_FILE_EOF_13

echo "  writing MatineeUI/README.md"
cat > 'MatineeUI/README.md' <<'MT_FILE_EOF_14'
# Letterboxd-style home screen — drop-in files

Five classes. The view layer has no dependency on `MTEntry` or `MTAppearance`;
the feed service deliberately reuses `MTSecureClient` because it is the only path
that speaks TLS 1.2 to letterboxd.com from iOS 6. MRC throughout, iOS 6 only.

| File | Role |
|---|---|
| `MTHomeTheme.h/.m` | Palette (`#14181C` bg, `#00E054` green, `#99AABB` text) + iPhone/iPad metrics |
| `MTFeedModels.h/.m` | `MTFeedItem`, `MTFeedSection`, star strings, poster URL builder, cached async image loader |
| `MTFeedService.h/.m` | Fetches `/<user>/rss/` per friend, strips headers/dechunks, parses RSS, builds rails |
| `MTPosterStripView.h/.m` | Horizontal poster rail with optional friend byline (avatar + name + stars) |
| `MTHomeViewController.h/.m` | Segmented header, three rails, friend-review list, iPad layout |

## Add to the project

Copy the ten files next to your other sources (same folder as
`MTSearchViewController.m`). If your `Makefile` uses the usual Theos wildcard:

```
Matinee_FILES = $(wildcard *.m)
```

they are picked up automatically. Otherwise add each `.m` explicitly.

`QuartzCore` is used for poster corner rounding — if it isn't already linked:

```
Matinee_FRAMEWORKS = UIKit Foundation QuartzCore
```

## Wire it into the tab bar

```objc
#import "MTHomeViewController.h"

MTHomeViewController *home = [[[MTHomeViewController alloc] init] autorelease];
home.tabBarItem = [[[UITabBarItem alloc] initWithTitle:@"Films"
                                                image:[UIImage imageNamed:@"films.png"]
                                                  tag:0] autorelease];
// replace the "Most Recent" tab (or make it the first tab)
```

`init` loads built-in demo content, so it renders immediately with real
Letterboxd posters. To drive it from live data:

```objc
home.sections = [self sectionsFromCurrentFeed];   // rebuilds automatically
[home reload];                                     // or refresh in place
```

## Real data

The screen no longer ships demo content. On appearance it calls `MTFeedService`,
which fetches `https://letterboxd.com/<username>/rss/` for every entry in
`friendUsernames` and builds the rails:

- **New from friends** — newest activity, one entry per film, with byline
- **Popular with friends** — films watched by more than one friend, most-watched first
- **Highest rated by friends** — highest `memberRating` first
- **Reviews** tab — only items that actually carry review text

```objc
MTFeedService *service = [MTFeedService sharedService];
service.friendUsernames = [NSArray arrayWithObjects:@"yourname", @"friend1", @"friend2", nil];
```

Defaults are `dave`, `matthew`, `jack` (real public accounts) so it works before you
configure anything. Replace them with the signed-in user's friends.

The service depends on one method of your transport:

```objc
[MTSecureClient sendRequestToHost:@"letterboxd.com" path:path completion:^(NSData *data, NSError *error) { … }];
```

That matches the call already used in `MTSearchViewController.m`. If the real header
differs, it is a one-line change inside `-fetchPath:completion:`.

RSS is the only un-challenged endpoint (§measured status below). It also means
`MTSecureClient` must be working for the screen to show anything — the app will show
"Tap to retry" with the transport error until it is.

### Manual items

```objc
MTFeedItem *item = [MTFeedItem itemWithTitle:entry.title
                                        year:entry.yearText
                                      poster:entry.poster];   // fragment or full URL
item.reviewerName  = @"axel";
item.avatarPath    = avatarFragment;
item.rating        = 4.5f;
item.reviewSnippet = @"…";

MTFeedSection *rail = [MTFeedSection sectionWithTitle:@"New from friends"
                                                items:items
                                          showsByline:YES];
```

Poster and avatar paths may be either full `https://` URLs or the fragment
after `/resized/` — `MTPosterURLString()` handles both. Verified working
poster form on today's site:

```
https://a.ltrbxd.com/resized/film-poster/2/6/8/2/2682-primer-0-600-0-900-crop.jpg
```

Note `-0-600-0-900-crop.jpg` is the 2:3 poster crop. The older
`-0-1000-0-1500-crop.jpg` form now returns **403**.

## What populates it — measured status

This matters before wiring: most of Letterboxd's feed is not reachable from a
non-JS client today.

| Endpoint | Status | Usable |
|---|---|---|
| `/search/<q>/` | 200 but JS shell | No results in HTML |
| `/s/search/<q>/` | 403 Cloudflare | No |
| `/films/popular/` | 200 but JS shell | No |
| `/` (home) | 403 Cloudflare | No |
| **`/<username>/rss/`** | **200, RSS with 100 real items** | **Yes — used by MTFeedService** |
| `/film/<slug>/` | 200, 205 KB | **Yes** — posters, year, cast |
| `a.ltrbxd.com/resized/...` images | 200 `image/jpeg` | **Yes** |

So the rails can be filled today from: the user's own bookmarks/watched list,
film pages the client already fetched, or a JSON movie API. "New from friends"
needs real friend data, which requires authentication the current client does
not have — the UI supports it the moment you supply `reviewerName` / `rating` /
`avatarPath`.

## iPad

Same controller, no separate code path:

- content column capped at 760 pt and centred
- posters 140×210 instead of 100×150
- all orientations allowed (`supportedInterfaceOrientations`), portrait-only on phone

## Not included (deliberate, next pass)

- Bottom tab bar restyle — that lives in your app delegate / tab controller
- Nav bar chrome above the segmented header
- Lists and Journal tabs (placeholders today)
- Film detail push on poster tap
- Any networking — this is the view layer only

## Verification status

These files were **not compiled**: this workspace has no iOS SDK, Theos or UIKit,
so no `make` run was possible. What was checked statically:

- all four pairs brace/paren/bracket balanced
- zero ARC keywords (`strong`, `weak`, `__weak`, `__strong`)
- zero iOS 7+ APIs (`tintColor`, `NSLayoutConstraint`, `UICollectionView`,
  `stringByAddingPercentEncoding…`, `NSURLSession`, `UIAlertController`)
- every `dealloc` ends with `[super dealloc];`
- every method called from a class is declared in that class's interface or
  class extension

Build it on your Mac and send me any compiler output; with `-Werror` it should
be a short list.
MT_FILE_EOF_14

echo "  writing tlsprobe/FINDINGS.md"
cat > 'tlsprobe/FINDINGS.md' <<'MT_FILE_EOF_15'
# Letterboxd connectivity — measured findings (2026-10-24)

Everything here was measured against the live server from a real Mbed TLS 2.28.9
build (`tlsprobe/probe.c`), not inferred from documentation.

## TL;DR

1. **TLS is not the blocker.** Stock Mbed TLS 2.28.9 talks to letterboxd.com fine.
2. **Search cannot work by scraping.** `/search/` is a JS shell; `/s/search/` is
   a Cloudflare 403. This is true for every UA and every cipher.
3. Two real transport bugs remain: **chunked framing** and **single-read truncation**.

## 1. Handshake facts

| Fact | Value |
|---|---|
| Protocol | TLS 1.2 (server rejected handshake without SNI) |
| Cipher negotiated by default 2.28.9 | `TLS-ECDHE-ECDSA-WITH-CHACHA20-POLY1305-SHA256` |
| Server cert | ECDSA, `CN=letterboxd.com`, issuer `CN=WE1` (Google Trust Services) |
| Chain length | 3 certs (leaf, WE1, GTS Root R4 cross-signed by GlobalSign) |
| Cert validity | 2026-09-16 .. 2026-12-15 |
| Verification anchor | **GTS Root R4** — 765 bytes, `certs/letterboxd-anchor.pem` |
| Also accepted | ECDHE-ECDSA-AES128/256-GCM, ECDHE-RSA-AES128-GCM, P-256 key exchange |

Verified successful: `verify flags=0x00000000 [ok]` with only the 765-byte anchor.

Required `config.h` flags (all present in the 2.28.9 default config — do not disable):
`MBEDTLS_SSL_PROTO_TLS1_2`, `MBEDTLS_ECDSA_C`, `MBEDTLS_ECDH_C`,
`MBEDTLS_ECP_DP_SECP256R1_ENABLED`, `MBEDTLS_GCM_C`, `MBEDTLS_CHACHAPOLY_C`,
`MBEDTLS_AES_C`, `MBEDTLS_X509_CRT_PARSE_C`, `MBEDTLS_HAVE_TIME`.

### SNI is mandatory — proven

Removing `mbedtls_ssl_set_hostname()` fails immediately:

```
HANDSHAKE FAILED -0x7780 SSL - A fatal alert message was received from our peer
```

Cloudflare drops the connection because there is no server name to route on.
`mbedtls_ssl_set_hostname()` is what sends SNI *and* what sets the CN check target.

## 2. Chunked framing is real

`Connection: close` does **not** prevent it. Response to `GET ... HTTP/1.1`:

```
chunked=1 rawBody=81398
dechunked=81361        <- matches curl byte-for-byte
body[0:...]: 16c5   <!DOCTYPE html> ...
```

The body begins with `16c5\r\n` — a hex length. That is exactly what the parser
would choke on. Two fixes, both verified:

- **Preferred:** send `HTTP/1.0` in the request line. Server answers `HTTP/1.1 200`
  with `chunked=0 rawBody=81361` — correct body, no dechunking needed.
- **Belt and braces:** keep HTTP/1.1 and dechunk before parsing.

## 3. Truncation

The search page is **81,361 bytes** and arrives over **48 TLS reads**. A single
`mbedtls_ssl_read()` call returns at most one TLS record (~16 KB). Any client that
reads once and parses gets ~20% of the document. The read loop must run until
`MBEDTLS_ERR_SSL_PEER_CLOSE_NOTIFY`, `0`, or `MBEDTLS_ERR_SSL_CONN_EOF`.

## 4. Search endpoints — all dead ends for a non-JS client

| Path | Status | Server-rendered results? |
|---|---|---|
| `/search/primer/` | 200, 81 KB | **No.** `<div id="search-table-body">` is empty |
| `/s/search/primer/` | **403** `Just a moment...` | No — Cloudflare JS challenge |
| `/search/films/primer/` | **403** | No |
| `/search/cast-crew/primer/` | **403** | No |
| `/search/primer/page/2/` | **403** | No |
| `/film/primer/` | 200, 205 KB | Yes — 74 `<img>`, 19 `/resized/`, 14 `/film/` links |

The 200 page contains a JS shell that fetches `/s/search/` into `#search-table-body`
(see `data-url="/s/search/primer/"` on the "Show more results" link). That endpoint
is challenge-protected, so the markup never exists for a raw TLS client to parse.

Marker counts on the dechunked 200 body: `data-film-name=0`, `data-film-slug=0`,
`<img=0`, `href="/film/"=0`, `/resized/=0`. The `data-film-*` attributes the parser
looks for are **gone from the site entirely**, so `parseHTMLResults:` can never match
even if the transport is perfect.

Film pages do still work and still use `a.ltrbxd.com/resized/...` posters.

## 5. Diagnostic map for `MTSecureClient`

Log `-ret` as hex from every mbedtls call; match against this table.

| Code | Meaning | Usual cause here |
|---|---|---|
| `-0x0044` | NET_CONNECT_FAILED | DNS/socket; check `getaddrinfo` succeeded |
| `-0x004C` | NET_RECV_FAILED | socket closed early; often missing SNI |
| `-0x6900` | SSL_WANT_READ | **not an error** — retry the loop |
| `-0x2700` | X509_CERT_VERIFY_FAILED | no CA loaded, stale CA, or device clock wrong |
| `-0x7780` | FATAL_ALERT_MESSAGE | **missing SNI** (verified), or no common cipher |
| `-0x7380` | NO_CIPHER_CHOSEN | custom config with ECDSA/GCM/CHACHA disabled |
| `-0x7A00` | BAD_HS_CERTIFICATE | header/lib mismatch, or 1.x lib with 2.x headers |
| `-0x7880` | PEER_CLOSE_NOTIFY | normal end of a `Connection: close` response |

`-0x2700` deserves suspicion on this target: the device clock on an old jailbroken
iOS install is frequently wrong, and this cert is only valid
2026-09-16 .. 2026-12-15. Call `mbedtls_ssl_get_verify_result()` and print the flags
even in `VERIFY_NONE` mode — it reports `EXPIRED` / `NOT_YET_VALID` / `NOT_TRUSTED`
separately, which distinguishes a bad clock from a bad bundle in one run.

## 6. `MTDechunk` (drop-in, MRC-safe C)

```c
// returns bytes written to out, or -1 on malformed framing
static long MTDechunk(const uint8_t *in, size_t inlen, uint8_t *out, size_t outcap)
{
    size_t i = 0, o = 0;
    while (i < inlen) {
        while (i < inlen && (in[i] == '\r' || in[i] == '\n')) i++;
        if (i >= inlen) break;

        long size = 0; int digits = 0;
        while (i < inlen) {
            int c = in[i], h = -1;
            if (c >= '0' && c <= '9') h = c - '0';
            else if (c >= 'a' && c <= 'f') h = c - 'a' + 10;
            else if (c >= 'A' && c <= 'F') h = c - 'A' + 10;
            if (h < 0) break;
            size = size * 16 + h; digits++; i++;
        }
        if (!digits) return -1;
        while (i < inlen && in[i] != '\n') i++;   // skip chunk extension
        i++;
        if (size == 0) break;
        if (o + (size_t)size > outcap || i + (size_t)size > inlen) return -1;
        memcpy(out + o, in + i, (size_t)size);
        o += (size_t)size; i += (size_t)size;
    }
    return (long)o;
}
```

Only call it when the response headers contain `Transfer-Encoding: chunked`.

## 7. Reproducing

```
cd tlsprobe
curl -sSL -o mbedtls.tar.gz \
  https://github.com/Mbed-TLS/mbedtls/archive/refs/tags/v2.28.9.tar.gz
tar xzf mbedtls.tar.gz && (cd mbedtls-2.28.9 && make -j4 lib)

gcc -O1 -I mbedtls-2.28.9/include -o probe probe.c \
    mbedtls-2.28.9/library/libmbedtls.a \
    mbedtls-2.28.9/library/libmbedx509.a \
    mbedtls-2.28.9/library/libmbedcrypto.a

./probe required /search/primer/ sni http10
MT_CA=certs/letterboxd-anchor.pem ./probe required /film/primer/ sni http10
./probe none /search/primer/ nosni          # demonstrates the SNI failure
```
MT_FILE_EOF_15

echo "  writing tlsprobe/certs/ca-letterboxd.pem"
cat > 'tlsprobe/certs/ca-letterboxd.pem' <<'MT_FILE_EOF_16'
-----BEGIN CERTIFICATE-----
MIIFVzCCAz+gAwIBAgINAgPlk28xsBNJiGuiFzANBgkqhkiG9w0BAQwFADBHMQsw
CQYDVQQGEwJVUzEiMCAGA1UEChMZR29vZ2xlIFRydXN0IFNlcnZpY2VzIExMQzEU
MBIGA1UEAxMLR1RTIFJvb3QgUjEwHhcNMTYwNjIyMDAwMDAwWhcNMzYwNjIyMDAw
MDAwWjBHMQswCQYDVQQGEwJVUzEiMCAGA1UEChMZR29vZ2xlIFRydXN0IFNlcnZp
Y2VzIExMQzEUMBIGA1UEAxMLR1RTIFJvb3QgUjEwggIiMA0GCSqGSIb3DQEBAQUA
A4ICDwAwggIKAoICAQC2EQKLHuOhd5s73L+UPreVp0A8of2C+X0yBoJx9vaMf/vo
27xqLpeXo4xL+Sv2sfnOhB2x+cWX3u+58qPpvBKJXqeqUqv4IyfLpLGcY9vXmX7w
Cl7raKb0xlpHDU0QM+NOsROjyBhsS+z8CZDfnWQpJSMHobTSPS5g4M/SCYe7zUjw
TcLCeoiKu7rPWRnWr4+wB7CeMfGCwcDfLqZtbBkOtdh+JhpFAz2weaSUKK0Pfybl
qAj+lug8aJRT7oM6iCsVlgmy4HqMLnXWnOunVmSPlk9orj2XwoSPwLxAwAtcvfaH
szVsrBhQf4TgTM2S0yDpM7xSma8ytSmzJSq0SPly4cpk9+aCEI3oncKKiPo4Zor8
Y/kB+Xj9e1x3+naH+uzfsQ55lVe0vSbv1gHR6xYKu44LtcXFilWr06zqkUspzBmk
MiVOKvFlRNACzqrOSbTqn3yDsEB750Orp2yjj32JgfpMpf/VjsPOS+C12LOORc92
wO1AK/1TD7Cn1TsNsYqiA94xrcx36m97PtbfkSIS5r762DL8EGMUUXLeXdYWk70p
aDPvOmbsB4om3xPXV2V4J95eSRQAogB/mqghtqmxlbCluQ0WEdrHbEg8QOB+DVrN
VjzRlwW5y0vtOUucxD/SVRNuJLDWcfr0wbrM7Rv1/oFB2ACYPTrIrnqYNxgFlQID
AQABo0IwQDAOBgNVHQ8BAf8EBAMCAYYwDwYDVR0TAQH/BAUwAwEB/zAdBgNVHQ4E
FgQU5K8rJnEaK0gnhS9SZizv8IkTcT4wDQYJKoZIhvcNAQEMBQADggIBAJ+qQibb
C5u+/x6Wki4+omVKapi6Ist9wTrYggoGxval3sBOh2Z5ofmmWJyq+bXmYOfg6LEe
QkEzCzc9zolwFcq1JKjPa7XSQCGYzyI0zzvFIoTgxQ6KfF2I5DUkzps+GlQebtuy
h6f88/qBVRRiClmpIgUxPoLW7ttXNLwzldMXG+gnoot7TiYaelpkttGsN/H9oPM4
7HLwEXWdyzRSjeZ2axfG34arJ45JK3VmgRAhpuo+9K4l/3wV3s6MJT/KYnAK9y8J
ZgfIPxz88NtFMN9iiMG1D53Dn0reWVlHxYciNuaCp+0KueIHoI17eko8cdLiA6Ef
MgfdG+RCzgwARWGAtQsgWSl4vflVy2PFPEz0tv/bal8xa5meLMFrUKTX5hgUvYU/
Z6tGn6D/Qqc6f1zLXbBwHSs09dR2CQzreExZBfMzQsNhFRAbd03OIozUhfJFfbdT
6u9AWpQKXCBfTkBdYiJ23//OYb2MI3jSNwLgjt7RETeJ9r/tSQdirpLsQBqvFAnZ
0E6yove+7u7Y/9waLd64NnHi/Hm3lCXRSHNboTXns5lndcEZOitHTtNCjv0xyBZm
2tIMPNuzjsmhDYAPexZ3FL//2wmUspO8IFgV6dtxQ/PeEMMA3KgqlbbC1j+Qa3bb
bP6MvPJwNQzcmRk13NfIRmPVNnGuV/u3gm3c
-----END CERTIFICATE-----
-----BEGIN CERTIFICATE-----
MIICCTCCAY6gAwIBAgINAgPlwGjvYxqccpBQUjAKBggqhkjOPQQDAzBHMQswCQYD
VQQGEwJVUzEiMCAGA1UEChMZR29vZ2xlIFRydXN0IFNlcnZpY2VzIExMQzEUMBIG
A1UEAxMLR1RTIFJvb3QgUjQwHhcNMTYwNjIyMDAwMDAwWhcNMzYwNjIyMDAwMDAw
WjBHMQswCQYDVQQGEwJVUzEiMCAGA1UEChMZR29vZ2xlIFRydXN0IFNlcnZpY2Vz
IExMQzEUMBIGA1UEAxMLR1RTIFJvb3QgUjQwdjAQBgcqhkjOPQIBBgUrgQQAIgNi
AATzdHOnaItgrkO4NcWBMHtLSZ37wWHO5t5GvWvVYRg1rkDdc/eJkTBa6zzuhXyi
QHY7qca4R9gq55KRanPpsXI5nymfopjTX15YhmUPoYRlBtHci8nHc8iMai/lxKvR
HYqjQjBAMA4GA1UdDwEB/wQEAwIBhjAPBgNVHRMBAf8EBTADAQH/MB0GA1UdDgQW
BBSATNbrdP9JNqPV2Py1PsVq8JQdjDAKBggqhkjOPQQDAwNpADBmAjEA6ED/g94D
9J+uHXqnLrmvT/aDHQ4thQEd0dlq7A/Cr8deVl5c1RxYIigL9zC2L7F8AjEA8GE8
p/SgguMh1YQdc4acLa/KNJvxn7kjNuK8YAOdgLOaVsjh4rsUecrNIdSUtUlD
-----END CERTIFICATE-----
-----BEGIN CERTIFICATE-----
MIIDXzCCAkegAwIBAgILBAAAAAABIVhTCKIwDQYJKoZIhvcNAQELBQAwTDEgMB4G
A1UECxMXR2xvYmFsU2lnbiBSb290IENBIC0gUjMxEzARBgNVBAoTCkdsb2JhbFNp
Z24xEzARBgNVBAMTCkdsb2JhbFNpZ24wHhcNMDkwMzE4MTAwMDAwWhcNMjkwMzE4
MTAwMDAwWjBMMSAwHgYDVQQLExdHbG9iYWxTaWduIFJvb3QgQ0EgLSBSMzETMBEG
A1UEChMKR2xvYmFsU2lnbjETMBEGA1UEAxMKR2xvYmFsU2lnbjCCASIwDQYJKoZI
hvcNAQEBBQADggEPADCCAQoCggEBAMwldpB5BngiFvXAg7aEyiie/QV2EcWtiHL8
RgJDx7KKnQRfJMsuS+FggkbhUqsMgUdwbN1k0ev1LKMPgj0MK66X17YUhhB5uzsT
gHeMCOFJ0mpiLx9e+pZo34knlTifBtc+ycsmWQ1z3rDI6SYOgxXG71uL0gRgykmm
KPZpO/bLyCiR5Z2KYVc3rHQU3HTgOu5yLy6c+9C7v/U9AOEGM+iCK65TpjoWc4zd
QQ4gOsC0p6Hpsk+QLjJg6VfLuQSSaGjlOCZgdbKfd/+RFO+uIEn8rUAVSNECMWEZ
XriX7613t2Saer9fwRPvm2L7DWzgVGkWqQPabumDk3F2xmmFghcCAwEAAaNCMEAw
DgYDVR0PAQH/BAQDAgEGMA8GA1UdEwEB/wQFMAMBAf8wHQYDVR0OBBYEFI/wS3+o
LkUkrk1Q+mOai97i3Ru8MA0GCSqGSIb3DQEBCwUAA4IBAQBLQNvAUKr+yAzv95ZU
RUm7lgAJQayzE4aGKAczymvmdLm6AC2upArT9fHxD4q/c2dKg8dEe3jgr25sbwMp
jjM5RcOO5LlXbKr8EpbsU8Yt5CRsuZRj+9xTaGdWPoO4zzUhw8lo/s7awlOqzJCK
6fBdRoyV3XpYKBovHd7NADdBj+1EbddTKJd+82cEHhXXipa0095MJ6RMG3NzdvQX
mcIfeg7jLQitChws/zyrVQ4PkX4268NXSb7hLi18YIvDQVETI53O9zJrlAGomecs
Mx86OyXShkDOOyyGeMlhLxS67ttVb9+E7gUJTb0o2HLO02JQZR7rkpeDMdmztcpH
WD9f
-----END CERTIFICATE-----
-----BEGIN CERTIFICATE-----
MIIFgzCCA2ugAwIBAgIORea7A4Mzw4VlSOb/RVEwDQYJKoZIhvcNAQEMBQAwTDEg
MB4GA1UECxMXR2xvYmFsU2lnbiBSb290IENBIC0gUjYxEzARBgNVBAoTCkdsb2Jh
bFNpZ24xEzARBgNVBAMTCkdsb2JhbFNpZ24wHhcNMTQxMjEwMDAwMDAwWhcNMzQx
MjEwMDAwMDAwWjBMMSAwHgYDVQQLExdHbG9iYWxTaWduIFJvb3QgQ0EgLSBSNjET
MBEGA1UEChMKR2xvYmFsU2lnbjETMBEGA1UEAxMKR2xvYmFsU2lnbjCCAiIwDQYJ
KoZIhvcNAQEBBQADggIPADCCAgoCggIBAJUH6HPKZvnsFMp7PPcNCPG0RQssgrRI
xutbPK6DuEGSMxSkb3/pKszGsIhrxbaJ0cay/xTOURQh7ErdG1rG1ofuTToVBu1k
ZguSgMpE3nOUTvOniX9PeGMIyBJQbUJmL025eShNUhqKGoC3GYEOfsSKvGRMIRxD
aNc9PIrFsmbVkJq3MQbFvuJtMgamHvm566qjuL++gmNQ0PAYid/kD3n16qIfKtJw
LnvnvJO7bVPiSHyMEAc4/2ayd2F+4OqMPKq0pPbzlUoSB239jLKJz9CgYXfIWHSw
1CM69106yqLbnQneXUQtkPGBzVeS+n68UARjNN9rkxi+azayOeSsJDa38O+2HBNX
k7besvjihbdzorg1qkXy4J02oW9UivFyVm4uiMVRQkQVlO6jxTiWm05OWgtH8wY2
SXcwvHE35absIQh1/OZhFj931dmRl4QKbNQCTXTAFO39OfuD8l4UoQSwC+n+7o/h
bguyCLNhZglqsQY6ZZZZwPA1/cnaKI0aEYdwgQqomnUdnjqGBQCe24DWJfncBZ4n
WUx2OVvq+aWh2IMP0f/fMBH5hc8zSPXKbWQULHpYT9NLCEnFlWQaYw55PfWzjMpY
rZxCRXluDocZXFSxZba/jJvcE+kNb7gu3GduyYsRtYQUigAZcIN5kZeR1Bonvzce
MgfYFGM8KEyvAgMBAAGjYzBhMA4GA1UdDwEB/wQEAwIBBjAPBgNVHRMBAf8EBTAD
AQH/MB0GA1UdDgQWBBSubAWjkxPioufi1xzWx/B/yGdToDAfBgNVHSMEGDAWgBSu
bAWjkxPioufi1xzWx/B/yGdToDANBgkqhkiG9w0BAQwFAAOCAgEAgyXt6NH9lVLN
nsAEoJFp5lzQhN7craJP6Ed41mWYqVuoPId8AorRbrcWc+ZfwFSY1XS+wc3iEZGt
Ixg93eFyRJa0lV7Ae46ZeBZDE1ZXs6KzO7V33EByrKPrmzU+sQghoefEQzd5Mr61
55wsTLxDKZmOMNOsIeDjHfrYBzN2VAAiKrlNIC5waNrlU/yDXNOd8v9EDERm8tLj
vUYAGm0CuiVdjaExUd1URhxN25mW7xocBFymFe944Hn+Xds+qkxV/ZoVqW/hpvvf
cDDpw+5CRu3CkwWJ+n1jez/QcYF8AOiYrg54NMMl+68KnyBr3TsTjxKM4kEaSHpz
oHdpx7Zcf4LIHv5YGygrqGytXm3ABdJ7t+uA/iU3/gKbaKxCXcPu9czc8FB10jZp
nOZ7BN9uBmm23goJSFmH63sUYHpkqmlD75HHTOwY3WzvUy2MmeFe8nI+z1TIvWfs
pA9MRf/TuTAjB0yPEL+GltmZWrSZVxykzLsViVO6LAUP5MSeGbEYNNVMnbrt9x+v
JJUEeKgDu+6B5dpffItKoZB0JaezPkvILFa9x8jvOOJckvB595yEunQtYQEgfn7R
8k8HWV+LLUNS60YMlOH1Zkd5d9VUWx+tJDfLRVpOoERIyNiwmcUVhAn21klJwGW4
5hpxbqCo8YLoRT5s1gLXCmeDBVrJpBA=
-----END CERTIFICATE-----
MT_FILE_EOF_16

echo "  writing tlsprobe/certs/gts-r4-only.pem"
cat > 'tlsprobe/certs/gts-r4-only.pem' <<'MT_FILE_EOF_17'
-----BEGIN CERTIFICATE-----
MIICCTCCAY6gAwIBAgINAgPlwGjvYxqccpBQUjAKBggqhkjOPQQDAzBHMQswCQYD
VQQGEwJVUzEiMCAGA1UEChMZR29vZ2xlIFRydXN0IFNlcnZpY2VzIExMQzEUMBIG
A1UEAxMLR1RTIFJvb3QgUjQwHhcNMTYwNjIyMDAwMDAwWhcNMzYwNjIyMDAwMDAw
WjBHMQswCQYDVQQGEwJVUzEiMCAGA1UEChMZR29vZ2xlIFRydXN0IFNlcnZpY2Vz
IExMQzEUMBIGA1UEAxMLR1RTIFJvb3QgUjQwdjAQBgcqhkjOPQIBBgUrgQQAIgNi
AATzdHOnaItgrkO4NcWBMHtLSZ37wWHO5t5GvWvVYRg1rkDdc/eJkTBa6zzuhXyi
QHY7qca4R9gq55KRanPpsXI5nymfopjTX15YhmUPoYRlBtHci8nHc8iMai/lxKvR
HYqjQjBAMA4GA1UdDwEB/wQEAwIBhjAPBgNVHRMBAf8EBTADAQH/MB0GA1UdDgQW
BBSATNbrdP9JNqPV2Py1PsVq8JQdjDAKBggqhkjOPQQDAwNpADBmAjEA6ED/g94D
9J+uHXqnLrmvT/aDHQ4thQEd0dlq7A/Cr8deVl5c1RxYIigL9zC2L7F8AjEA8GE8
p/SgguMh1YQdc4acLa/KNJvxn7kjNuK8YAOdgLOaVsjh4rsUecrNIdSUtUlD
-----END CERTIFICATE-----
MT_FILE_EOF_17

echo "  writing tlsprobe/certs/letterboxd-anchor.pem"
cat > 'tlsprobe/certs/letterboxd-anchor.pem' <<'MT_FILE_EOF_18'
-----BEGIN CERTIFICATE-----
MIICCTCCAY6gAwIBAgINAgPlwGjvYxqccpBQUjAKBggqhkjOPQQDAzBHMQswCQYD
VQQGEwJVUzEiMCAGA1UEChMZR29vZ2xlIFRydXN0IFNlcnZpY2VzIExMQzEUMBIG
A1UEAxMLR1RTIFJvb3QgUjQwHhcNMTYwNjIyMDAwMDAwWhcNMzYwNjIyMDAwMDAw
WjBHMQswCQYDVQQGEwJVUzEiMCAGA1UEChMZR29vZ2xlIFRydXN0IFNlcnZpY2Vz
IExMQzEUMBIGA1UEAxMLR1RTIFJvb3QgUjQwdjAQBgcqhkjOPQIBBgUrgQQAIgNi
AATzdHOnaItgrkO4NcWBMHtLSZ37wWHO5t5GvWvVYRg1rkDdc/eJkTBa6zzuhXyi
QHY7qca4R9gq55KRanPpsXI5nymfopjTX15YhmUPoYRlBtHci8nHc8iMai/lxKvR
HYqjQjBAMA4GA1UdDwEB/wQEAwIBhjAPBgNVHRMBAf8EBTADAQH/MB0GA1UdDgQW
BBSATNbrdP9JNqPV2Py1PsVq8JQdjDAKBggqhkjOPQQDAwNpADBmAjEA6ED/g94D
9J+uHXqnLrmvT/aDHQ4thQEd0dlq7A/Cr8deVl5c1RxYIigL9zC2L7F8AjEA8GE8
p/SgguMh1YQdc4acLa/KNJvxn7kjNuK8YAOdgLOaVsjh4rsUecrNIdSUtUlD
-----END CERTIFICATE-----
MT_FILE_EOF_18

echo "  writing tlsprobe/probe.c"
cat > 'tlsprobe/probe.c' <<'MT_FILE_EOF_19'
/*
 * probe.c - Mbed TLS 2.28 client mirroring what MTSecureClient must do:
 * entropy -> drbg -> TCP -> SNI -> handshake -> HTTP GET -> header strip ->
 * dechunk -> content checks.
 *
 * usage: probe <mode> <path> [sni|nosni] [http11|http10]
 *   mode  none     : VERIFY_NONE, no CA loaded (transport-only)
 *         required : load CA bundle, VERIFY_REQUIRED
 *         report   : VERIFY_NONE but load CA and report why verification fails
 */

#include <stdio.h>
#include <string.h>
#include <stdlib.h>

#include "mbedtls/net_sockets.h"
#include "mbedtls/ssl.h"
#include "mbedtls/entropy.h"
#include "mbedtls/ctr_drbg.h"
#include "mbedtls/error.h"
#include "mbedtls/x509_crt.h"

#define HOST "letterboxd.com"
#define PORT "443"
#define CA_BUNDLE "/etc/ssl/certs/ca-certificates.crt"
#define MAXBODY (512 * 1024)

static unsigned char raw[MAXBODY + 1];
static unsigned char body[MAXBODY + 1];

static void dump_flags(char *buf, size_t len, uint32_t flags)
{
    buf[0] = 0;
    if (flags & MBEDTLS_X509_BADCERT_EXPIRED)     strncat(buf, "EXPIRED ", len - strlen(buf) - 1);
    if (flags & MBEDTLS_X509_BADCERT_REVOKED)     strncat(buf, "REVOKED ", len - strlen(buf) - 1);
    if (flags & MBEDTLS_X509_BADCERT_CN_MISMATCH) strncat(buf, "CN_MISMATCH ", len - strlen(buf) - 1);
    if (flags & MBEDTLS_X509_BADCERT_NOT_TRUSTED) strncat(buf, "NOT_TRUSTED ", len - strlen(buf) - 1);
    if (flags & MBEDTLS_X509_BADCERT_FUTURE)      strncat(buf, "NOT_YET_VALID ", len - strlen(buf) - 1);
    if (flags & MBEDTLS_X509_BADCERT_BAD_KEY)     strncat(buf, "BAD_KEY ", len - strlen(buf) - 1);
    if (flags == 0)                               strncat(buf, "ok", len - strlen(buf) - 1);
}

static int hexval(int c)
{
    if (c >= '0' && c <= '9') return c - '0';
    if (c >= 'a' && c <= 'f') return c - 'a' + 10;
    if (c >= 'A' && c <= 'F') return c - 'A' + 10;
    return -1;
}

/* Returns decompressed size, or -1 if the framing is malformed. */
static long dechunk(const unsigned char *in, size_t inlen, unsigned char *out, size_t outcap)
{
    size_t i = 0, o = 0;
    while (i < inlen) {
        /* skip CRLF between chunks */
        while (i < inlen && (in[i] == '\r' || in[i] == '\n')) i++;
        if (i >= inlen) break;

        long size = 0;
        int digits = 0;
        while (i < inlen) {
            int h = hexval(in[i]);
            if (h < 0) break;
            size = size * 16 + h;
            digits++;
            i++;
        }
        if (!digits) return -1;
        /* skip chunk extensions up to CRLF */
        while (i < inlen && in[i] != '\n') i++;
        i++;

        if (size == 0) break;
        if (o + (size_t)size > outcap) return -1;
        if (i + (size_t)size > inlen) return -1;
        memcpy(out + o, in + i, (size_t)size);
        o += (size_t)size;
        i += (size_t)size;
    }
    return (long)o;
}

static size_t count_occurrences(const unsigned char *hay, size_t n, const char *needle)
{
    size_t len = strlen(needle), count = 0;
    if (!len || n < len) return 0;
    for (size_t i = 0; i + len <= n; i++) {
        if (memcmp(hay + i, needle, len) == 0) count++;
    }
    return count;
}

int main(int argc, char **argv)
{
    const char *mode = (argc > 1) ? argv[1] : "none";
    const char *path = (argc > 2) ? argv[2] : "/search/primer/";
    int no_sni   = (argc > 3 && strcmp(argv[3], "nosni") == 0);
    int http10   = (argc > 4 && strcmp(argv[4], "http10") == 0);
    int verify_required = (strcmp(mode, "required") == 0);
    int load_ca = verify_required || (strcmp(mode, "report") == 0);
    const char *ca_path = getenv("MT_CA");
    if (!ca_path) ca_path = CA_BUNDLE;

    mbedtls_net_context server_fd;
    mbedtls_entropy_context entropy;
    mbedtls_ctr_drbg_context ctr_drbg;
    mbedtls_ssl_context ssl;
    mbedtls_ssl_config conf;
    mbedtls_x509_crt cacert;
    char errbuf[256];
    int ret;
    const char *pers = "mtprobe";

    mbedtls_net_init(&server_fd);
    mbedtls_ssl_init(&ssl);
    mbedtls_ssl_config_init(&conf);
    mbedtls_ctr_drbg_init(&ctr_drbg);
    mbedtls_entropy_init(&entropy);
    mbedtls_x509_crt_init(&cacert);

    ret = mbedtls_ctr_drbg_seed(&ctr_drbg, mbedtls_entropy_func, &entropy,
                                (const unsigned char *)pers, strlen(pers));
    if (ret != 0) { printf("FAIL ctr_drbg_seed -0x%04x\n", -ret); return 1; }

    if (load_ca) {
        ret = mbedtls_x509_crt_parse_file(&cacert, ca_path);
        if (ret < 0) {
            mbedtls_strerror(ret, errbuf, sizeof(errbuf));
            printf("WARN ca load failed -0x%04x %s\n", -ret, errbuf);
        }
    }

    mbedtls_ssl_config_defaults(&conf, MBEDTLS_SSL_IS_CLIENT,
                                MBEDTLS_SSL_TRANSPORT_STREAM, MBEDTLS_SSL_PRESET_DEFAULT);
    mbedtls_ssl_conf_authmode(&conf, verify_required ? MBEDTLS_SSL_VERIFY_REQUIRED
                                                     : MBEDTLS_SSL_VERIFY_NONE);
    if (load_ca) mbedtls_ssl_conf_ca_chain(&conf, &cacert, NULL);
    mbedtls_ssl_conf_rng(&conf, mbedtls_ctr_drbg_random, &ctr_drbg);
    mbedtls_ssl_conf_min_version(&conf, MBEDTLS_SSL_MAJOR_VERSION_3, MBEDTLS_SSL_MINOR_VERSION_3);

    if ((ret = mbedtls_ssl_setup(&ssl, &conf)) != 0) {
        printf("FAIL ssl_setup -0x%04x\n", -ret); return 1;
    }
    if (!no_sni && (ret = mbedtls_ssl_set_hostname(&ssl, HOST)) != 0) {
        printf("FAIL set_hostname -0x%04x\n", -ret); return 1;
    }

    printf("mode=%s sni=%s http=%s path=%s\n", mode, no_sni ? "off" : HOST,
           http10 ? "1.0" : "1.1", path);

    ret = mbedtls_net_connect(&server_fd, HOST, PORT, MBEDTLS_NET_PROTO_TCP);
    if (ret != 0) {
        mbedtls_strerror(ret, errbuf, sizeof(errbuf));
        printf("net_connect FAILED -0x%04x %s\n", -ret, errbuf);
        goto out;
    }

    mbedtls_ssl_set_bio(&ssl, &server_fd, mbedtls_net_send, mbedtls_net_recv, NULL);
    while ((ret = mbedtls_ssl_handshake(&ssl)) != 0) {
        if (ret != MBEDTLS_ERR_SSL_WANT_READ && ret != MBEDTLS_ERR_SSL_WANT_WRITE) {
            mbedtls_strerror(ret, errbuf, sizeof(errbuf));
            printf("HANDSHAKE FAILED -0x%04x %s\n", -ret, errbuf);
            goto out;
        }
    }
    printf("handshake: %s / %s\n", mbedtls_ssl_get_version(&ssl), mbedtls_ssl_get_ciphersuite(&ssl));
    {
        char fbuf[256];
        uint32_t flags = mbedtls_ssl_get_verify_result(&ssl);
        dump_flags(fbuf, sizeof(fbuf), flags);
        printf("verify flags=0x%08x [%s]\n", (unsigned)flags, fbuf);
    }

    {
        char req[512];
        int n = snprintf(req, sizeof(req),
            "GET %s HTTP/%s\r\n"
            "Host: " HOST "\r\n"
            "User-Agent: Mozilla/5.0 (iPhone; CPU iPhone OS 6_1 like Mac OS X) "
            "AppleWebKit/536.26 (KHTML, like Gecko) Version/6.0 Mobile/10B329 Safari/8536.25\r\n"
            "Accept: text/html,application/xhtml+xml\r\n"
            "Accept-Language: en-US,en;q=0.8\r\n"
            "Accept-Encoding: identity\r\n"
            "%s\r\n",
            path, http10 ? "1.0" : "1.1",
            http10 ? "" : "Connection: close\r\n");
        if ((ret = mbedtls_ssl_write(&ssl, (const unsigned char *)req, (size_t)n)) < 0) {
            mbedtls_strerror(ret, errbuf, sizeof(errbuf));
            printf("WRITE FAILED -0x%04x %s\n", -ret, errbuf);
            goto out;
        }
    }

    {
        size_t total = 0;
        int reads = 0;
        while (total < MAXBODY) {
            ret = mbedtls_ssl_read(&ssl, raw + total, MAXBODY - total);
            if (ret > 0) { total += (size_t)ret; reads++; continue; }
            if (ret == 0 || ret == MBEDTLS_ERR_SSL_PEER_CLOSE_NOTIFY) break;
            if (ret == MBEDTLS_ERR_SSL_WANT_READ || ret == MBEDTLS_ERR_SSL_WANT_WRITE) continue;
            mbedtls_strerror(ret, errbuf, sizeof(errbuf));
            printf("read ended -0x%04x %s\n", -ret, errbuf);
            break;
        }
        printf("raw=%zu bytes in %d reads\n", total, reads);

        /* header / body split */
        size_t hdrEnd = 0, i;
        for (i = 0; i + 3 < total; i++) {
            if (raw[i]=='\r'&&raw[i+1]=='\n'&&raw[i+2]=='\r'&&raw[i+3]=='\n') { hdrEnd = i + 4; break; }
        }
        printf("--- headers ---\n");
        fwrite(raw, 1, hdrEnd, stdout);

        int chunked = 0;
        for (i = 0; i + 17 <= hdrEnd; i++) {
            if (!strncasecmp((const char *)raw + i, "Transfer-Encoding:", 18)) {
                if (strstr((const char *)raw + i, "chunked")) chunked = 1;
                break;
            }
        }
        size_t bodyLen = total - hdrEnd;
        memcpy(body, raw + hdrEnd, bodyLen);
        printf("--- body ---\nchunked=%d rawBody=%zu\n", chunked, bodyLen);

        if (chunked) {
            long d = dechunk(raw + hdrEnd, bodyLen, body, MAXBODY);
            if (d < 0) { printf("dechunk FAILED (framing)\n"); bodyLen = 0; }
            else { bodyLen = (size_t)d; printf("dechunked=%zu\n", bodyLen); }
        }
        body[bodyLen] = 0;

        printf("markers: data-film-name=%zu data-film-slug=%zu href=/film/=%zu <img=%zu resized=%zu\n",
               count_occurrences(body, bodyLen, "data-film-name"),
               count_occurrences(body, bodyLen, "data-film-slug"),
               count_occurrences(body, bodyLen, "href=\"/film/"),
               count_occurrences(body, bodyLen, "<img"),
               count_occurrences(body, bodyLen, "/resized/"));

        char head[200];
        size_t hn = bodyLen < 199 ? bodyLen : 199;
        memcpy(head, body, hn); head[hn] = 0;
        for (size_t k = 0; k < hn; k++) if (head[k] == '\n' || head[k] == '\r') head[k] = ' ';
        printf("body[0:199]: %s\n", head);
    }

out:
    mbedtls_ssl_close_notify(&ssl);
    mbedtls_net_free(&server_fd);
    mbedtls_x509_crt_free(&cacert);
    mbedtls_ssl_free(&ssl);
    mbedtls_ssl_config_free(&conf);
    mbedtls_ctr_drbg_free(&ctr_drbg);
    mbedtls_entropy_free(&entropy);
    return 0;
}
MT_FILE_EOF_19

echo
echo "Done. Files written:"
find MatineeUI tlsprobe -type f | sort
echo
echo "Next: add QuartzCore to Matinee_FRAMEWORKS, then build."
