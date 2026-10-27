//
//  MTFilmViewController.m
//  Matinee
//

#import "MTFilmViewController.h"
#import "MTAppearance.h"
#import "MTImageCache.h"
#import "MTLogViewController.h"
#import "MTRelay.h"
#import "MTStarsView.h"
#import <QuartzCore/QuartzCore.h>

@interface MTFilmViewController ()
@property (nonatomic, strong) MTEntry *entry;
@property (nonatomic, strong) MTFilm *film;
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIView *contentView;
@property (nonatomic, strong) MTPosterImageView *poster;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *yearLabel;
@property (nonatomic, strong) MTStarsView *averageStars;
@property (nonatomic, strong) UILabel *averageLabel;
@property (nonatomic, strong) MTStarsView *userStars;
@property (nonatomic, strong) UILabel *userLabel;
@property (nonatomic, strong) UILabel *factsLabel;
@property (nonatomic, strong) UILabel *reviewLabel;
@property (nonatomic, strong) UILabel *synopsisLabel;
@property (nonatomic, strong) UIButton *logButton;
@end

@implementation MTFilmViewController

- (id)initWithEntry:(MTEntry *)entry
{
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _entry = entry;
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor whiteColor];
    self.title = self.entry.title;

    self.scrollView = [[UIScrollView alloc] initWithFrame:self.view.bounds];
    self.scrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.scrollView.backgroundColor = [UIColor whiteColor];
    [self.view addSubview:self.scrollView];

    self.contentView = [[UIView alloc] initWithFrame:CGRectZero];
    self.contentView.backgroundColor = [UIColor whiteColor];
    [self.scrollView addSubview:self.contentView];

    self.poster = [[MTPosterImageView alloc] initWithFrame:CGRectZero];
    self.poster.layer.cornerRadius = 3.0;
    [self.contentView addSubview:self.poster];

    self.titleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.titleLabel.font = [UIFont boldSystemFontOfSize:19.0];
    self.titleLabel.textColor = [MTAppearance ink];
    self.titleLabel.numberOfLines = 0;
    [self.contentView addSubview:self.titleLabel];

    self.yearLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.yearLabel.font = [UIFont systemFontOfSize:13.0];
    self.yearLabel.textColor = [MTAppearance muted];
    [self.contentView addSubview:self.yearLabel];

    self.averageStars = [[MTStarsView alloc] initWithFrame:CGRectZero];
    self.averageStars.starSize = 12.0;
    [self.contentView addSubview:self.averageStars];

    self.averageLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.averageLabel.font = [UIFont systemFontOfSize:12.0];
    self.averageLabel.textColor = [MTAppearance muted];
    [self.contentView addSubview:self.averageLabel];

    self.userStars = [[MTStarsView alloc] initWithFrame:CGRectZero];
    self.userStars.starSize = 12.0;
    [self.contentView addSubview:self.userStars];

    self.userLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.userLabel.font = [UIFont systemFontOfSize:12.0];
    self.userLabel.textColor = [MTAppearance muted];
    self.userLabel.text = @"your rating";
    [self.contentView addSubview:self.userLabel];

    self.factsLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.factsLabel.font = [UIFont systemFontOfSize:12.5];
    self.factsLabel.textColor = [MTAppearance ink];
    self.factsLabel.numberOfLines = 0;
    [self.contentView addSubview:self.factsLabel];

    self.reviewLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.reviewLabel.font = [UIFont italicSystemFontOfSize:13.0];
    self.reviewLabel.textColor = [MTAppearance ink];
    self.reviewLabel.numberOfLines = 0;
    [self.contentView addSubview:self.reviewLabel];

    self.synopsisLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.synopsisLabel.font = [UIFont systemFontOfSize:13.0];
    self.synopsisLabel.textColor = [MTAppearance ink];
    self.synopsisLabel.numberOfLines = 0;
    [self.contentView addSubview:self.synopsisLabel];

    self.logButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.logButton setTitle:@"Log this film" forState:UIControlStateNormal];
    self.logButton.titleLabel.font = [UIFont boldSystemFontOfSize:14.0];
    [self.logButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [self.logButton setBackgroundImage:[self buttonImage] forState:UIControlStateNormal];
    [self.logButton addTarget:self action:@selector(logTapped:) forControlEvents:UIControlEventTouchUpInside];
    [self.contentView addSubview:self.logButton];

    [self populate];
    [self loadFilm];
}

- (UIImage *)buttonImage
{
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(1.0, 38.0), YES, 0.0);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    NSArray *colors = @[
        (__bridge id)[UIColor colorWithRed:0.34 green:0.55 blue:0.74 alpha:1.0].CGColor,
        (__bridge id)[UIColor colorWithRed:0.17 green:0.35 blue:0.55 alpha:1.0].CGColor
    ];
    CGGradientRef gradient = CGGradientCreateWithColors(space, (__bridge CFArrayRef)colors, NULL);
    CGContextDrawLinearGradient(ctx, gradient, CGPointZero, CGPointMake(0.0, 38.0), 0);
    CGGradientRelease(gradient);
    CGColorSpaceRelease(space);
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return [image resizableImageWithCapInsets:UIEdgeInsetsMake(0.0, 0.0, 0.0, 0.0)];
}

- (void)viewWillLayoutSubviews
{
    [super viewWillLayoutSubviews];
    [self layoutContent];
}

