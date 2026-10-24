//
//  MTEntry.m
//  Matinee
//

#import "MTEntry.h"

@implementation MTEntry

+ (instancetype)entryWithDictionary:(NSDictionary *)dict
{
    if (![dict isKindOfClass:[NSDictionary class]]) return nil;
    
    MTEntry *entry = [[MTEntry alloc] init];
    entry.title = dict[@"title"];
    entry.year = [dict[@"year"] integerValue];
    entry.tmdbId = [dict[@"tmdbId"] description];
    entry.slug = dict[@"slug"];
    entry.posterCdn = dict[@"posterCdn"];
    entry.poster = dict[@"poster"];
    return entry;
}

@end