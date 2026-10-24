//
//  MTFeedService.h
//  Matinee
//
//  Loads the home feed from Letterboxd's public RSS endpoints.
//
//  Why RSS: as of 2026-10, every HTML route on letterboxd.com is either a
//  Cloudflare JS challenge (403) or a JavaScript shell with an empty results
//  container. The per-user RSS feeds are NOT challenged and return real data:
//
//      https://letterboxd.com/<username>/rss/   -> 100 items, RSS 2.0
//
//  Each item carries letterboxd:filmTitle, letterboxd:filmYear,
//  letterboxd:memberRating, dc:creator and a description containing the
//  poster <img src="https://a.ltrbxd.com/resized/...-0-600-0-900-crop.jpg">.
//

#import <UIKit/UIKit.h>

typedef void (^MTFeedCompletionBlock)(NSArray *sections, NSError *error);

@interface MTFeedService : NSObject

// Letterboxd usernames whose /rss/ feed is merged into the home screen.
// Defaults to a few real public accounts so the screen works out of the box;
// replace with the signed-in user's actual friends.
@property (nonatomic, retain) NSArray *friendUsernames;

+ (MTFeedService *)sharedService;

// Fetches every friend feed, parses, merges, and returns NSArray of
// MTFeedSection on the main queue. On total failure, sections is nil and
// error describes the first failure.
- (void)loadFeedWithCompletion:(MTFeedCompletionBlock)completion;

@end
