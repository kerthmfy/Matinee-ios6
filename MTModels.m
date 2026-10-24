//
//  MTModels.m
//  Matinee
//

#import "MTModels.h"
#import <math.h>

static NSString *MTString(id value)
{
    return [value isKindOfClass:[NSString class]] ? value : nil;
}

static NSNumber *MTNumber(id value)
{
    return [value isKindOfClass:[NSNumber class]] ? value : nil;
}

static NSArray *MTArray(id value)
{
    return [value isKindOfClass:[NSArray class]] ? value : nil;
}

static NSString *MTISODateString(NSDate *date)
{
    static NSDateFormatter *formatter = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        formatter = [[NSDateFormatter alloc] init];
        [formatter setDateFormat:@"yyyy-MM-dd"];
        [formatter setLocale:[[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"]];
    });
    return [formatter stringFromDate:date];
}

static NSString *MTCSVField(NSString *value)
{
    if (!value) return @"";
    NSCharacterSet *special = [NSCharacterSet characterSetWithCharactersInString:@",\"\r\n"];
    if ([value rangeOfCharacterFromSet:special].location == NSNotFound) return value;
    NSString *escaped = [value stringByReplacingOccurrencesOfString:@"\"" withString:@"\"\""];
    return [NSString stringWithFormat:@"\"%@\"", escaped];
}

@implementation MTEntry

+ (instancetype)entryWithDictionary:(NSDictionary *)dict
{
    if (![dict isKindOfClass:[NSDictionary class]]) return nil;

    MTEntry *entry = [[MTEntry alloc] init];
    entry.entryId = MTString(dict[@"id"]);
    entry.kind = MTString(dict[@"kind"]);
    entry.title = MTString(dict[@"title"]);
    entry.year = [MTNumber(dict[@"year"]) integerValue];
    entry.slug = MTString(dict[@"slug"]);
    entry.link = MTString(dict[@"link"]);
    entry.watchedDate = MTString(dict[@"watchedDate"]);
    entry.published = MTString(dict[@"published"]);
    entry.review = MTString(dict[@"review"]);
    entry.tmdbId = MTString(dict[@"tmdbId"]);
    entry.posterCdn = MTString(dict[@"posterCdn"]);
    entry.poster = MTString(dict[@"poster"]);
    entry.rating = MTNumber(dict[@"rating"]);
    entry.liked = [MTNumber(dict[@"liked"]) boolValue];
    entry.rewatch = [MTNumber(dict[@"rewatch"]) boolValue];
    entry.total = [MTNumber(dict[@"total"]) integerValue];

    NSArray *rawEntries = MTArray(dict[@"entries"]);
    if (rawEntries) {
        NSMutableArray *parsed = [NSMutableArray arrayWithCapacity:rawEntries.count];
        for (NSDictionary *raw in rawEntries) {
            MTEntry *child = [MTEntry entryWithDictionary:raw];
            if (child) [parsed addObject:child];
        }
        entry.entries = parsed;
    }
    return entry;
}

- (NSString *)yearText
{
    return self.year > 0 ? [NSString stringWithFormat:@"%ld", (long)self.year] : @"";
}

- (NSString *)ratingText
{
    return self.rating ? [NSString stringWithFormat:@"%.1f", self.rating.doubleValue] : @"";
}

@end


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


@implementation MTDraft

+ (instancetype)draftWithEntry:(MTEntry *)entry film:(MTFilm *)film
{
    MTDraft *draft = [[MTDraft alloc] init];
    draft.slug = entry.slug;
    draft.tmdbId = entry.tmdbId;
    draft.title = film.title.length ? film.title : entry.title;
    draft.year = film.year > 0 ? film.year : entry.year;
    draft.posterCdn = film.posterCdn.length ? film.posterCdn : entry.posterCdn;
    draft.poster = entry.poster;
    draft.rating = entry.rating;
    draft.watchedDate = MTISODateString([NSDate date]);
    draft.review = @"";
    draft.directors = [film.directors componentsJoinedByString:@", "];
    draft.tags = @"";
    draft.rewatch = NO;
    draft.liked = NO;
    return draft;
}

+ (instancetype)draftWithDictionary:(NSDictionary *)dict
{
    if (![dict isKindOfClass:[NSDictionary class]]) return nil;

    MTDraft *draft = [[MTDraft alloc] init];
    draft.slug = MTString(dict[@"slug"]);
    draft.tmdbId = MTString(dict[@"tmdbId"]);
    draft.title = MTString(dict[@"title"]);
    draft.year = [MTNumber(dict[@"year"]) integerValue];
    draft.posterCdn = MTString(dict[@"posterCdn"]);
    draft.poster = MTString(dict[@"poster"]);
    draft.rating = MTNumber(dict[@"rating"]);
    draft.watchedDate = MTString(dict[@"watchedDate"]);
    draft.review = MTString(dict[@"review"]);
    draft.directors = MTString(dict[@"directors"]);
    draft.tags = MTString(dict[@"tags"]);
    draft.rewatch = [MTNumber(dict[@"rewatch"]) boolValue];
    draft.liked = [MTNumber(dict[@"liked"]) boolValue];
    return draft;
}

- (NSDictionary *)dictionary
{
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    if (self.slug) dict[@"slug"] = self.slug;
    if (self.tmdbId) dict[@"tmdbId"] = self.tmdbId;
    if (self.title) dict[@"title"] = self.title;
    dict[@"year"] = @(self.year);
    if (self.posterCdn) dict[@"posterCdn"] = self.posterCdn;
    if (self.poster) dict[@"poster"] = self.poster;
    if (self.rating) dict[@"rating"] = self.rating;
    if (self.watchedDate) dict[@"watchedDate"] = self.watchedDate;
    if (self.review) dict[@"review"] = self.review;
    if (self.directors) dict[@"directors"] = self.directors;
    if (self.tags) dict[@"tags"] = self.tags;
    dict[@"rewatch"] = @(self.rewatch);
    dict[@"liked"] = @(self.liked);
    return dict;
}

- (NSString *)csvRow
{
    NSString *uri = self.slug.length
        ? [NSString stringWithFormat:@"https://letterboxd.com/film/%@/", self.slug]
        : @"";
    NSString *rating = self.rating ? [NSString stringWithFormat:@"%.1f", self.rating.doubleValue] : @"";
    NSString *rating10 = self.rating ? [NSString stringWithFormat:@"%ld", (long)lround(self.rating.doubleValue * 2.0)] : @"";    NSString *year = self.year > 0 ? [NSString stringWithFormat:@"%ld", (long)self.year] : @"";

    NSArray *fields = @[
        uri,
        self.tmdbId ?: @"",
        @"",
        self.title ?: @"",
        year,
        self.directors ?: @"",
        rating,
        rating10,
        self.watchedDate ?: @"",
        self.rewatch ? @"Yes" : @"",
        self.tags ?: @"",
        self.review ?: @""
    ];

    NSMutableArray *escaped = [NSMutableArray arrayWithCapacity:fields.count];
    for (NSString *field in fields) {
        [escaped addObject:MTCSVField(field)];
    }
    return [escaped componentsJoinedByString:@","];
}

@end
