//
//  MTAppearance.m
//  Matinee
//

#import "MTAppearance.h"

static const CGFloat MTCardInset = 8.0;
static const CGFloat MTCardRadius = 9.0;

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

static UIBezierPath *MTCardOutline(CGRect rect, BOOL first, BOOL last)
{
    CGFloat radius = MTCardRadius;

    if (first && last) {
        return [UIBezierPath bezierPathWithRoundedRect:rect cornerRadius:radius];
    }

    UIBezierPath *path = [UIBezierPath bezierPath];
    if (first) {
        [path moveToPoint:CGPointMake(CGRectGetMinX(rect), CGRectGetMaxY(rect))];
        [path addLineToPoint:CGPointMake(CGRectGetMinX(rect), CGRectGetMinY(rect) + radius)];
        [path addArcWithCenter:CGPointMake(CGRectGetMinX(rect) + radius, CGRectGetMinY(rect) + radius)
                        radius:radius
                    startAngle:M_PI
                      endAngle:1.5 * M_PI
                     clockwise:YES];
        [path addLineToPoint:CGPointMake(CGRectGetMaxX(rect) - radius, CGRectGetMinY(rect))];
        [path addArcWithCenter:CGPointMake(CGRectGetMaxX(rect) - radius, CGRectGetMinY(rect) + radius)
                        radius:radius
                    startAngle:1.5 * M_PI
                      endAngle:0.0
                     clockwise:YES];
        [path addLineToPoint:CGPointMake(CGRectGetMaxX(rect), CGRectGetMaxY(rect))];
    } else if (last) {
        [path moveToPoint:CGPointMake(CGRectGetMinX(rect), CGRectGetMinY(rect))];
        [path addLineToPoint:CGPointMake(CGRectGetMinX(rect), CGRectGetMaxY(rect) - radius)];
        [path addArcWithCenter:CGPointMake(CGRectGetMinX(rect) + radius, CGRectGetMaxY(rect) - radius)
                        radius:radius
                    startAngle:M_PI
                      endAngle:0.5 * M_PI
                     clockwise:NO];
        [path addLineToPoint:CGPointMake(CGRectGetMaxX(rect) - radius, CGRectGetMaxY(rect))];
        [path addArcWithCenter:CGPointMake(CGRectGetMaxX(rect) - radius, CGRectGetMaxY(rect) - radius)
                        radius:radius
                    startAngle:0.5 * M_PI
                      endAngle:0.0
                     clockwise:NO];
        [path addLineToPoint:CGPointMake(CGRectGetMaxX(rect), CGRectGetMinY(rect))];
    } else {
        [path moveToPoint:CGPointMake(CGRectGetMinX(rect), CGRectGetMinY(rect))];
        [path addLineToPoint:CGPointMake(CGRectGetMinX(rect), CGRectGetMaxY(rect))];
        [path moveToPoint:CGPointMake(CGRectGetMaxX(rect), CGRectGetMinY(rect))];
        [path addLineToPoint:CGPointMake(CGRectGetMaxX(rect), CGRectGetMaxY(rect))];
    }
    return path;
}

