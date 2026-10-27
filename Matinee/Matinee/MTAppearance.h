//
//  MTAppearance.h
//  Matinee
//
//  Colours and chrome shared by every screen. iOS 6 only.
//

#import <UIKit/UIKit.h>

typedef NS_ENUM(NSInteger, MTTabIcon) {
    MTTabIconDiary = 0,
    MTTabIconLists = 1,
    MTTabIconSearch = 2,
    MTTabIconProfile = 3
};

// The bordered white card used by the diary, lists, and search tables. It
// draws the 8pt side margin, 1px border, and row separator that the mock uses.
@interface MTCardBackgroundView : UIView
@property (nonatomic, assign) BOOL first;
@property (nonatomic, assign) BOOL last;
@end

// Pinstripe strip with an uppercase section title (for example "50 ENTRIES").
@interface MTSectionHeadView : UIView
@property (nonatomic, strong) UILabel *titleLabel;
- (id)initWithTitle:(NSString *)title;
@end

@interface MTAppearance : NSObject

+ (UIColor *)green;          // star fill, #00c853
+ (UIColor *)starEmpty;      // #d0d4da
+ (UIColor *)paper;          // grouped-table background
+ (UIColor *)groupBackground;// pinstripe base, #c8ccd2
+ (UIColor *)sep;            // 1px separators
+ (UIColor *)ink;            // primary text
+ (UIColor *)muted;          // secondary text
+ (UIColor *)placeholder;    // poster backing before the image arrives
+ (UIColor *)link;           // tappable blue

+ (UIFont *)titleFont;
+ (UIFont *)bodyFont;
+ (UIFont *)smallFont;
+ (UIFont *)groupTitleFont;

+ (UIImage *)navigationBarImage;
+ (UIImage *)tabBarImage;
+ (UIImage *)pinstripeImage;
+ (UIImage *)tabSelectionImage;
+ (UIImage *)tabIconForTab:(MTTabIcon)tab selected:(BOOL)selected;
+ (UIImage *)actionButtonImage;
+ (UIImage *)dangerButtonImage;
+ (void)styleNavigationBar:(UINavigationBar *)bar;
+ (void)styleTabBar:(UITabBar *)tabBar;

// A shaped iOS 6 navigation button. The back variant has the pointed left cap
// used by the film screen; the normal variant is the rounded "Log" cap.
+ (UIButton *)barButtonWithTitle:(NSString *)title
                            back:(BOOL)back
                          target:(id)target
                          action:(SEL)action;

@end
