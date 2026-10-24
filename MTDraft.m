//
//  MTDraft.m
//  Matinee
//

#import "MTDraft.h"

@implementation MTDraft

+ (instancetype)draftWithDictionary:(NSDictionary *)dict
{
    if (![dict isKindOfClass:[NSDictionary class]]) return nil;
    
    MTDraft *draft = [[MTDraft alloc] init];
    draft.filmSlug = dict[@"filmSlug"];
    draft.reviewText = dict[@"reviewText"];
    draft.rating = [dict[@"rating"] integerValue];
    draft.rewatch = [dict[@"rewatch"] boolValue];
    
    NSTimeInterval timestamp = [dict[@"timestamp"] doubleValue];
    if (timestamp > 0) {
        draft.date = [NSDate dateWithTimeIntervalSince1970:timestamp];
    } else {
        draft.date = [NSDate date];
    }
    
    return draft;
}

- (NSDictionary *)dictionary
{
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    if (self.filmSlug) dict[@"filmSlug"] = self.filmSlug;
    if (self.reviewText) dict[@"reviewText"] = self.reviewText;
    dict[@"rating"] = @(self.rating);
    dict[@"rewatch"] = @(self.rewatch);
    if (self.date) dict[@"timestamp"] = @([self.date timeIntervalSince1970]);
    return [dict copy];
}

@end