//
//  MTPosterStripView.h
//  Matinee
//
//  Horizontally scrolling row of film posters, exactly like Letterboxd's
//  "Popular this week" / "New from friends" rails.
//

#import <UIKit/UIKit.h>

@interface MTPosterStripView : UIView

// Total height for a strip at the given width (poster + optional byline).
+ (CGFloat)heightForWidth:(CGFloat)width showsByline:(BOOL)showsByline;

- (void)setItems:(NSArray *)items showsByline:(BOOL)showsByline;

// Call from the owner's layout pass, after the view's frame is set.
- (void)layoutForWidth:(CGFloat)width;

@end
