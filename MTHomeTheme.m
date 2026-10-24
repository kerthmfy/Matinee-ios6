//
//  MTHomeTheme.m
//  Matinee
//

#import "MTHomeTheme.h"

static UIColor *MTHomeCachedColor(CGFloat r, CGFloat g, CGFloat b, UIColor **slot, dispatch_once_t *once)
{
    dispatch_once(once, ^{
        *slot = [[UIColor alloc] initWithRed:(r / 255.0f)
                                       green:(g / 255.0f)
                                        blue:(b / 255.0f)
                                       alpha:1.0f];
    });
    return *slot;
}

UIColor *MTHomeBackgroundColor(void)
{
    static UIColor *color = nil;
    static dispatch_once_t once;
    return MTHomeCachedColor(20.0f, 24.0f, 28.0f, &color, &once);
}

UIColor *MTHomeSurfaceColor(void)
{
    static UIColor *color = nil;
    static dispatch_once_t once;
    return MTHomeCachedColor(27.0f, 34.0f, 40.0f, &color, &once);
}

UIColor *MTHomeSeparatorColor(void)
{
    static UIColor *color = nil;
    static dispatch_once_t once;
    return MTHomeCachedColor(44.0f, 52.0f, 64.0f, &color, &once);
}

UIColor *MTHomeTextColor(void)
{
    static UIColor *color = nil;
    static dispatch_once_t once;
    return MTHomeCachedColor(255.0f, 255.0f, 255.0f, &color, &once);
}

UIColor *MTHomeSecondaryTextColor(void)
{
    static UIColor *color = nil;
    static dispatch_once_t once;
    return MTHomeCachedColor(153.0f, 170.0f, 187.0f, &color, &once);
}

UIColor *MTHomeGreenColor(void)
{
    static UIColor *color = nil;
    static dispatch_once_t once;
    return MTHomeCachedColor(0.0f, 224.0f, 84.0f, &color, &once);
}

UIColor *MTHomeOrangeColor(void)
{
    static UIColor *color = nil;
    static dispatch_once_t once;
    return MTHomeCachedColor(255.0f, 128.0f, 0.0f, &color, &once);
}

UIColor *MTHomeBlueColor(void)
{
    static UIColor *color = nil;
    static dispatch_once_t once;
    return MTHomeCachedColor(64.0f, 188.0f, 244.0f, &color, &once);
}

BOOL MTHomeIsPad(void)
{
    return UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad;
}

CGFloat MTHomePosterWidth(void)
{
    return MTHomeIsPad() ? 140.0f : 100.0f;
}

CGFloat MTHomePosterHeight(void)
{
    return MTHomePosterWidth() * 1.5f;
}

CGFloat MTHomeGutter(void)
{
    return MTHomeIsPad() ? 14.0f : 10.0f;
}

CGFloat MTHomeScreenInset(void)
{
    return MTHomeIsPad() ? 24.0f : 16.0f;
}

CGFloat MTHomeContentMaxWidth(void)
{
    return MTHomeIsPad() ? 760.0f : 0.0f;
}

CGFloat MTHomeBarHeight(void)
{
    return 44.0f;
}
