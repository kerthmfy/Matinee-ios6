//
//  MTEntry.h
//  Matinee
//

#import <Foundation/Foundation.h>

@interface MTEntry : NSObject

@property (nonatomic, strong) NSString *kind;
@property (nonatomic, strong) NSString *title;
@property (nonatomic, assign) NSInteger year;
@property (nonatomic, strong) NSString *tmdbId;
@property (nonatomic, strong) NSString *slug;
@property (nonatomic, strong) NSString *posterCdn;
@property (nonatomic, strong) NSString *poster;

+ (instancetype)entryWithDictionary:(NSDictionary *)dict;

@end