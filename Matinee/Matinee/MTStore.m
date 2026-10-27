//
//  MTStore.m
//  Matinee
//

#import "MTStore.h"

NSString * const MTDraftsDidChangeNotification = @"MTDraftsDidChangeNotification";
NSString * const MTFeedShouldReloadNotification = @"MTFeedShouldReloadNotification";

static NSString * const MTDraftsKey = @"matinee.drafts";
static NSString * const MTHandleKey = @"matinee.handle";
static NSString * const MTRelayKey  = @"matinee.relay";

@interface MTStore (Private)
+ (void)saveDrafts:(NSArray *)drafts;
@end

@implementation MTStore

+ (void)registerDefaults
{
    NSDictionary *defaults = @{
        MTRelayKey: @"http://192.168.1.50:3000",
        MTHandleKey: @""
    };
    [[NSUserDefaults standardUserDefaults] registerDefaults:defaults];
}

+ (NSString *)relayBase
{
    NSString *base = [[NSUserDefaults standardUserDefaults] stringForKey:MTRelayKey];
    base = [base stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    while ([base hasSuffix:@"/"]) {
        base = [base substringToIndex:base.length - 1];
    }
    return base.length ? base : @"http://192.168.1.50:3000";
}

+ (void)setRelayBase:(NSString *)base
{
    NSString *clean = [base stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (!clean.length) return;
    [[NSUserDefaults standardUserDefaults] setObject:clean forKey:MTRelayKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

+ (NSString *)handle
{
    NSString *handle = [[NSUserDefaults standardUserDefaults] stringForKey:MTHandleKey];
    handle = [handle stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    return handle.length ? handle : nil;
}

+ (void)setHandle:(NSString *)handle
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if (handle.length) {
        [defaults setObject:handle forKey:MTHandleKey];
    } else {
        [defaults removeObjectForKey:MTHandleKey];
    }
    [defaults synchronize];
}

+ (NSArray *)drafts
{
    NSArray *raw = [[NSUserDefaults standardUserDefaults] arrayForKey:MTDraftsKey];
    NSMutableArray *drafts = [NSMutableArray arrayWithCapacity:raw.count];
    for (NSDictionary *dict in raw) {
        MTDraft *draft = [MTDraft draftWithDictionary:dict];
        if (draft) [drafts addObject:draft];
    }
    return drafts;
}

+ (void)saveDrafts:(NSArray *)drafts
{
    NSMutableArray *raw = [NSMutableArray arrayWithCapacity:drafts.count];
    for (MTDraft *draft in drafts) {
        [raw addObject:[draft dictionary]];
    }
    [[NSUserDefaults standardUserDefaults] setObject:raw forKey:MTDraftsKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
    [[NSNotificationCenter defaultCenter] postNotificationName:MTDraftsDidChangeNotification object:nil];
}

+ (void)addDraft:(MTDraft *)draft
{
    if (!draft) return;
    NSMutableArray *drafts = [[self drafts] mutableCopy];
    [drafts insertObject:draft atIndex:0];
    [self saveDrafts:drafts];
}

+ (void)removeDraftAtIndex:(NSInteger)index
{
    NSMutableArray *drafts = [[self drafts] mutableCopy];
    if (index < 0 || index >= (NSInteger)drafts.count) return;
    [drafts removeObjectAtIndex:(NSUInteger)index];
    [self saveDrafts:drafts];
}

+ (void)clearDrafts
{
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:MTDraftsKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
    [[NSNotificationCenter defaultCenter] postNotificationName:MTDraftsDidChangeNotification object:nil];
}

@end
