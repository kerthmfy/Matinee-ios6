//
//  MTSecureClient.m
//  Matinee
//

#import "MTSecureClient.h"
#import <UIKit/UIKit.h>
#include "mbedtls/net_sockets.h"
#include "mbedtls/ssl.h"
#include "mbedtls/entropy.h"
#include "mbedtls/ctr_drbg.h"
#include "mbedtls/error.h"

static NSString *__lastDebugPayload = nil;

@implementation MTSecureClient

+ (NSString *)lastDebugPayload {
    return __lastDebugPayload;
}

+ (void)sendRequestToHost:(NSString *)host
                     path:(NSString *)path
               completion:(void(^)(NSData *data, NSError *error))completion
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        int ret = 0;
        
        mbedtls_net_context server_fd;
        mbedtls_ssl_context ssl;
        mbedtls_ssl_config conf;
        mbedtls_entropy_context entropy;
        mbedtls_ctr_drbg_context ctr_drbg;

        mbedtls_net_init(&server_fd);
        mbedtls_ssl_init(&ssl);
        mbedtls_ssl_config_init(&conf);
        mbedtls_entropy_init(&entropy);
        mbedtls_ctr_drbg_init(&ctr_drbg);

        #define MATINEE_CLEANUP() \
            mbedtls_ssl_free(&ssl); \
            mbedtls_ssl_config_free(&conf); \
            mbedtls_ctr_drbg_free(&ctr_drbg); \
            mbedtls_entropy_free(&entropy); \
            mbedtls_net_free(&server_fd)

        // 1. Seed the random number generator
        const char *pers = "matinee_client";
        ret = mbedtls_ctr_drbg_seed(&ctr_drbg, mbedtls_entropy_func, &entropy,
                                    (const unsigned char *)pers, strlen(pers));
        if (ret != 0) {
            NSError *err = [NSError errorWithDomain:@"MTSecureError" code:ret userInfo:@{NSLocalizedDescriptionKey: @"Failed to seed RNG"}];
            if (completion) dispatch_async(dispatch_get_main_queue(), ^{ completion(nil, err); });
            MATINEE_CLEANUP();
            return;
        }

        // 2. Connect via TCP socket to port 443
        const char *hostStr = [host UTF8String];
        ret = mbedtls_net_connect(&server_fd, hostStr, "443", MBEDTLS_NET_PROTO_TCP);
        if (ret != 0) {
            NSError *err = [NSError errorWithDomain:@"MTSecureError" code:ret userInfo:@{NSLocalizedDescriptionKey: @"TCP connection failed"}];
            if (completion) dispatch_async(dispatch_get_main_queue(), ^{ completion(nil, err); });
            MATINEE_CLEANUP();
            return;
        }

        // 3. Setup SSL configuration
        ret = mbedtls_ssl_config_defaults(&conf,
                                          MBEDTLS_SSL_IS_CLIENT,
                                          MBEDTLS_SSL_TRANSPORT_STREAM,
                                          MBEDTLS_SSL_PRESET_DEFAULT);
        
        mbedtls_ssl_conf_authmode(&conf, MBEDTLS_SSL_VERIFY_NONE);
        mbedtls_ssl_conf_rng(&conf, mbedtls_ctr_drbg_random, &ctr_drbg);

        ret = mbedtls_ssl_setup(&ssl, &conf);
        mbedtls_ssl_set_hostname(&ssl, hostStr);
        mbedtls_ssl_set_bio(&ssl, &server_fd, mbedtls_net_send, mbedtls_net_recv, NULL);

        // 4. Perform TLS Handshake
        while ((ret = mbedtls_ssl_handshake(&ssl)) != 0) {
            if (ret != MBEDTLS_ERR_SSL_WANT_READ && ret != MBEDTLS_ERR_SSL_WANT_WRITE) {
                NSError *err = [NSError errorWithDomain:@"MTSecureError" code:ret userInfo:@{NSLocalizedDescriptionKey: @"TLS Handshake failed"}];
                if (completion) dispatch_async(dispatch_get_main_queue(), ^{ completion(nil, err); });
                MATINEE_CLEANUP();
                return;
            }
        }

        // 5. Send HTTP Request with AJAX/JSON headers
        NSString *requestStr = [NSString stringWithFormat:
            @"GET %@ HTTP/1.1\r\n"
            @"Host: %@\r\n"
            @"User-Agent: Mozilla/5.0 (iPhone; CPU iPhone OS 16_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.5 Mobile/15E148 Safari/604.1\r\n"
            @"Accept: application/json, text/javascript, */*; q=0.01\r\n"
            @"X-Requested-With: XMLHttpRequest\r\n"
            @"Connection: close\r\n\r\n", path, host];

        const unsigned char *get_req = (const unsigned char *)[requestStr UTF8String];
        size_t written = 0;
        size_t len = strlen((const char *)get_req);

        while (written < len) {
            ret = mbedtls_ssl_write(&ssl, get_req + written, len - written);
            if (ret <= 0) break;
            written += ret;
        }

        // 6. Read Response Data
        NSMutableData *responseData = [NSMutableData data];
        unsigned char buf[1024];
        memset(buf, 0, sizeof(buf));

        while (true) {
            int len_read = mbedtls_ssl_read(&ssl, buf, sizeof(buf) - 1);
            if (len_read == MBEDTLS_ERR_SSL_PEER_CLOSE_NOTIFY) break;
            if (len_read < 0) break;
            if (len_read == 0) break;
            [responseData appendBytes:buf length:len_read];
        }

        // 7. Strip HTTP headers and capture clean body for debugging
        NSData *finalBodyData = responseData;
        const char *rawBytes = (const char *)[responseData bytes];
        const char *headerSplit = strstr(rawBytes, "\r\n\r\n");
        
        if (headerSplit) {
            NSUInteger headerLength = (headerSplit - rawBytes) + 4;
            finalBodyData = [responseData subdataWithRange:NSMakeRange(headerLength, responseData.length - headerLength)];
        }
        
        __lastDebugPayload = [[NSString alloc] initWithData:finalBodyData encoding:NSUTF8StringEncoding];

        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) {
                completion(finalBodyData, nil);
            }
        });

        MATINEE_CLEANUP();
    });
}

@end