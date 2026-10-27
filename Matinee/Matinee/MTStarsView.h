//
//  MTStarsView.h
//  Matinee
//
//  Letterboxd-green stars. Each star is clipped independently, so the gaps
//  between stars never count toward the filled width.
//

#import <UIKit/UIKit.h>

@interface MTStarsView : UIView

@property (nonatomic, assign) CGFloat rating;   // 0.0 .. 5.0
@property (nonatomic, assign) CGFloat starSize; // default 11

@end


// Tappable five-star control used by the log sheet.
@interface MTRatingControl : UIView

@property (nonatomic, assign) CGFloat rating;
@property (nonatomic, copy) void (^onChange)(CGFloat rating);

@end
