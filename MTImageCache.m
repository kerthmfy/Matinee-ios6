//
//  MTImageCache.m
//  Matinee
//

#import "MTImageCache.h"
#import <QuartzCore/QuartzCore.h>

@interface MTImageCache ()
@property (nonatomic, strong) NSCache *cache;
@property (nonatomic, strong) NSOperationQueue *queue;
@end

@implementation MTImageCache

+ (instancetype)sharedCache
{
    static MTImageCache *cache = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        cache = [[MTImageCache alloc] init];
    });
    return cache;
}

- (id)init
{
    self = [super init];
    if (self) {
        _cache = [[NSCache alloc] init];
        _cache.countLimit = 300;
        _queue = [[NSOperationQueue alloc] init];
        _queue.maxConcurrentOperationCount = 4;
    }
    return self;
}

- (void)imageForURL:(NSURL *)url completion:(void (^)(UIImage *image))completion
{
    if (!url || !completion) return;

    UIImage *cached = [self.cache objectForKey:url.absoluteString];
    if (cached) {
        completion(cached);
        return;
    }

    NSURLRequest *request = [NSURLRequest requestWithURL:url
                                             cachePolicy:NSURLRequestReturnCacheDataElseLoad
                                         timeoutInterval:20.0];
    [[MTImageCache sharedCache].queue addOperationWithBlock:^{
        NSURLResponse *response = nil;
        NSError *error = nil;
        NSData *data = [NSURLConnection sendSynchronousRequest:request
                                             returningResponse:&response
                                                         error:&error];
        UIImage *image = data.length ? [UIImage imageWithData:data] : nil;
        if (image) {
            [self.cache setObject:image forKey:url.absoluteString];
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(image);
        });
    }];
}

@end


@implementation MTPosterImageView

@synthesize remoteURL = _remoteURL;

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor colorWithRed:0.906 green:0.914 blue:0.929 alpha:1.0];
        self.contentMode = UIViewContentModeScaleAspectFill;
        self.clipsToBounds = YES;
        self.layer.cornerRadius = 2.0;
        self.opaque = YES;
    }
    return self;
}

- (void)setRemoteURL:(NSURL *)url
{
    if (_remoteURL == url || [_remoteURL isEqual:url]) {
        if (self.image) return;
    }
    _remoteURL = url;
    self.image = nil;

    if (!url) return;

    __block MTPosterImageView *weakSelf = self;
    [[MTImageCache sharedCache] imageForURL:url completion:^(UIImage *image) {
        MTPosterImageView *strongSelf = weakSelf;
        if (!strongSelf || !image) return;
        if ([strongSelf.remoteURL isEqual:url]) {
            strongSelf.image = image;
        }
    }];
}

@end
