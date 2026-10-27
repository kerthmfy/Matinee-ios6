//
//  MTDiaryViewController.m
//  Matinee
//

#import "MTDiaryViewController.h"
#import "MTAppearance.h"
#import "MTFilmViewController.h"
#import "MTImageCache.h"
#import "MTMarkView.h"
#import "MTModels.h"
#import "MTRelay.h"
#import "MTStarsView.h"
#import "MTStore.h"
#import <QuartzCore/QuartzCore.h>

static NSDateFormatter *MTDiaryISOFormatter(void)
{
    static NSDateFormatter *formatter = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        formatter = [[NSDateFormatter alloc] init];
        [formatter setDateFormat:@"yyyy-MM-dd"];
        [formatter setLocale:[[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"]];
    });
    return formatter;
}

static NSDateFormatter *MTDiaryDisplayFormatter(void)
{
    static NSDateFormatter *formatter = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        formatter = [[NSDateFormatter alloc] init];
        [formatter setDateFormat:@"d MMM yyyy"];
        [formatter setLocale:[[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"]];
    });
    return formatter;
}

static NSString *MTDiaryDateText(NSString *iso)
{
    if (!iso.length) return @"";
    NSDate *date = [MTDiaryISOFormatter() dateFromString:iso];
    return date ? [MTDiaryDisplayFormatter() stringFromDate:date] : iso;
}

static CGFloat MTDiaryTextX(void)          { return 8.0 + 10.0 + 34.0 + 9.0; }
static CGFloat MTDiaryRightInset(void)     { return 8.0 + 10.0; }


@interface MTDiaryCell : UITableViewCell
@property (nonatomic, strong) MTCardBackgroundView *card;
@property (nonatomic, strong) MTPosterImageView *poster;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *yearLabel;
@property (nonatomic, strong) UILabel *dateLabel;
@property (nonatomic, strong) MTStarsView *stars;
@property (nonatomic, strong) UILabel *badgesLabel;
@property (nonatomic, strong) UILabel *reviewLabel;
- (void)configureWithEntry:(MTEntry *)entry;
- (void)setFirst:(BOOL)first last:(BOOL)last;
+ (CGFloat)heightForEntry:(MTEntry *)entry width:(CGFloat)width;
@end

@implementation MTDiaryCell

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
        self.contentView.backgroundColor = [UIColor clearColor];
        self.selectionStyle = UITableViewCellSelectionStyleBlue;

        _card = [[MTCardBackgroundView alloc] initWithFrame:self.bounds];
        _card.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        self.backgroundView = _card;

        _poster = [[MTPosterImageView alloc] initWithFrame:CGRectZero];
        [self.contentView addSubview:_poster];

        _titleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _titleLabel.backgroundColor = [UIColor clearColor];
        _titleLabel.font = [UIFont boldSystemFontOfSize:15.0];
        _titleLabel.textColor = [MTAppearance ink];
        _titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
        [self.contentView addSubview:_titleLabel];

        _yearLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _yearLabel.backgroundColor = [UIColor clearColor];
        _yearLabel.font = [UIFont systemFontOfSize:13.0];
        _yearLabel.textColor = [UIColor colorWithRed:0.486 green:0.486 blue:0.506 alpha:1.0];
        _yearLabel.textAlignment = NSTextAlignmentRight;
        [self.contentView addSubview:_yearLabel];

        _dateLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _dateLabel.backgroundColor = [UIColor clearColor];
        _dateLabel.font = [UIFont systemFontOfSize:10.0];
        _dateLabel.textColor = [UIColor colorWithRed:0.541 green:0.541 blue:0.561 alpha:1.0];
        _dateLabel.textAlignment = NSTextAlignmentRight;
        [self.contentView addSubview:_dateLabel];

        _stars = [[MTStarsView alloc] initWithFrame:CGRectZero];
        _stars.starSize = 10.0;
        [self.contentView addSubview:_stars];

        _badgesLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _badgesLabel.backgroundColor = [UIColor clearColor];
        _badgesLabel.font = [UIFont systemFontOfSize:11.0];
        _badgesLabel.textColor = [MTAppearance ink];
        [self.contentView addSubview:_badgesLabel];

        _reviewLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _reviewLabel.backgroundColor = [UIColor clearColor];
        _reviewLabel.font = [UIFont systemFontOfSize:12.0];
        _reviewLabel.textColor = [UIColor colorWithRed:0.427 green:0.427 blue:0.447 alpha:1.0];
        _reviewLabel.numberOfLines = 2;
        _reviewLabel.lineBreakMode = NSLineBreakByTruncatingTail;
        [self.contentView addSubview:_reviewLabel];
    }
    return self;
}