static UIImage *MTBarButtonImage(CGFloat width, BOOL back, BOOL highlighted)
{
    CGSize size = CGSizeMake(width, 30.0);
    UIGraphicsBeginImageContextWithOptions(size, NO, 0.0);
    CGContextRef ctx = UIGraphicsGetCurrentContext();

    UIBezierPath *path = nil;
    if (back) {
        path = [UIBezierPath bezierPath];
        [path moveToPoint:CGPointMake(8.5, 0.5)];
        [path addLineToPoint:CGPointMake(width - 0.5, 0.5)];
        [path addLineToPoint:CGPointMake(width - 0.5, 29.5)];
        [path addLineToPoint:CGPointMake(8.5, 29.5)];
        [path addLineToPoint:CGPointMake(0.5, 15.0)];
        [path closePath];
    } else {
        path = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(0.5, 0.5, width - 1.0, 29.0)
                                          cornerRadius:5.0];
    }

    CGContextSaveGState(ctx);
    [path addClip];

    NSArray *colors = highlighted
        ? @[
            (__bridge id)[UIColor colorWithRed:0.30 green:0.42 blue:0.56 alpha:1.0].CGColor,
            (__bridge id)[UIColor colorWithRed:0.23 green:0.35 blue:0.47 alpha:1.0].CGColor
          ]
        : @[
            (__bridge id)[UIColor colorWithRed:0.54 green:0.65 blue:0.78 alpha:1.0].CGColor,
            (__bridge id)[UIColor colorWithRed:0.35 green:0.48 blue:0.64 alpha:1.0].CGColor,
            (__bridge id)[UIColor colorWithRed:0.28 green:0.42 blue:0.57 alpha:1.0].CGColor,
            (__bridge id)[UIColor colorWithRed:0.22 green:0.35 blue:0.49 alpha:1.0].CGColor
          ];
    CGFloat locations[] = { 0.0, 0.49, 0.50, 1.0 };
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CGGradientRef gradient = CGGradientCreateWithColors(space,
                                                        (__bridge CFArrayRef)colors,
                                                        locations);
    CGContextDrawLinearGradient(ctx, gradient,
                                CGPointMake(0.0, 0.0),
                                CGPointMake(0.0, 30.0),
                                0);
    CGGradientRelease(gradient);
    CGColorSpaceRelease(space);

    CGContextSetFillColorWithColor(ctx, [UIColor colorWithWhite:1.0 alpha:0.28].CGColor);
    CGContextFillRect(ctx, CGRectMake(3.0, 1.5, width - 6.0, 1.0));
    CGContextRestoreGState(ctx);

    CGContextSetStrokeColorWithColor(ctx,
        [UIColor colorWithRed:0.13 green:0.22 blue:0.31 alpha:1.0].CGColor);
    CGContextSetLineWidth(ctx, 1.0);
    CGContextAddPath(ctx, path.CGPath);
    CGContextStrokePath(ctx);

    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}


@implementation MTCardBackgroundView

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
        self.opaque = NO;
        self.contentMode = UIViewContentModeRedraw;
    }
    return self;
}

- (void)setFirst:(BOOL)first
{
    _first = first;
    [self setNeedsDisplay];
}

- (void)setLast:(BOOL)last
{
    _last = last;
    [self setNeedsDisplay];
}

- (void)drawRect:(CGRect)rect
{
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    if (!ctx) return;

    CGRect card = CGRectMake(MTCardInset, 0.0,
                             CGRectGetWidth(self.bounds) - MTCardInset * 2.0,
                             CGRectGetHeight(self.bounds));
    CGFloat scale = self.contentScaleFactor ?: 1.0;
    CGFloat hairline = 1.0 / scale;

    [[UIColor whiteColor] setFill];
    UIRectFill(card);

    UIBezierPath *outline = MTCardOutline(card, self.first, self.last);
    [[UIColor colorWithRed:0.65 green:0.68 blue:0.71 alpha:1.0] setStroke];
    outline.lineWidth = hairline;
    [outline stroke];

    if (!self.last) {
        CGContextSetFillColorWithColor(ctx,
            [UIColor colorWithRed:0.835 green:0.847 blue:0.863 alpha:1.0].CGColor);
        CGContextFillRect(ctx, CGRectMake(CGRectGetMinX(card),
                                          CGRectGetMaxY(self.bounds) - hairline,
                                          CGRectGetWidth(card),
                                          hairline));
    }

    if (self.first) {
        CGContextSetFillColorWithColor(ctx, [UIColor colorWithWhite:1.0 alpha:0.65].CGColor);
        CGContextFillRect(ctx, CGRectMake(CGRectGetMinX(card) + 1.0,
                                          CGRectGetMinY(card) + 1.0,
                                          CGRectGetWidth(card) - 2.0,
                                          hairline));
    }
}

@end


@implementation MTSectionHeadView

