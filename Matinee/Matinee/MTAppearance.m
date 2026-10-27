//
//  MTAppearance.m
//  Matinee
//

#import "MTAppearance.h"

static UIImage *MTGradientImage(NSArray *colors, CGFloat height, BOOL highlight)
{
    CGSize size = CGSizeMake(1.0, height);
    UIGraphicsBeginImageContextWithOptions(size, YES, 0.0);
    CGContextRef ctx = UIGraphicsGetCurrentContext();

    CGGradientRef gradient = NULL;
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();

    NSMutableArray *cgColors = [NSMutableArray array];
    for (UIColor *color in colors) {
        [cgColors addObject:(__bridge id)color.CGColor];
    }
    gradient = CGGradientCreateWithColors(space, (__bridge CFArrayRef)cgColors, NULL);

    CGContextDrawLinearGradient(ctx, gradient,
                                CGPointMake(0.0, 0.0),
                                CGPointMake(0.0, height),
                                0);

    CGGradientRelease(gradient);
    CGColorSpaceRelease(space);

    if (highlight) {
        CGContextSetFillColorWithColor(ctx, [UIColor colorWithWhite:1.0 alpha:0.40].CGColor);
        CGContextFillRect(ctx, CGRectMake(0.0, 0.0, 1.0, 1.0));
        CGContextSetFillColorWithColor(ctx, [UIColor colorWithWhite:1.0 alpha:0.07].CGColor);
        CGContextFillRect(ctx, CGRectMake(0.0, 1.0, 1.0, 1.0));
    }

    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

@implementation MTAppearance

+ (UIColor *)green      { return [UIColor colorWithRed:0.00 green:0.78 blue:0.33 alpha:1.0]; }
+ (UIColor *)starEmpty  { return [UIColor colorWithRed:0.82 green:0.84 blue:0.86 alpha:1.0]; }
+ (UIColor *)paper      { return [UIColor colorWithRed:0.957 green:0.961 blue:0.969 alpha:1.0]; }
+ (UIColor *)sep        { return [UIColor colorWithRed:0.79 green:0.80 blue:0.82 alpha:1.0]; }
+ (UIColor *)ink        { return [UIColor colorWithRed:0.13 green:0.13 blue:0.15 alpha:1.0]; }
+ (UIColor *)muted      { return [UIColor colorWithRed:0.48 green:0.48 blue:0.50 alpha:1.0]; }
+ (UIColor *)placeholder{ return [UIColor colorWithRed:0.906 green:0.914 blue:0.929 alpha:1.0]; }
+ (UIColor *)link       { return [UIColor colorWithRed:0.16 green:0.35 blue:0.56 alpha:1.0]; }

+ (UIFont *)titleFont { return [UIFont boldSystemFontOfSize:16.0]; }
+ (UIFont *)bodyFont  { return [UIFont systemFontOfSize:13.0]; }
+ (UIFont *)smallFont { return [UIFont systemFontOfSize:11.0]; }

+ (UIImage *)navigationBarImage
{
    static UIImage *image = nil;
    if (!image) {
        image = MTGradientImage(@[
            [UIColor colorWithRed:0.42 green:0.56 blue:0.70 alpha:1.0],
            [UIColor colorWithRed:0.36 green:0.50 blue:0.65 alpha:1.0],
            [UIColor colorWithRed:0.28 green:0.42 blue:0.57 alpha:1.0],
            [UIColor colorWithRed:0.23 green:0.36 blue:0.50 alpha:1.0]
        ], 44.0, YES);
    }
    return image;
}

+ (UIImage *)tabBarImage
{
    static UIImage *image = nil;
    if (!image) {
        image = MTGradientImage(@[
            [UIColor colorWithRed:0.19 green:0.19 blue:0.20 alpha:1.0],
            [UIColor colorWithRed:0.12 green:0.12 blue:0.13 alpha:1.0],
            [UIColor colorWithRed:0.05 green:0.05 blue:0.06 alpha:1.0]
        ], 49.0, YES);
    }
    return image;
}

+ (void)styleNavigationBar:(UINavigationBar *)bar
{
    [bar setBackgroundImage:[self navigationBarImage] forBarMetrics:UIBarMetricsDefault];
    bar.tintColor = [UIColor colorWithRed:0.16 green:0.28 blue:0.42 alpha:1.0];
    NSDictionary *attributes = @{
        UITextAttributeTextColor: [UIColor whiteColor],
        UITextAttributeTextShadowColor: [UIColor colorWithWhite:0.0 alpha:0.55],
        UITextAttributeTextShadowOffset: [NSValue valueWithUIOffset:UIOffsetMake(0.0, -1.0)],
        UITextAttributeFont: [UIFont boldSystemFontOfSize:17.0]
    };
    [bar setTitleTextAttributes:attributes];
}

+ (void)styleTabBar:(UITabBar *)tabBar
{
    [tabBar setBackgroundImage:[self tabBarImage]];
    tabBar.tintColor = [UIColor colorWithRed:0.45 green:0.62 blue:0.80 alpha:1.0];
}

@end
