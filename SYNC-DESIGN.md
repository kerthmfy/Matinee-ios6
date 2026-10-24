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
