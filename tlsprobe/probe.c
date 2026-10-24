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
