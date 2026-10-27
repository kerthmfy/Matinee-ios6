//
//  MTAppearance.h
//  Matinee
//
//  Colours and chrome shared by every screen. iOS 6 only.
//

#import <UIKit/UIKit.h>

@interface MTAppearance : NSObject

+ (UIColor *)green;          // star fill, #00c853
+ (UIColor *)starEmpty;      // #d0d4da
+ (UIColor *)paper;          // grouped-table background
+ (UIColor *)sep;            // 1px separators
+ (UIColor *)ink;            // primary text
+ (UIColor *)muted;          // secondary text
+ (UIColor *)placeholder;    // poster backing before the image arrives
+ (UIColor *)link;           // tappable blue

+ (UIFont *)titleFont;
+ (UIFont *)bodyFont;
+ (UIFont *)smallFont;

+ (UIImage *)navigationBarImage;
+ (UIImage *)tabBarImage;
+ (void)styleNavigationBar:(UINavigationBar *)bar;
+ (void)styleTabBar:(UITabBar *)tabBar;

@end
