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
