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
