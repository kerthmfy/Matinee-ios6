//
//  MTRelay.m
//  Matinee
//

#import "MTRelay.h"
#import "MTStore.h"

static NSError *MTRelayError(NSInteger code, NSString *message)
{
    NSString *text = message.length ? message : @"The relay could not be reached.";
    return [NSError errorWithDomain:@"MTRelay" code:code
                           userInfo:@{NSLocalizedDescriptionKey: text}];
}

@implementation MTRelay

+ (instancetype)sharedRelay
{
    static MTRelay *relay = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        relay = [[MTRelay alloc] init];
    });
    return relay;
}

+ (NSURL *)URLForPath:(NSString *)path
{
    if (!path.length) return nil;
    if ([path hasPrefix:@"http://"] || [path hasPrefix:@"https://"]) {
        return [NSURL URLWithString:path];
    }
    NSString *base = [MTStore relayBase];
    if (![path hasPrefix:@"/"]) path = [@"/" stringByAppendingString:path];
    return [NSURL URLWithString:[base stringByAppendingString:path]];
}

- (void)sendRequest:(NSURLRequest *)request completion:(MTRelayCompletion)completion
{
    [NSURLConnection sendAsynchronousRequest:request
                                       queue:[NSOperationQueue mainQueue]
                           completionHandler:^(NSURLResponse *response, NSData *data, NSError *connectionError) {
        if (connectionError) {
            if (completion) completion(nil, connectionError);
            return;
        }

        NSInteger status = 200;
        if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
            status = [(NSHTTPURLResponse *)response statusCode];
        }

        id json = nil;
        if (data.length) {
            NSError *parseError = nil;
            json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&parseError];
            if (!json && parseError) {
                if (completion) completion(nil, parseError);
                return;
            }
        }

        if (status >= 400) {
            NSString *detail = nil;
            if ([json isKindOfClass:[NSDictionary class]]) {
                detail = json[@"detail"] ?: json[@"reason"];
            }
            if (![detail isKindOfClass:[NSString class]]) {
                detail = [NSString stringWithFormat:@"Relay returned HTTP %ld.", (long)status];
            }
            if (completion) completion(nil, MTRelayError(status, detail));
            return;
        }

        if (completion) completion(json, nil);
    }];
}

- (void)getPath:(NSString *)path completion:(MTRelayCompletion)completion
{
    NSURL *url = [MTRelay URLForPath:path];
    if (!url) {
        if (completion) completion(nil, MTRelayError(0, @"The relay address is not valid."));
        return;
    }
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url
                                                           cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                                                       timeoutInterval:20.0];
    [request setHTTPMethod:@"GET"];
    [self sendRequest:request completion:completion];
}

- (void)postPath:(NSString *)path body:(NSDictionary *)body completion:(MTRelayCompletion)completion
{
    NSURL *url = [MTRelay URLForPath:path];
    if (!url) {
        if (completion) completion(nil, MTRelayError(0, @"The relay address is not valid."));
        return;
    }

    NSError *encodeError = nil;
    NSData *data = [NSJSONSerialization dataWithJSONObject:body options:0 error:&encodeError];
    if (!data) {
        if (completion) completion(nil, encodeError);
        return;
    }

    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url
                                                           cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                                                       timeoutInterval:20.0];
    [request setHTTPMethod:@"POST"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setHTTPBody:data];
    [self sendRequest:request completion:completion];
}

- (void)health:(MTRelayCompletion)completion
{
    [self getPath:@"/api/health" completion:completion];
}

- (void)feedForHandle:(NSString *)handle completion:(MTRelayCompletion)completion
{
    NSString *path = @"/api/feed";
    if (handle.length) {
        NSString *encoded = [handle stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
        path = [path stringByAppendingFormat:@"?user=%@", encoded];
    }
    [self getPath:path completion:completion];
}

- (void)filmWithSlug:(NSString *)slug completion:(MTRelayCompletion)completion
{
    if (!slug.length) {
        if (completion) completion(nil, MTRelayError(0, @"Missing film slug."));
        return;
    }
    NSString *encoded = [slug stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    [self getPath:[@"/api/film?slug=" stringByAppendingString:encoded] completion:completion];
}

- (void)searchForQuery:(NSString *)query completion:(MTRelayCompletion)completion
{
    NSString *trimmed = [query stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (!trimmed.length) {
        if (completion) completion(@{@"ok": @YES, @"results": @[]}, nil);
        return;
    }
    NSString *encoded = [trimmed stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    [self getPath:[@"/api/search?q=" stringByAppendingString:encoded] completion:completion];
}

- (void)connectInput:(NSString *)input completion:(MTRelayCompletion)completion
{
    [self postPath:@"/api/connect" body:@{@"input": input ?: @""} completion:completion];
}

- (void)logDraft:(MTDraft *)draft completion:(MTRelayCompletion)completion
{
    if (!draft.slug.length) {
        if (completion) completion(nil, MTRelayError(0, @"This film has no Letterboxd slug; export it as CSV instead."));
        return;
    }

    NSMutableDictionary *body = [NSMutableDictionary dictionary];
    body[@"slug"] = draft.slug;
    body[@"watchedDate"] = draft.watchedDate ?: @"";
    body[@"review"] = draft.review ?: @"";
    body[@"rewatch"] = @(draft.rewatch);
    body[@"liked"] = @(draft.liked);
    body[@"tags"] = draft.tags ?: @"";
    if (draft.rating) body[@"rating"] = draft.rating;

    [self postPath:@"/api/log" body:body completion:completion];
}

@end
