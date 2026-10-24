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
