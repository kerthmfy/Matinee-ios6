//
//  MTModels.h
//  Matinee
//
//  Plain data. No UIKit views, no networking. Everything here is built from
//  the relay's JSON, which is in turn built from Letterboxd's RSS and JSON-LD.
//

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

@interface MTEntry : NSObject

@property (nonatomic, copy) NSString *entryId;
@property (nonatomic, copy) NSString *kind;        // "diary" or "list"
@property (nonatomic, copy) NSString *title;
@property (nonatomic, assign) NSInteger year;
@property (nonatomic, copy) NSString *slug;
@property (nonatomic, copy) NSString *link;
@property (nonatomic, copy) NSString *watchedDate; // yyyy-MM-dd
@property (nonatomic, copy) NSString *published;
@property (nonatomic, copy) NSString *review;
@property (nonatomic, copy) NSString *tmdbId;
@property (nonatomic, copy) NSString *posterCdn;   // direct CDN, used by the mock
@property (nonatomic, copy) NSString *poster;      // relative /img?u= proxy path
@property (nonatomic, strong) NSNumber *rating;    // 0.5 .. 5.0, nil when unrated
@property (nonatomic, assign) BOOL liked;
@property (nonatomic, assign) BOOL rewatch;

// Lists only:
@property (nonatomic, strong) NSArray *entries;    // NSArray of MTEntry
@property (nonatomic, assign) NSInteger total;

+ (instancetype)entryWithDictionary:(NSDictionary *)dict;
- (NSString *)yearText;
- (NSString *)ratingText;

@end


@interface MTFilm : NSObject

@property (nonatomic, copy) NSString *slug;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, assign) NSInteger year;
@property (nonatomic, assign) NSInteger runtime;
@property (nonatomic, assign) CGFloat rating;
@property (nonatomic, assign) NSInteger ratingCount;
@property (nonatomic, copy) NSString *synopsis;
@property (nonatomic, copy) NSString *posterCdn;
@property (nonatomic, copy) NSString *poster;
@property (nonatomic, copy) NSString *uid;         // film:123
@property (nonatomic, copy) NSString *csrf;
@property (nonatomic, assign) BOOL loggable;
@property (nonatomic, assign) BOOL signedIn;
@property (nonatomic, strong) NSArray *directors;
@property (nonatomic, strong) NSArray *cast;
@property (nonatomic, strong) NSArray *genres;

+ (instancetype)filmWithDictionary:(NSDictionary *)dict;
- (NSString *)runtimeText;
- (NSString *)directorsText;

@end


@interface MTDraft : NSObject

@property (nonatomic, copy) NSString *slug;
@property (nonatomic, copy) NSString *tmdbId;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, assign) NSInteger year;
@property (nonatomic, copy) NSString *posterCdn;
@property (nonatomic, copy) NSString *poster;
@property (nonatomic, strong) NSNumber *rating;    // stars, not the 0-10 form value
@property (nonatomic, copy) NSString *watchedDate; // yyyy-MM-dd
@property (nonatomic, copy) NSString *review;
@property (nonatomic, copy) NSString *directors;
@property (nonatomic, copy) NSString *tags;
@property (nonatomic, assign) BOOL rewatch;
@property (nonatomic, assign) BOOL liked;

+ (instancetype)draftWithEntry:(MTEntry *)entry film:(MTFilm *)film;
+ (instancetype)draftWithDictionary:(NSDictionary *)dict;
- (NSDictionary *)dictionary;
- (NSString *)csvRow;

@end
