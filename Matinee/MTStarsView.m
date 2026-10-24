//
//  MTStarsView.m
//  Matinee
//

#import "MTStarsView.h"
#import "MTAppearance.h"
#import <math.h>

static UIBezierPath *MTStarPath(CGRect rect)
{
    UIBezierPath *path = [UIBezierPath bezierPath];
    CGPoint center = CGPointMake(CGRectGetMidX(rect), CGRectGetMidY(rect));
    CGFloat outer = MIN(CGRectGetWidth(rect), CGRectGetHeight(rect)) * 0.5;
    CGFloat inner = outer * 0.46;

    for (NSInteger i = 0; i < 10; i++) {
        CGFloat radius = (i % 2 == 0) ? outer : inner;
        CGFloat angle = -M_PI_2 + (CGFloat)i * M_PI / 5.0;
        CGPoint point = CGPointMake(center.x + cos(angle) * radius,
                                    center.y + sin(angle) * radius);
        if (i == 0) {
            [path moveToPoint:point];
        } else {
            [path addLineToPoint:point];
        }
    }
    [path closePath];
    return path;
}

@implementation MTStarsView

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
        self.opaque = NO;
        self.starSize = 11.0;
        self.rating = 0.0;
        self.contentMode = UIViewContentModeRedraw;
        self.isAccessibilityElement = YES;
    }
    return self;
}

- (void)setRating:(CGFloat)rating
{
    _rating = MAX(0.0, MIN(5.0, rating));
    [self setNeedsDisplay];
    self.accessibilityLabel = [NSString stringWithFormat:@"%.1f of 5 stars", _rating];
}

- (void)setStarSize:(CGFloat)starSize
{
    _starSize = MAX(6.0, starSize);
    [self invalidateIntrinsicContentSize];
    [self setNeedsDisplay];
}

- (CGSize)intrinsicContentSize
{
    CGFloat width = self.starSize * 5.0 + 2.0 * 4.0;
    return CGSizeMake(width, self.starSize);
}

- (void)drawRect:(CGRect)rect
{
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    if (!ctx) return;

    CGFloat size = self.starSize;
    CGFloat gap = 2.0;
    CGFloat total = size * 5.0 + gap * 4.0;
    CGFloat startX = (CGRectGetWidth(self.bounds) - total) * 0.5;
    CGFloat y = (CGRectGetHeight(self.bounds) - size) * 0.5;

    for (NSInteger i = 0; i < 5; i++) {
        CGRect starRect = CGRectMake(startX + (size + gap) * i, y, size, size);
        UIBezierPath *path = MTStarPath(starRect);

        [[MTAppearance starEmpty] setFill];
        [path fill];

        CGFloat fraction = MAX(0.0, MIN(1.0, self.rating - (CGFloat)i));
        if (fraction > 0.0) {
            CGContextSaveGState(ctx);
            CGContextClipToRect(ctx, CGRectMake(starRect.origin.x,
                                                starRect.origin.y,
                                                starRect.size.width * fraction,
                                                starRect.size.height));
            [[MTAppearance green] setFill];
            [path fill];
            CGContextRestoreGState(ctx);
        }
    }
}

@end


@interface MTRatingControl ()
@property (nonatomic, strong) MTStarsView *stars;
@end

@implementation MTRatingControl

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
        self.opaque = NO;
        _stars = [[MTStarsView alloc] initWithFrame:CGRectZero];
        _stars.starSize = 26.0;
        _stars.userInteractionEnabled = NO;
        [self addSubview:_stars];

        self.isAccessibilityElement = YES;
        self.accessibilityLabel = @"Rating";
        self.accessibilityTraits = UIAccessibilityTraitAdjustable;
    }
    return self;
}

- (void)setRating:(CGFloat)rating
{
    _rating = MAX(0.0, MIN(5.0, rating));
    _stars.rating = _rating;
    [self setNeedsLayout];
    self.accessibilityValue = _rating > 0.0
        ? [NSString stringWithFormat:@"%.1f of 5", _rating]
        : @"Not rated";
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    CGSize starSize = [_stars intrinsicContentSize];
    _stars.frame = CGRectMake((CGRectGetWidth(self.bounds) - starSize.width) * 0.5,
                              0.0,
                              starSize.width,
                              starSize.height);
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    UITouch *touch = [touches anyObject];
    CGPoint point = [touch locationInView:self];
    CGFloat size = _stars.starSize + 2.0;
    CGFloat startX = CGRectGetMinX(_stars.frame);

    if (point.x < startX - 6.0 || point.x > startX + size * 5.0 + 6.0) {
        [super touchesEnded:touches withEvent:event];
        return;
    }

    NSInteger index = (NSInteger)floor((point.x - startX) / size) + 1;
    index = MAX(1, MIN(5, index));

    CGFloat next = (fabs(self.rating - (CGFloat)index) < 0.01) ? 0.0 : (CGFloat)index;
    self.rating = next;
    if (self.onChange) self.onChange(next);
}

- (void)accessibilityIncrement
{
    self.rating = MIN(5.0, self.rating + 0.5);
    if (self.onChange) self.onChange(self.rating);
}

- (void)accessibilityDecrement
{
    self.rating = MAX(0.0, self.rating - 0.5);
    if (self.onChange) self.onChange(self.rating);
}

@end