- (void)prepareForReuse
{
    [super prepareForReuse];
    [self.poster setRemoteURL:nil];
    self.titleLabel.text = nil;
    self.yearLabel.text = nil;
    self.dateLabel.text = nil;
    self.reviewLabel.text = nil;
    self.badgesLabel.text = nil;
    self.stars.rating = 0.0;
}

- (void)configureWithEntry:(MTEntry *)entry
{
    self.titleLabel.text = entry.title;
    self.yearLabel.text = entry.year > 0 ? [entry yearText] : nil;
    self.dateLabel.text = MTDiaryDateText(entry.watchedDate);
    self.stars.rating = entry.rating ? entry.rating.doubleValue : 0.0;

    NSMutableString *badges = [NSMutableString string];
    if (entry.rewatch) [badges appendString:@"\u21bb"];
    if (entry.liked) [badges appendString:@" \u2665"];
    self.badgesLabel.text = badges;

    NSString *review = [entry.review stringByTrimmingCharactersInSet:
                        [NSCharacterSet whitespaceAndNewlineCharacterSet]];
    self.reviewLabel.text = review.length ? review : nil;

    NSString *path = entry.poster.length ? entry.poster : entry.posterCdn;
    [self.poster setRemoteURL:[MTRelay URLForPath:path]];

    self.poster.layer.borderColor = [UIColor colorWithWhite:0.0 alpha:0.10].CGColor;
    self.poster.layer.borderWidth = 0.5;

    [self setNeedsLayout];
}

- (void)setFirst:(BOOL)first last:(BOOL)last
{
    self.card.first = first;
    self.card.last = last;
}

+ (CGFloat)heightForEntry:(MTEntry *)entry width:(CGFloat)width
{
    CGFloat base = 68.0;
    NSString *review = [entry.review stringByTrimmingCharactersInSet:
                        [NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (!review.length) return base;

    CGFloat textWidth = width - MTDiaryTextX() - MTDiaryRightInset();
    CGSize size = [review sizeWithFont:[UIFont systemFontOfSize:12.0]
                     constrainedToSize:CGSizeMake(textWidth, 30.0)
                         lineBreakMode:NSLineBreakByWordWrapping];
    CGFloat height = 43.0 + MIN(ceil(size.height), 30.0) + 9.0;
    return MAX(base, height);
}

- (void)layoutSubviews
{
    [super layoutSubviews];

    CGFloat width = CGRectGetWidth(self.contentView.bounds);
    CGFloat textX = MTDiaryTextX();
    CGFloat right = width - MTDiaryRightInset();

    self.poster.frame = CGRectMake(8.0 + 10.0, 9.0, 34.0, 50.0);

    CGSize yearSize = self.yearLabel.text.length
        ? [self.yearLabel.text sizeWithFont:self.yearLabel.font]
        : CGSizeZero;
    CGFloat yearWidth = ceil(yearSize.width);
    self.yearLabel.frame = CGRectMake(right - yearWidth, 6.0, yearWidth, 17.0);
    self.titleLabel.frame = CGRectMake(textX, 6.0,
                                       MAX(0.0, right - yearWidth - 4.0 - textX), 18.0);

    self.stars.frame = CGRectMake(textX, 27.0, 52.0, 10.0);
    self.badgesLabel.frame = CGRectMake(textX + 56.0, 25.0, 44.0, 14.0);
    self.dateLabel.frame = CGRectMake(right - 68.0, 26.0, 68.0, 13.0);

    self.reviewLabel.frame = CGRectMake(textX, 42.0, right - textX, 31.0);
}

@end


@interface MTDiaryViewController ()
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UIRefreshControl *refreshControl;
@property (nonatomic, strong) MTSectionHeadView *sectionHead;
@property (nonatomic, strong) NSArray *items;
@property (nonatomic, assign) BOOL showedError;
@end

@implementation MTDiaryViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.view.backgroundColor = [MTAppearance groupBackground];

    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStylePlain];
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.backgroundColor = [UIColor colorWithPatternImage:[MTAppearance pinstripeImage]];
    self.tableView.tableFooterView = [[UIView alloc] initWithFrame:CGRectMake(0.0, 0.0, 320.0, 14.0)];
    [self.view addSubview:self.tableView];

    self.sectionHead = [[MTSectionHeadView alloc] initWithTitle:@"Diary"];
    self.tableView.tableHeaderView = self.sectionHead;

    self.refreshControl = [[UIRefreshControl alloc] init];
    [self.refreshControl addTarget:self action:@selector(refreshPulled:) forControlEvents:UIControlEventValueChanged];
    [self.tableView addSubview:self.refreshControl];

    MTMarkView *mark = [[MTMarkView alloc] initWithFrame:CGRectMake(0.0, 0.0, 34.0, 27.0)];
    self.navigationItem.titleView = mark;
    self.navigationItem.backBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Diary"
                                                                             style:UIBarButtonItemStyleBordered
                                                                            target:nil
                                                                            action:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(feedShouldReload:)
                                                 name:MTFeedShouldReloadNotification
                                               object:nil];

    [self loadFeed];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];

    CGFloat width = CGRectGetWidth(self.tableView.bounds);
    if (CGRectGetWidth(self.sectionHead.frame) != width) {
        CGRect frame = self.sectionHead.frame;
        frame.size.width = width;
        self.sectionHead.frame = frame;
        self.tableView.tableHeaderView = self.sectionHead;
    }
}

