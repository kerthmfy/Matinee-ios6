//
//  MTStore.h
//  Matinee
//
//  Preferences and drafts. Everything the phone keeps between launches lives
//  here, in NSUserDefaults. No account credentials are ever stored.
//

#import <Foundation/Foundation.h>
#import "MTModels.h"

extern NSString * const MTDraftsDidChangeNotification;
extern NSString * const MTFeedShouldReloadNotification;

@interface MTStore : NSObject

+ (void)registerDefaults;

+ (NSString *)relayBase;
+ (void)setRelayBase:(NSString *)base;

+ (NSString *)handle;             // nil when not connected
+ (void)setHandle:(NSString *)handle;

+ (NSArray *)drafts;              // NSArray of MTDraft
+ (void)addDraft:(MTDraft *)draft;
+ (void)removeDraftAtIndex:(NSInteger)index;
+ (void)clearDrafts;

@end
