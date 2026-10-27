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

static NSString *MTFilmRatingCount(NSInteger count)
{
    if (count <= 0) return nil;
    NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
    [formatter setNumberStyle:NSNumberFormatterDecimalStyle];
    return [NSString stringWithFormat:@"%@ ratings", [formatter stringFromNumber:@(count)]];
}

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
@property (nonatomic, strong) UIView *reviewRule;
@property (nonatomic, strong) UIView *synopsisRule;
@property (nonatomic, strong) UIView *logRule;
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
    self.poster.layer.borderColor = [UIColor colorWithWhite:0.0 alpha:0.10].CGColor;
    self.poster.layer.borderWidth = 0.5;
    [self.contentView addSubview:self.poster];

    self.titleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.titleLabel.font = [UIFont boldSystemFontOfSize:19.0];
    self.titleLabel.textColor = [MTAppearance ink];
    self.titleLabel.numberOfLines = 0;
    [self.contentView addSubview:self.titleLabel];

    self.yearLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.yearLabel.font = [UIFont systemFontOfSize:13.0];
    self.yearLabel.textColor = [UIColor colorWithRed:0.467 green:0.467 blue:0.486 alpha:1.0];
    [self.contentView addSubview:self.yearLabel];

    self.averageStars = [[MTStarsView alloc] initWithFrame:CGRectZero];
    self.averageStars.starSize = 12.0;
    [self.contentView addSubview:self.averageStars];

    self.averageLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.averageLabel.font = [UIFont systemFontOfSize:12.0];
    self.averageLabel.textColor = [UIColor colorWithRed:0.420 green:0.420 blue:0.439 alpha:1.0];
    [self.contentView addSubview:self.averageLabel];

    self.userStars = [[MTStarsView alloc] initWithFrame:CGRectZero];
    self.userStars.starSize = 12.0;
    [self.contentView addSubview:self.userStars];

    self.userLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.userLabel.font = [UIFont systemFontOfSize:12.0];
    self.userLabel.textColor = [UIColor colorWithRed:0.420 green:0.420 blue:0.439 alpha:1.0];
    self.userLabel.text = @"your rating";
    [self.contentView addSubview:self.userLabel];

    self.factsLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.factsLabel.font = [UIFont systemFontOfSize:11.5];
    self.factsLabel.textColor = [UIColor colorWithRed:0.361 green:0.361 blue:0.380 alpha:1.0];
    self.factsLabel.numberOfLines = 0;
    [self.contentView addSubview:self.factsLabel];

    self.reviewRule = [[UIView alloc] initWithFrame:CGRectZero];
    self.reviewRule.backgroundColor = [MTAppearance sep];
    [self.contentView addSubview:self.reviewRule];

    self.reviewLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.reviewLabel.font = [UIFont systemFontOfSize:14.0];
    self.reviewLabel.textColor = [UIColor colorWithRed:0.173 green:0.173 blue:0.188 alpha:1.0];
    self.reviewLabel.numberOfLines = 0;
    [self.contentView addSubview:self.reviewLabel];

    self.synopsisRule = [[UIView alloc] initWithFrame:CGRectZero];
    self.synopsisRule.backgroundColor = [MTAppearance sep];
    [self.contentView addSubview:self.synopsisRule];

    self.synopsisLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.synopsisLabel.font = [UIFont systemFontOfSize:13.5];
    self.synopsisLabel.textColor = [UIColor colorWithRed:0.173 green:0.173 blue:0.188 alpha:1.0];
    self.synopsisLabel.numberOfLines = 0;
    [self.contentView addSubview:self.synopsisLabel];

    self.logRule = [[UIView alloc] initWithFrame:CGRectZero];
    self.logRule.backgroundColor = [MTAppearance sep];
    [self.contentView addSubview:self.logRule];

    self.logButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.logButton setTitle:@"Log this film" forState:UIControlStateNormal];
    self.logButton.titleLabel.font = [UIFont boldSystemFontOfSize:14.0];
    [self.logButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [self.logButton setTitleShadowColor:[UIColor colorWithWhite:0.0 alpha:0.5] forState:UIControlStateNormal];
    self.logButton.titleLabel.shadowOffset = CGSizeMake(0.0, -1.0);
    [self.logButton setBackgroundImage:[MTAppearance actionButtonImage] forState:UIControlStateNormal];
    [self.logButton addTarget:self action:@selector(logTapped:) forControlEvents:UIControlEventTouchUpInside];
    [self.contentView addSubview:self.logButton];

    [self installNavigationButtons];
    [self populate];
    [self loadFilm];
}

- (void)installNavigationButtons
{
    NSString *backTitle = @"Back";
    NSArray *stack = self.navigationController.viewControllers;
    if (stack.count >= 2) {
        UIViewController *previous = stack[stack.count - 2];
        if (previous.navigationItem.backBarButtonItem.title.length) {
            backTitle = previous.navigationItem.backBarButtonItem.title;
        } else if (previous.title.length) {
            backTitle = previous.title;
        }
    }

    UIButton *back = [MTAppearance barButtonWithTitle:backTitle
                                                back:YES
                                              target:self
                                              action:@selector(backTapped:)];
    self.navigationItem.hidesBackButton = YES;
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:back];

    UIButton *log = [MTAppearance barButtonWithTitle:@"Log"
                                                back:NO
                                              target:self
                                              action:@selector(logTapped:)];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:log];
}