- (void)feedShouldReload:(NSNotification *)note
{
    [self loadFeed];
}

- (void)refreshPulled:(id)sender
{
    [self loadFeed];
}

- (void)loadFeed
{
    __weak MTDiaryViewController *weakSelf = self;
    [[MTRelay sharedRelay] feedForHandle:[MTStore handle] completion:^(id json, NSError *error) {
        MTDiaryViewController *strongSelf = weakSelf;
        if (!strongSelf) return;
        [strongSelf.refreshControl endRefreshing];

        if (error) {
            [strongSelf showRelayError:error];
            return;
        }
        if (![json isKindOfClass:[NSDictionary class]]) return;

        NSMutableArray *diary = [NSMutableArray array];
        NSInteger rated = 0;
        CGFloat ratingSum = 0.0;
        NSArray *items = json[@"items"];
        if ([items isKindOfClass:[NSArray class]]) {
            for (NSDictionary *dict in items) {
                MTEntry *entry = [MTEntry entryWithDictionary:dict];
                if (entry && [entry.kind isEqualToString:@"diary"]) {
                    [diary addObject:entry];
                    if (entry.rating) {
                        rated++;
                        ratingSum += entry.rating.doubleValue;
                    }
                }
            }
        }

        NSInteger count = (NSInteger)diary.count;
        NSDictionary *counts = json[@"counts"];
        if ([counts isKindOfClass:[NSDictionary class]] && [counts[@"diary"] isKindOfClass:[NSNumber class]]) {
            count = [counts[@"diary"] integerValue];
        }

        NSString *member = json[@"member"];
        if (![member isKindOfClass:[NSString class]] || !member.length) {
            member = [MTStore handle];
        }
        if (!member.length) member = @"matinee";

        NSString *entryWord = count == 1 ? @"entry" : @"entries";
        NSString *average = rated > 0
            ? [NSString stringWithFormat:@"\u2605 %.2f avg", ratingSum / (CGFloat)rated]
            : @"\u2014 avg";
        strongSelf.sectionHead.titleLabel.text =
            [[NSString stringWithFormat:@"%@ \u00b7 %ld %@ \u00b7 %@",
              member, (long)count, entryWord, average] uppercaseString];

        strongSelf.items = diary;
        strongSelf.tableView.backgroundView = nil;
        [strongSelf.tableView reloadData];
    }];
}

- (void)showRelayError:(NSError *)error
{
    if (!self.items.count) {
        UILabel *label = [[UILabel alloc] initWithFrame:self.view.bounds];
        label.backgroundColor = [UIColor clearColor];
        label.textColor = [MTAppearance muted];
        label.font = [MTAppearance bodyFont];
        label.textAlignment = NSTextAlignmentCenter;
        label.numberOfLines = 0;
        label.text = [NSString stringWithFormat:@"Can't reach the relay.\n%@\n\nSet the server in Profile.",
                      [MTStore relayBase]];
        self.tableView.backgroundView = label;
        self.sectionHead.titleLabel.text = @"DIARY OFFLINE";
        return;
    }

    if (self.showedError) return;
    self.showedError = YES;
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Relay unreachable"
                                                    message:error.localizedDescription
                                                   delegate:nil
                                          cancelButtonTitle:@"OK"
                                          otherButtonTitles:nil];
    [alert show];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return (NSInteger)self.items.count;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return [MTDiaryCell heightForEntry:self.items[(NSUInteger)indexPath.row]
                                 width:CGRectGetWidth(tableView.bounds)];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *identifier = @"diary";
    MTDiaryCell *cell = (MTDiaryCell *)[tableView dequeueReusableCellWithIdentifier:identifier];
    if (!cell) {
        cell = [[MTDiaryCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:identifier];
    }
    [cell configureWithEntry:self.items[(NSUInteger)indexPath.row]];
    [cell setFirst:indexPath.row == 0
              last:indexPath.row == (NSInteger)self.items.count - 1];
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    MTEntry *entry = self.items[(NSUInteger)indexPath.row];
    MTFilmViewController *film = [[MTFilmViewController alloc] initWithEntry:entry];
    [self.navigationController pushViewController:film animated:YES];
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
