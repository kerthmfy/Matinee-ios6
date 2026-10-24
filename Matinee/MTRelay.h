//
//  MTRelay.h
//  Matinee
//
//  The only object that talks to the Matinee relay. The phone never opens a
//  connection to letterboxd.com; the relay owns every upstream request.
//

#import <Foundation/Foundation.h>
#import "MTModels.h"

typedef void (^MTRelayCompletion)(id json, NSError *error);

@interface MTRelay : NSObject

+ (instancetype)sharedRelay;

// Resolve a relay-relative path (for example "/img?u=...") against the base
// URL currently set in MTStore.
+ (NSURL *)URLForPath:(NSString *)path;

- (void)health:(MTRelayCompletion)completion;
- (void)feedForHandle:(NSString *)handle completion:(MTRelayCompletion)completion;
- (void)filmWithSlug:(NSString *)slug completion:(MTRelayCompletion)completion;
- (void)searchForQuery:(NSString *)query completion:(MTRelayCompletion)completion;
- (void)connectInput:(NSString *)input completion:(MTRelayCompletion)completion;
- (void)logDraft:(MTDraft *)draft completion:(MTRelayCompletion)completion;

@end