- (void)backTapped:(id)sender
{
    [self.navigationController popViewControllerAnimated:YES];
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
    self.yearLabel.frame = CGRectMake(textX, CGRectGetMaxY(self.titleLabel.frame) + 1.0, textW, 17.0);

    CGFloat rowY = CGRectGetMaxY(self.yearLabel.frame) + 6.0;
    if (!self.averageStars.hidden) {
        self.averageStars.frame = CGRectMake(textX, rowY, 68.0, 13.0);
        self.averageLabel.frame = CGRectMake(textX + 73.0, rowY - 1.0, textW - 73.0, 15.0);
        rowY += 18.0;
    } else {
        self.averageStars.frame = CGRectZero;
        self.averageLabel.frame = CGRectZero;
    }

    if (!self.userStars.hidden) {
        self.userStars.frame = CGRectMake(textX, rowY, 68.0, 13.0);
        self.userLabel.frame = CGRectMake(textX + 73.0, rowY - 1.0, textW - 73.0, 15.0);
        rowY += 18.0;
    } else {
        self.userStars.frame = CGRectZero;
        self.userLabel.frame = CGRectZero;
    }

    CGSize factsSize = self.factsLabel.text.length
        ? [self.factsLabel sizeThatFits:CGSizeMake(textW, 300.0)]
        : CGSizeZero;
    self.factsLabel.frame = CGRectMake(textX, rowY + 5.0, textW, factsSize.height);
    rowY = CGRectGetMaxY(self.factsLabel.frame);

    CGFloat heroBottom = MAX(CGRectGetMaxY(self.poster.frame), rowY) + 12.0;
    CGFloat ruleX = x + 12.0;
    CGFloat ruleW = width - 24.0;

    self.reviewRule.hidden = !self.reviewLabel.text.length;
    self.reviewRule.frame = CGRectMake(ruleX, heroBottom, ruleW, 1.0);
    rowY = heroBottom + 13.0;

    if (self.reviewLabel.text.length) {
        CGSize reviewSize = [self.reviewLabel sizeThatFits:CGSizeMake(ruleW, 400.0)];
        self.reviewLabel.frame = CGRectMake(ruleX, rowY, ruleW, reviewSize.height);
        rowY = CGRectGetMaxY(self.reviewLabel.frame) + 13.0;
    } else {
        self.reviewLabel.frame = CGRectZero;
    }

    self.synopsisRule.hidden = !self.synopsisLabel.text.length;
    self.synopsisRule.frame = CGRectMake(ruleX, rowY, ruleW, 1.0);
    rowY += 13.0;

    if (self.synopsisLabel.text.length) {
        CGSize synopsisSize = [self.synopsisLabel sizeThatFits:CGSizeMake(ruleW, 900.0)];
        self.synopsisLabel.frame = CGRectMake(ruleX, rowY, ruleW, synopsisSize.height);
        rowY = CGRectGetMaxY(self.synopsisLabel.frame) + 13.0;
    } else {
        self.synopsisLabel.frame = CGRectZero;
    }

    self.logRule.frame = CGRectMake(ruleX, rowY, ruleW, 1.0);
    rowY += 13.0;
    self.logButton.frame = CGRectMake(ruleX, rowY, ruleW, 38.0);
    rowY = CGRectGetMaxY(self.logButton.frame) + 22.0;

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
    self.yearLabel.text = [meta componentsJoinedByString:@" \u00b7 "];

    NSString *posterPath = self.film.poster.length ? self.film.poster : self.entry.poster;
    if (!posterPath.length) posterPath = self.film.posterCdn.length ? self.film.posterCdn : self.entry.posterCdn;
    [self.poster setRemoteURL:[MTRelay URLForPath:posterPath]];

    self.averageStars.hidden = !(self.film.rating > 0.0);
    self.averageLabel.hidden = self.averageStars.hidden;
    self.averageStars.rating = self.film.rating;
    self.averageLabel.text = self.film.rating > 0.0
        ? [NSString stringWithFormat:@"%.2f avg", self.film.rating]
        : @"";

    BOOL hasUserRating = self.entry.rating != nil;
    self.userStars.hidden = !hasUserRating;
    self.userLabel.hidden = !hasUserRating;
    self.userStars.rating = hasUserRating ? self.entry.rating.doubleValue : 0.0;

    NSMutableArray *facts = [NSMutableArray array];
    if (self.film.directorsText.length) [facts addObject:self.film.directorsText];
    if (self.film.genres.count) [facts addObject:[self.film.genres componentsJoinedByString:@" \u00b7 "]];
    NSString *ratingCount = MTFilmRatingCount(self.film.ratingCount);
    if (ratingCount.length) [facts addObject:ratingCount];
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

- (UIInterfaceOrientationMask)supportedInterfaceOrientations
{
    return UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad
        ? UIInterfaceOrientationMaskAll
        : UIInterfaceOrientationMaskPortrait;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)orientation
{
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) return YES;
    return orientation == UIInterfaceOrientationPortrait;
}

@end
