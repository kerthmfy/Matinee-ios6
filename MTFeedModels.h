//
//  MTFeedModels.h
//  Matinee
//
//  Lightweight feed model for the Letterboxd-style home screen.
//  Deliberately independent of MTEntry so this screen can be dropped in and
//  populated from any source (existing parser, JSON API, local cache).
//

#import <UIKit/UIKit.h>

@interface MTFeedItem : NSObject
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *yearText;
@property (nonatomic, copy) NSString *slug;
// Either a full https URL or the fragment after "/resized/"
// (e.g. "film-poster/2/6/8/2/2682-primer-0-600-0-900-crop.jpg").
@property (nonatomic, copy) NSString *posterPath;
@property (nonatomic, copy) NSString *reviewerName;
@property (nonatomic, copy) NSString *avatarPath;   // same fragment rules
@property (nonatomic, assign) CGFloat rating;       // 0 = unrated, up to 5.0
@property (nonatomic, copy) NSString *reviewSnippet;
@property (nonatomic, assign) NSTimeInterval timestamp; // feed order; 0 if unknown
+ (id)itemWithTitle:(NSString *)title
               year:(NSString *)year
             poster:(NSString *)poster;
@end

@interface MTFeedSection : NSObject
@property (nonatomic, copy) NSString *title;
@property (nonatomic, retain) NSArray *items;
@property (nonatomic, assign) BOOL showsByline;
+ (id)sectionWithTitle:(NSString *)title
                 items:(NSArray *)items
            showsByline:(BOOL)showsByline;
@end

// "★★★★☆" for 4.0, rounded to the nearest whole star.
NSString *MTStarsString(CGFloat rating);

// Prefixes a /resized/ fragment; passes full URLs through untouched.
NSString *MTPosterURLString(NSString *path);

// Async image fetch with an NSCache. Safe to call repeatedly during reuse.
// Returns immediately; the view's image is set on the main queue.
void MTLoadImage(NSString *URLString, UIImageView *imageView);
