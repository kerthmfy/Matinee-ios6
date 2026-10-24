//
//  MTDraft.h
//  Matinee
//

#import <Foundation/Foundation.h>

@interface MTDraft : NSObject

@property (nonatomic, strong) NSString *filmSlug;
@property (nonatomic, strong) NSString *reviewText;
@property (nonatomic, assign) NSInteger rating; // e.g. 1-10 or stars
@property (nonatomic, assign) BOOL rewatch;
@property (nonatomic, strong) NSDate *date;

+ (instancetype)draftWithDictionary:(NSDictionary *)dict;
- (NSDictionary *)dictionary;

@end