- (void)layoutContent
{
    CGFloat viewWidth = CGRectGetWidth(self.view.bounds);
    CGFloat width = MIN(viewWidth, 560.0);
    CGFloat x = (viewWidth - width) * 0.5;

    CGFloat posterW = 96.0;
    CGFloat posterH = 142.0;
    self.poster.frame = CGRectMake(x + 12.0, 12.0, posterW, posterH);

    CGFloat textX = x + 12.0 + posterW + 12.0;
    CGFloat textW = width - (textX - x) - 12.0;

    CGSize titleSize = [self.titleLabel sizeThatFits:CGSizeMake(textW, 200.0)];
    self.titleLabel.frame = CGRectMake(textX, 12.0, textW, titleSize.height);
    self.yearLabel.frame = CGRectMake(textX, CGRectGetMaxY(self.titleLabel.frame) + 2.0, textW, 17.0);

    CGFloat rowY = CGRectGetMaxY(self.yearLabel.frame) + 6.0;
    self.averageStars.frame = CGRectMake(textX, rowY, 68.0, 13.0);
    self.averageLabel.frame = CGRectMake(textX + 73.0, rowY, textW - 73.0, 15.0);

    rowY += 18.0;
    self.userStars.frame = CGRectMake(textX, rowY, 68.0, 13.0);
    self.userLabel.frame = CGRectMake(textX + 73.0, rowY, textW - 73.0, 15.0);

    CGFloat contentBottom = MAX(CGRectGetMaxY(self.poster.frame), rowY + 20.0);
    rowY = contentBottom + 10.0;

    CGSize factsSize = [self.factsLabel sizeThatFits:CGSizeMake(width - 24.0, 300.0)];
    self.factsLabel.frame = CGRectMake(x + 12.0, rowY, width - 24.0, factsSize.height);
    rowY = CGRectGetMaxY(self.factsLabel.frame) + 8.0;

    if (self.reviewLabel.text.length) {
        CGSize reviewSize = [self.reviewLabel sizeThatFits:CGSizeMake(width - 24.0, 400.0)];
        self.reviewLabel.frame = CGRectMake(x + 12.0, rowY, width - 24.0, reviewSize.height);
        rowY = CGRectGetMaxY(self.reviewLabel.frame) + 10.0;
    } else {
        self.reviewLabel.frame = CGRectZero;
    }

    if (self.synopsisLabel.text.length) {
        CGSize synopsisSize = [self.synopsisLabel sizeThatFits:CGSizeMake(width - 24.0, 900.0)];
        self.synopsisLabel.frame = CGRectMake(x + 12.0, rowY, width - 24.0, synopsisSize.height);
        rowY = CGRectGetMaxY(self.synopsisLabel.frame) + 12.0;
    } else {
        self.synopsisLabel.frame = CGRectZero;
    }

    self.logButton.frame = CGRectMake(x + 12.0, rowY, width - 24.0, 38.0);
    rowY = CGRectGetMaxY(self.logButton.frame) + 16.0;

    self.contentView.frame = CGRectMake(0.0, 0.0, viewWidth, rowY);
    self.scrollView.contentSize = CGSizeMake(viewWidth, rowY);
}

- (void)populate
{
    self.titleLabel.text = self.film.title.length ? self.film.title : self.entry.title;
    NSInteger year = self.film.year > 0 ? self.film.year : self.entry.year;
    NSString *runtime = self.film ? [self.film runtimeText] : @"";
    NSMutableArray *meta = [NSMutableArray array];
    if (year > 0) [meta addObject:[NSString stringWithFormat:@"%ld", (long)year]];
    if (runtime.length) [meta addObject:runtime];
    self.yearLabel.text = [meta componentsJoinedByString:@" · "];

    NSString *posterPath = self.film.poster.length ? self.film.poster : self.entry.poster;
    if (!posterPath.length) posterPath = self.film.posterCdn.length ? self.film.posterCdn : self.entry.posterCdn;
    [self.poster setRemoteURL:[MTRelay URLForPath:posterPath]];

    self.averageStars.rating = self.film.rating;
    self.averageLabel.text = self.film.rating > 0.0
        ? [NSString stringWithFormat:@"%.2f avg", self.film.rating]
        : @"no average yet";
    self.userStars.rating = self.entry.rating ? self.entry.rating.doubleValue : 0.0;
    self.userLabel.hidden = !self.entry.rating;

    NSMutableArray *facts = [NSMutableArray array];
    if (self.film.directorsText.length) [facts addObject:self.film.directorsText];
    if (self.film.genres.count) [facts addObject:[self.film.genres componentsJoinedByString:@" · "]];
    if (self.film.ratingCount > 0) {
        [facts addObject:[NSString stringWithFormat:@"%ld ratings", (long)self.film.ratingCount]];
    }
    self.factsLabel.text = [facts componentsJoinedByString:@"\n"];

    self.reviewLabel.text = self.entry.review.length
        ? [NSString stringWithFormat:@"\u201c%@\u201d", self.entry.review]
        : nil;
    self.synopsisLabel.text = self.film.synopsis;

    [self layoutContent];
}

- (void)loadFilm
{
    if (!self.entry.slug.length) return;

    __weak MTFilmViewController *weakSelf = self;
    [[MTRelay sharedRelay] filmWithSlug:self.entry.slug completion:^(id json, NSError *error) {
        MTFilmViewController *strongSelf = weakSelf;
        if (!strongSelf || error) return;
        strongSelf.film = [MTFilm filmWithDictionary:json];
        [strongSelf populate];
    }];
}

- (void)logTapped:(id)sender
{
    MTLogViewController *log = [[MTLogViewController alloc] initWithEntry:self.entry film:self.film];
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:log];
    [MTAppearance styleNavigationBar:nav.navigationBar];
    nav.modalPresentationStyle = UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad
        ? UIModalPresentationFormSheet
        : UIModalPresentationFullScreen;
    [self presentViewController:nav animated:YES completion:nil];
}

@end
