//
//  MTHomeViewController.h
//  Matinee
//
//  Letterboxd-style home screen: segmented Films/Reviews/Lists/Journal header,
//  poster rails ("Popular this week", "New from friends", "Popular with friends")
//  and a friend-review list. Same controller drives iPhone and iPad.
//

#import <UIKit/UIKit.h>

@interface MTHomeViewController : UIViewController

// Array of MTFeedSection. Setting it rebuilds the screen.
@property (nonatomic, retain) NSArray *sections;

- (id)initWithSections:(NSArray *)sections;

// Rebuild from the current `sections`.
- (void)reload;

@end
