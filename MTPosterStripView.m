//
//  MTPosterStripView.m
//  Matinee
//

#import "MTPosterStripView.h"
#import "MTFeedModels.h"
#import "MTHomeTheme.h"
#import <QuartzCore/QuartzCore.h>
#import <math.h>

#define MT_BYLINE_HEIGHT 26.0f

#pragma mark - card

@interface MTPosterCardView : UIView {
    UIImageView *_poster;
    UIImageView *_avatar;
    UILabel *_nameLabel;
    UILabel *_starsLabel;
    BOOL _showsByline;
}
- (void)configureWithItem:(MTFeedItem *)item showsByline:(BOOL)showsByline;
@end

@implementation MTPosterCardView

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        _poster = [[UIImageView alloc] initWithFrame:CGRectZero];
        _poster.backgroundColor = MTHomeSurfaceColor();
        _poster.contentMode = UIViewContentModeScaleAspectFill;
        _poster.clipsToBounds = YES;
        _poster.layer.cornerRadius = 3.0f;
        [self addSubview:_poster];

        _avatar = [[UIImageView alloc] initWithFrame:CGRectZero];
        _avatar.backgroundColor = MTHomeSurfaceColor();
        _avatar.contentMode = UIViewContentModeScaleAspectFill;
        _avatar.clipsToBounds = YES;
        _avatar.layer.cornerRadius = 9.0f;
        _avatar.hidden = YES;
        [self addSubview:_avatar];

        _nameLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _nameLabel.font = [UIFont systemFontOfSize:11.0f];
        _nameLabel.textColor = MTHomeSecondaryTextColor();
        _nameLabel.backgroundColor = [UIColor clearColor];
        _nameLabel.lineBreakMode = NSLineBreakByTruncatingTail;
        _nameLabel.hidden = YES;
        [self addSubview:_nameLabel];

        _starsLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _starsLabel.font = [UIFont systemFontOfSize:9.0f];
        _starsLabel.textColor = MTHomeGreenColor();
        _starsLabel.backgroundColor = [UIColor clearColor];
        _starsLabel.hidden = YES;
        [self addSubview:_starsLabel];
    }
    return self;
}

- (void)dealloc
{
    [_poster release];
    [_avatar release];
    [_nameLabel release];
    [_starsLabel release];
    [super dealloc];
}

- (void)configureWithItem:(MTFeedItem *)item showsByline:(BOOL)showsByline
{
    _showsByline = showsByline;

    // RSS feeds carry a display name but no avatar; collapse the avatar slot
    // so the name starts at the card edge instead of leaving a blank circle.
    _avatar.hidden = (!showsByline || !item.avatarPath.length);
    _nameLabel.hidden = !showsByline;
    _starsLabel.hidden = !showsByline;

    MTLoadImage(MTPosterURLString(item.posterPath), _poster);

    if (showsByline) {
        _nameLabel.text = item.reviewerName;
        _starsLabel.text = (item.rating > 0.0f) ? MTStarsString(item.rating) : @"";
        MTLoadImage(MTPosterURLString(item.avatarPath), _avatar);
    }

    [self setNeedsLayout];
}

- (void)layoutSubviews
{
    [super layoutSubviews];

    CGFloat width = CGRectGetWidth(self.bounds);
    CGFloat posterHeight = width * 1.5f;

    _poster.frame = CGRectMake(0.0f, 0.0f, width, posterHeight);

    if (!_showsByline) {
        _avatar.frame = CGRectZero;
        _nameLabel.frame = CGRectZero;
        _starsLabel.frame = CGRectZero;
        return;
    }

    CGFloat y = posterHeight + 7.0f;
    CGFloat textX = _avatar.hidden ? 0.0f : 23.0f;

    _avatar.frame = _avatar.hidden ? CGRectZero : CGRectMake(0.0f, y, 18.0f, 18.0f);
    _nameLabel.frame = CGRectMake(textX, y - 1.0f, width - textX, 12.0f);
    _starsLabel.frame = CGRectMake(textX, y + 10.0f, width - textX, 11.0f);
}

@end

#pragma mark - strip

@interface MTPosterStripView () {
    UIScrollView *_scrollView;
    NSMutableArray *_cards;
    BOOL _showsByline;
}
@end

@implementation MTPosterStripView

+ (CGFloat)heightForWidth:(CGFloat)width showsByline:(BOOL)showsByline
{
    CGFloat posterWidth = MTHomePosterWidth();
    if (posterWidth > width) posterWidth = width;
    CGFloat height = posterWidth * 1.5f;
    if (showsByline) height += MT_BYLINE_HEIGHT;
    return height;
}

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = MTHomeBackgroundColor();

        _scrollView = [[UIScrollView alloc] initWithFrame:CGRectZero];
        _scrollView.backgroundColor = MTHomeBackgroundColor();
        _scrollView.showsHorizontalScrollIndicator = NO;
        _scrollView.showsVerticalScrollIndicator = NO;
        _scrollView.alwaysBounceHorizontal = YES;
        _scrollView.decelerationRate = UIScrollViewDecelerationRateFast;
        [self addSubview:_scrollView];

        _cards = [[NSMutableArray alloc] init];
    }
    return self;
}

- (void)dealloc
{
    [_scrollView release];
    [_cards release];
    [super dealloc];
}

- (void)setItems:(NSArray *)items showsByline:(BOOL)showsByline
{
    _showsByline = showsByline;

    for (MTPosterCardView *card in _cards) {
        [card removeFromSuperview];
    }
    [_cards removeAllObjects];

    for (MTFeedItem *item in items) {
        MTPosterCardView *card = [[MTPosterCardView alloc] initWithFrame:CGRectZero];
        [card configureWithItem:item showsByline:showsByline];
        [_scrollView addSubview:card];
        [_cards addObject:card];
        [card release];
    }

    [self setNeedsLayout];
}

- (void)layoutForWidth:(CGFloat)width
{
    CGFloat height = CGRectGetHeight(self.bounds);
    _scrollView.frame = CGRectMake(0.0f, 0.0f, width, height);

    CGFloat posterWidth = MTHomePosterWidth();
    if (posterWidth > width) posterWidth = width;

    CGFloat gutter = MTHomeGutter();
    CGFloat inset = MTHomeScreenInset();
    CGFloat x = inset;

    for (MTPosterCardView *card in _cards) {
        card.frame = CGRectMake(x, 0.0f, posterWidth, height);
        x += posterWidth + gutter;
    }

    if (_cards.count == 0) {
        _scrollView.contentSize = CGSizeMake(width, height);
        return;
    }
    _scrollView.contentSize = CGSizeMake(x - gutter + inset, height);
}

@end
