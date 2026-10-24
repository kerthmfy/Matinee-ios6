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