- (id)initWithTitle:(NSString *)title
{
    self = [super initWithFrame:CGRectMake(0.0, 0.0, 320.0, 32.0)];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
        self.autoresizingMask = UIViewAutoresizingFlexibleWidth;

        _titleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _titleLabel.backgroundColor = [UIColor clearColor];
        _titleLabel.font = [MTAppearance groupTitleFont];
        _titleLabel.textColor = [UIColor colorWithRed:0.30 green:0.34 blue:0.39 alpha:1.0];
        _titleLabel.shadowColor = [UIColor colorWithWhite:1.0 alpha:0.72];
        _titleLabel.shadowOffset = CGSizeMake(0.0, 1.0);
        _titleLabel.text = [title uppercaseString];
        [self addSubview:_titleLabel];
    }
    return self;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    self.titleLabel.frame = CGRectMake(12.0, 10.0,
                                       CGRectGetWidth(self.bounds) - 24.0, 15.0);
}

@end


@implementation MTAppearance

+ (UIColor *)green      { return [UIColor colorWithRed:0.00 green:0.78 blue:0.33 alpha:1.0]; }
+ (UIColor *)starEmpty  { return [UIColor colorWithRed:0.82 green:0.84 blue:0.86 alpha:1.0]; }
+ (UIColor *)paper      { return [UIColor colorWithRed:0.957 green:0.961 blue:0.969 alpha:1.0]; }
+ (UIColor *)groupBackground { return [UIColor colorWithRed:0.784 green:0.800 blue:0.824 alpha:1.0]; }
+ (UIColor *)sep        { return [UIColor colorWithRed:0.79 green:0.80 blue:0.82 alpha:1.0]; }
+ (UIColor *)ink        { return [UIColor colorWithRed:0.13 green:0.13 blue:0.15 alpha:1.0]; }
+ (UIColor *)muted      { return [UIColor colorWithRed:0.48 green:0.48 blue:0.50 alpha:1.0]; }
+ (UIColor *)placeholder{ return [UIColor colorWithRed:0.906 green:0.914 blue:0.929 alpha:1.0]; }
+ (UIColor *)link       { return [UIColor colorWithRed:0.16 green:0.35 blue:0.56 alpha:1.0]; }

+ (UIFont *)titleFont { return [UIFont boldSystemFontOfSize:16.0]; }
+ (UIFont *)bodyFont  { return [UIFont systemFontOfSize:13.0]; }
+ (UIFont *)smallFont { return [UIFont systemFontOfSize:11.0]; }
+ (UIFont *)groupTitleFont { return [UIFont boldSystemFontOfSize:11.0]; }

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

+ (UIImage *)pinstripeImage
{
    static UIImage *image = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        UIGraphicsBeginImageContextWithOptions(CGSizeMake(4.0, 1.0), YES, 0.0);
        CGContextRef ctx = UIGraphicsGetCurrentContext();
        [[self groupBackground] setFill];
        CGContextFillRect(ctx, CGRectMake(0.0, 0.0, 4.0, 1.0));
        [[UIColor colorWithWhite:1.0 alpha:0.34] setFill];
        CGContextFillRect(ctx, CGRectMake(0.0, 0.0, 1.0, 1.0));
        image = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
    });
    return image;
}

+ (UIImage *)tabSelectionImage
{
    static UIImage *image = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        UIGraphicsBeginImageContextWithOptions(CGSizeMake(80.0, 49.0), NO, 0.0);
        CGContextRef ctx = UIGraphicsGetCurrentContext();

        CGRect rect = CGRectMake(2.0, 3.0, 76.0, 43.0);
        UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:rect cornerRadius:7.0];

        CGContextSaveGState(ctx);
        [path addClip];

        NSArray *colors = @[
            (__bridge id)[UIColor colorWithRed:0.43 green:0.43 blue:0.43 alpha:1.0].CGColor,
            (__bridge id)[UIColor colorWithRed:0.29 green:0.29 blue:0.29 alpha:1.0].CGColor,
            (__bridge id)[UIColor colorWithRed:0.23 green:0.23 blue:0.23 alpha:1.0].CGColor,
            (__bridge id)[UIColor colorWithRed:0.15 green:0.15 blue:0.15 alpha:1.0].CGColor
        ];
        CGFloat locations[] = { 0.0, 0.49, 0.50, 1.0 };
        CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
        CGGradientRef gradient = CGGradientCreateWithColors(space,
                                                            (__bridge CFArrayRef)colors,
                                                            locations);
        CGContextDrawLinearGradient(ctx, gradient,
                                    CGPointMake(0.0, CGRectGetMinY(rect)),
                                    CGPointMake(0.0, CGRectGetMaxY(rect)),
                                    0);
        CGGradientRelease(gradient);
        CGColorSpaceRelease(space);

        CGContextSetFillColorWithColor(ctx, [UIColor colorWithWhite:1.0 alpha:0.28].CGColor);
        CGContextFillRect(ctx, CGRectMake(8.0, 3.5, 64.0, 1.0));
        CGContextRestoreGState(ctx);

        CGContextSetStrokeColorWithColor(ctx, [UIColor colorWithWhite:0.0 alpha:0.9].CGColor);
        CGContextSetLineWidth(ctx, 1.0);
        CGContextAddPath(ctx, path.CGPath);
        CGContextStrokePath(ctx);

        image = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
    });
    return image;
}

