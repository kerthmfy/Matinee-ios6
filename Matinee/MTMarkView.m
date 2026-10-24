//
//  MTMarkView.m
//  Matinee
//

#import "MTMarkView.h"

@implementation MTMarkView

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
        self.opaque = NO;
        self.contentMode = UIViewContentModeRedraw;
        self.isAccessibilityElement = YES;
        self.accessibilityLabel = @"Matinee";
    }
    return self;
}

- (void)drawOrbInContext:(CGContextRef)ctx
                  center:(CGPoint)center
                  radius:(CGFloat)radius
                  colors:(NSArray *)colors
{
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CGGradientRef gradient = CGGradientCreateWithColors(space, (__bridge CFArrayRef)colors, NULL);

    CGRect circle = CGRectMake(center.x - radius, center.y - radius, radius * 2.0, radius * 2.0);

    CGContextSetShadowWithColor(ctx,
                                CGSizeMake(0.0, 1.0),
                                1.0,
                                [UIColor colorWithWhite:0.0 alpha:0.40].CGColor);

    CGContextSaveGState(ctx);
    CGContextAddEllipseInRect(ctx, circle);
    CGContextClip(ctx);
    CGContextDrawRadialGradient(ctx, gradient,
                                CGPointMake(center.x - radius * 0.28, center.y - radius * 0.32),
                                0.0,
                                center,
                                radius,
                                0);
    CGContextRestoreGState(ctx);
    CGContextSetShadowWithColor(ctx, CGSizeZero, 0.0, NULL);

    // Bounce light along the lower edge.
    NSArray *bounce = @[
        (__bridge id)[UIColor colorWithWhite:1.0 alpha:0.34].CGColor,
        (__bridge id)[UIColor colorWithWhite:1.0 alpha:0.0].CGColor
    ];
    CGGradientRef bounceGradient = CGGradientCreateWithColors(space, (__bridge CFArrayRef)bounce, NULL);
    CGContextSaveGState(ctx);
    CGContextAddEllipseInRect(ctx, circle);
    CGContextClip(ctx);
    CGContextDrawRadialGradient(ctx, bounceGradient,
                                CGPointMake(center.x, center.y + radius * 0.9),
                                0.0,
                                CGPointMake(center.x, center.y + radius * 0.9),
                                radius * 0.9,
                                0);
    CGContextRestoreGState(ctx);
    CGGradientRelease(bounceGradient);

    // Specular highlight.
    CGContextSaveGState(ctx);
    CGContextTranslateCTM(ctx, center.x - radius * 0.30, center.y - radius * 0.42);
    CGContextRotateCTM(ctx, -0.35);
    CGContextSetFillColorWithColor(ctx, [UIColor colorWithWhite:1.0 alpha:0.55].CGColor);
    CGContextFillEllipseInRect(ctx, CGRectMake(-radius * 0.34, -radius * 0.19, radius * 0.68, radius * 0.38));
    CGContextSetFillColorWithColor(ctx, [UIColor colorWithWhite:1.0 alpha:0.30].CGColor);
    CGContextFillEllipseInRect(ctx, CGRectMake(-radius * 0.20, -radius * 0.10, radius * 0.40, radius * 0.22));
    CGContextRestoreGState(ctx);

    CGGradientRelease(gradient);
    CGColorSpaceRelease(space);
}

- (void)drawRect:(CGRect)rect
{
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    if (!ctx) return;

    // The mark is designed in a 40 x 32 box.
    CGContextSaveGState(ctx);
    CGContextScaleCTM(ctx,
                      CGRectGetWidth(self.bounds) / 40.0,
                      CGRectGetHeight(self.bounds) / 32.0);

    NSArray *orange = @[
        (__bridge id)[UIColor colorWithRed:1.00 green:0.88 blue:0.74 alpha:1.0].CGColor,
        (__bridge id)[UIColor colorWithRed:1.00 green:0.62 blue:0.21 alpha:1.0].CGColor,
        (__bridge id)[UIColor colorWithRed:0.81 green:0.31 blue:0.00 alpha:1.0].CGColor
    ];
    NSArray *green = @[
        (__bridge id)[UIColor colorWithRed:0.73 green:1.00 blue:0.84 alpha:1.0].CGColor,
        (__bridge id)[UIColor colorWithRed:0.36 green:0.94 blue:0.60 alpha:1.0].CGColor,
        (__bridge id)[UIColor colorWithRed:0.00 green:0.59 blue:0.24 alpha:1.0].CGColor
    ];
    NSArray *blue = @[
        (__bridge id)[UIColor colorWithRed:0.80 green:0.93 blue:1.00 alpha:1.0].CGColor,
        (__bridge id)[UIColor colorWithRed:0.50 green:0.82 blue:0.98 alpha:1.0].CGColor,
        (__bridge id)[UIColor colorWithRed:0.04 green:0.47 blue:0.72 alpha:1.0].CGColor
    ];

    [self drawOrbInContext:ctx center:CGPointMake(8.1, 19.4) radius:7.9 colors:orange];
    [self drawOrbInContext:ctx center:CGPointMake(20.0, 15.6) radius:7.9 colors:green];
    [self drawOrbInContext:ctx center:CGPointMake(31.9, 19.4) radius:7.9 colors:blue];

    CGContextRestoreGState(ctx);
}

@end
