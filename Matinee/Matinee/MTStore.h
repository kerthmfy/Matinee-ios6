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

// The outbox: drafts with a status, waiting for the relay to take them.
+ (NSArray *)outboxDrafts;        // NSArray of MTDraft, queued or failed
+ (NSInteger)outboxCount;
+ (void)enqueueDraft:(MTDraft *)draft;   // marks the draft queued and stores it
+ (void)replaceDraftAtIndex:(NSInteger)index withDraft:(MTDraft *)draft;

// Sends queued drafts to the relay one at a time. Safe to call often: it is
// a no-op while a flush is already running or the outbox is empty. On the
// first failure the draft is marked failed and the flush stops.
+ (void)flushOutbox;

@end