+ (UIImage *)tabIconForTab:(MTTabIcon)tab selected:(BOOL)selected
{
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(24.0, 24.0), NO, 0.0);
    CGContextRef ctx = UIGraphicsGetCurrentContext();

    UIColor *color = selected
        ? [UIColor whiteColor]
        : [UIColor colorWithRed:0.63 green:0.63 blue:0.65 alpha:1.0];
    CGContextSetStrokeColorWithColor(ctx, color.CGColor);
    CGContextSetFillColorWithColor(ctx, color.CGColor);
    CGContextSetLineWidth(ctx, 2.0);
    CGContextSetLineCap(ctx, kCGLineCapRound);

    if (tab == MTTabIconDiary) {
        UIBezierPath *page = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(4.0, 3.0, 16.0, 18.0)
                                                            cornerRadius:1.5];
        [color setFill];
        [page fill];

        CGContextSetStrokeColorWithColor(ctx,
            [UIColor colorWithRed:0.08 green:0.08 blue:0.09 alpha:1.0].CGColor);
        CGContextSetLineWidth(ctx, 1.5);
        for (NSInteger i = 0; i < 3; i++) {
            CGFloat y = 7.5 + (CGFloat)i * 4.0;
            CGContextMoveToPoint(ctx, 8.0, y);
            CGContextAddLineToPoint(ctx, 16.0, y);
        }
        CGContextStrokePath(ctx);
    } else if (tab == MTTabIconLists) {
        [color setFill];
        for (NSInteger i = 0; i < 4; i++) {
            CGFloat y = 5.0 + (CGFloat)i * 4.0;
            CGContextFillRect(ctx, CGRectMake(4.0, y, 11.0, 2.0));
            CGContextFillRect(ctx, CGRectMake(17.0, y, 3.0, 2.0));
        }
    } else if (tab == MTTabIconSearch) {
        UIBezierPath *circle = [UIBezierPath bezierPathWithOvalInRect:CGRectMake(4.5, 4.5, 12.0, 12.0)];
        circle.lineWidth = 2.0;
        [color setStroke];
        [circle stroke];
        CGContextMoveToPoint(ctx, 15.0, 15.0);
        CGContextAddLineToPoint(ctx, 20.0, 20.0);
        CGContextStrokePath(ctx);
    } else {
        [color setFill];
        CGContextFillEllipseInRect(ctx, CGRectMake(8.0, 4.0, 8.0, 8.0));
        UIBezierPath *body = [UIBezierPath bezierPath];
        [body moveToPoint:CGPointMake(4.0, 21.0)];
        [body addCurveToPoint:CGPointMake(20.0, 21.0)
                controlPoint1:CGPointMake(4.4, 14.0)
                controlPoint2:CGPointMake(19.6, 14.0)];
        [body closePath];
        [body fill];
    }

    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

