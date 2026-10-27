//
//  MTImageCache.h
//  Matinee
//
//  Poster loading. The phone asks the relay's /img endpoint, which owns the
//  CDN allowlist and the byte cache; this class only keeps decoded images.
//

#import <UIKit/UIKit.h>

@interface MTImageCache : NSObject

+ (instancetype)sharedCache;
- (void)imageForURL:(NSURL *)url completion:(void (^)(UIImage *image))completion;

@end


// An image view that ignores late completions after it has been reused.
@interface MTPosterImageView : UIImageView

@property (nonatomic, strong) NSURL *remoteURL;
- (void)setRemoteURL:(NSURL *)url;

@end
