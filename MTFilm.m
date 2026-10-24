#import "MTModels.h"

#define MTString(obj) ([obj isKindOfClass:[NSString class]] ? (NSString *)obj : nil)
#define MTNumber(obj) ([obj isKindOfClass:[NSNumber class]] ? (NSNumber *)obj : nil)
#define MTArray(obj)  ([obj isKindOfClass:[NSArray class]] ? (NSArray *)obj : nil)
#define MTDict(obj)   ([obj isKindOfClass:[NSDictionary class]] ? (NSDictionary *)obj : nil)


@implementation MTFilm

+ (instancetype)filmWithDictionary:(NSDictionary *)dict
{
    if (![dict isKindOfClass:[NSDictionary class]]) return nil;

    MTFilm *film = [[MTFilm alloc] init];
    film.slug = MTString(dict[@"slug"]);
    film.title = MTString(dict[@"title"]);
    film.year = [MTNumber(dict[@"year"]) integerValue];
    film.runtime = [MTNumber(dict[@"runtime"]) integerValue];
    film.rating = [MTNumber(dict[@"rating"]) floatValue];
    film.ratingCount = [MTNumber(dict[@"ratingCount"]) integerValue];
    film.synopsis = MTString(dict[@"synopsis"]);
    film.posterCdn = MTString(dict[@"posterCdn"]);
    film.poster = MTString(dict[@"poster"]);
    film.uid = MTString(dict[@"uid"]);
    film.csrf = MTString(dict[@"csrf"]);
    film.loggable = [MTNumber(dict[@"loggable"]) boolValue];
    film.signedIn = [MTNumber(dict[@"signedIn"]) boolValue];
    film.directors = MTArray(dict[@"directors"]) ?: @[];
    film.cast = MTArray(dict[@"cast"]) ?: @[];
    film.genres = MTArray(dict[@"genres"]) ?: @[];
    return film;
}

- (NSString *)runtimeText
{
    return self.runtime > 0 ? [NSString stringWithFormat:@"%ld min", (long)self.runtime] : @"";
}

- (NSString *)directorsText
{
    if (!self.directors.count) return @"";
    return [@"Dir. " stringByAppendingString:[self.directors componentsJoinedByString:@", "]];
}

@end
