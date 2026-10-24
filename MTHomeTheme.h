//
//  MTHomeTheme.h
//  Matinee
//
//  Letterboxd-style dark palette + metrics for the redrawn home screen.
//  MRC-safe: every function returns a retained-forever cached singleton.
//

#import <UIKit/UIKit.h>

UIColor *MTHomeBackgroundColor(void);   // #14181C
UIColor *MTHomeSurfaceColor(void);      // #1B2228 (poster placeholders)
UIColor *MTHomeSeparatorColor(void);    // #2C3440
UIColor *MTHomeTextColor(void);         // #FFFFFF
UIColor *MTHomeSecondaryTextColor(void); // #99AABB
UIColor *MTHomeGreenColor(void);        // #00E054
UIColor *MTHomeOrangeColor(void);       // #FF8000
UIColor *MTHomeBlueColor(void);         // #40BCF4

BOOL    MTHomeIsPad(void);
CGFloat MTHomePosterWidth(void);        // 100 phone / 140 pad
CGFloat MTHomePosterHeight(void);       // 3:2 poster ratio
CGFloat MTHomeGutter(void);             // gap between posters
CGFloat MTHomeScreenInset(void);        // leading/trailing inset
CGFloat MTHomeContentMaxWidth(void);    // 0 on phone, 760 on pad
CGFloat MTHomeBarHeight(void);          // segmented header height