+ (UIImage *)actionButtonImage
{
    static UIImage *image = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        UIGraphicsBeginImageContextWithOptions(CGSizeMake(24.0, 38.0), NO, 0.0);
        CGContextRef ctx = UIGraphicsGetCurrentContext();
        CGRect rect = CGRectMake(0.5, 0.5, 23.0, 37.0);
        UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:rect cornerRadius:6.0];

        CGContextSaveGState(ctx);
        [path addClip];
        NSArray *colors = @[
            (__bridge id)[UIColor colorWithRed:0.44 green:0.61 blue:0.80 alpha:1.0].CGColor,
            (__bridge id)[UIColor colorWithRed:0.20 green:0.38 blue:0.55 alpha:1.0].CGColor
        ];
        CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
        CGGradientRef gradient = CGGradientCreateWithColors(space,
                                                            (__bridge CFArrayRef)colors,
                                                            NULL);
        CGContextDrawLinearGradient(ctx, gradient,
                                    CGPointMake(0.0, 0.0),
                                    CGPointMake(0.0, 38.0),
                                    0);
        CGGradientRelease(gradient);
        CGColorSpaceRelease(space);
        CGContextRestoreGState(ctx);

        CGContextSetStrokeColorWithColor(ctx,
            [UIColor colorWithRed:0.14 green:0.24 blue:0.35 alpha:1.0].CGColor);
        CGContextSetLineWidth(ctx, 1.0);
        CGContextAddPath(ctx, path.CGPath);
        CGContextStrokePath(ctx);

        image = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
    });
    return [image resizableImageWithCapInsets:UIEdgeInsetsMake(8.0, 8.0, 8.0, 8.0)];
}

+ (UIImage *)dangerButtonImage
{
    static UIImage *image = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        UIGraphicsBeginImageContextWithOptions(CGSizeMake(24.0, 38.0), NO, 0.0);
        CGContextRef ctx = UIGraphicsGetCurrentContext();
        CGRect rect = CGRectMake(0.5, 0.5, 23.0, 37.0);
        UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:rect cornerRadius:6.0];

        CGContextSaveGState(ctx);
        [path addClip];
        NSArray *colors = @[
            (__bridge id)[UIColor colorWithRed:0.76 green:0.31 blue:0.27 alpha:1.0].CGColor,
            (__bridge id)[UIColor colorWithRed:0.60 green:0.19 blue:0.16 alpha:1.0].CGColor
        ];
        CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
        CGGradientRef gradient = CGGradientCreateWithColors(space,
                                                            (__bridge CFArrayRef)colors,
                                                            NULL);
        CGContextDrawLinearGradient(ctx, gradient,
                                    CGPointMake(0.0, 0.0),
                                    CGPointMake(0.0, 38.0),
                                    0);
        CGGradientRelease(gradient);
        CGColorSpaceRelease(space);
        CGContextRestoreGState(ctx);

        CGContextSetStrokeColorWithColor(ctx,
            [UIColor colorWithRed:0.38 green:0.10 blue:0.08 alpha:1.0].CGColor);
        CGContextSetLineWidth(ctx, 1.0);
        CGContextAddPath(ctx, path.CGPath);
        CGContextStrokePath(ctx);

        image = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
    });
    return [image resizableImageWithCapInsets:UIEdgeInsetsMake(8.0, 8.0, 8.0, 8.0)];
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
    tabBar.selectionIndicatorImage = [self tabSelectionImage];
    tabBar.tintColor = [UIColor colorWithWhite:0.18 alpha:1.0];
}

+ (UIButton *)barButtonWithTitle:(NSString *)title
                            back:(BOOL)back
                          target:(id)target
                          action:(SEL)action
{
    UIFont *font = [UIFont boldSystemFontOfSize:12.0];
    CGSize textSize = [title sizeWithFont:font];
    CGFloat width = ceil(textSize.width) + (back ? 31.0 : 20.0);
    width = MAX(width, 44.0);
    width = MIN(width, 104.0);

    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    button.frame = CGRectMake(0.0, 0.0, width, 30.0);
    [button setBackgroundImage:MTBarButtonImage(width, back, NO)
                      forState:UIControlStateNormal];
    [button setBackgroundImage:MTBarButtonImage(width, back, YES)
                      forState:UIControlStateHighlighted];
    [button setTitle:title forState:UIControlStateNormal];
    button.titleLabel.font = font;
    button.titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    button.contentEdgeInsets = UIEdgeInsetsMake(0.0, back ? 14.0 : 0.0, 0.0, 0.0);
    [button setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [button setTitleShadowColor:[UIColor colorWithWhite:0.0 alpha:0.55]
                       forState:UIControlStateNormal];
    button.titleLabel.shadowOffset = CGSizeMake(0.0, -1.0);
    [button addTarget:target action:action forControlEvents:UIControlEventTouchUpInside];
    return button;
}

@end
