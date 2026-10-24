//
//  MTSecureClient.h
//  Matinee
//

#import <Foundation/Foundation.h>

@interface MTSecureClient : NSObject

+ (void)sendRequestToHost:(NSString *)host
                     path:(NSString *)path
               completion:(void(^)(NSData *data, NSError *error))completion;

+ (NSString *)lastDebugPayload;

@end