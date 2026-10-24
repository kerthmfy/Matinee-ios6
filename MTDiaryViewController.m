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
#import "MTStarsView.h"
#import "MTStore.h"

@interface MTDiaryCell : UITableViewCell
@property (nonatomic, strong) MTPosterImageView *poster;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *dateLabel;
@property (nonatomic, strong) MTStarsView *stars;
@property (nonatomic, strong) UILabel *badgesLabel;
@property (nonatomic, strong) UILabel *reviewLabel;
- (void)configureWithEntry:(MTEntry *)entry;
+ (CGFloat)heightForEntry:(MTEntry *)entry;
@end

@implementation MTDiaryCell

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.backgroundColor = [UIColor whiteColor];
        self.selectionStyle = UITableViewCellSelectionStyleBlue;

        _poster = [[MTPosterImageView alloc] initWithFrame:CGRectZero];
        [self.contentView addSubview:_poster];

        _titleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _titleLabel.backgroundColor = [UIColor clearColor];
        _titleLabel.font = [UIFont boldSystemFontOfSize:16.0];
        _titleLabel.textColor = [MTAppearance ink];
        _titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
        [self.contentView addSubview:_titleLabel];

        _dateLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _dateLabel.backgroundColor = [UIColor clearColor];
        _dateLabel.font = [MTAppearance smallFont];
        _dateLabel.textColor = [MTAppearance muted];
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
        _reviewLabel.textColor = [MTAppearance muted];
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
    self.dateLabel.text = nil;
    self.reviewLabel.text = nil;
    self.badgesLabel.text = nil;
    self.stars.rating = 0.0;
}

- (void)configureWithEntry:(MTEntry *)entry
{
    self.titleLabel.text = entry.year > 0
        ? [NSString stringWithFormat:@"%@  %@", entry.title, [entry yearText]]
        : entry.title;
    self.dateLabel.text = entry.watchedDate ?: @"";
    self.stars.rating = entry.rating ? entry.rating.doubleValue : 0.0;

    NSMutableString *badges = [NSMutableString string];
    if (entry.rewatch) [badges appendString:@"\u21bb"];
    if (entry.liked) [badges appendString:@"\u2665"];
    self.badgesLabel.text = badges;

    NSString *review = [entry.review stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    self.reviewLabel.text = review.length ? review : nil;

    // Direct CDN image loading without relay
    NSString *path = entry.poster.length ? entry.poster : entry.posterCdn;
    if (path.length) {
        NSString *imageURLString = [NSString stringWithFormat:@"https://a.ltrbxd.com/resized/%@", path];
        [self.poster setRemoteURL:[NSURL URLWithString:imageURLString]];
    } else {
        [self.poster setRemoteURL:nil];
    }

    [self setNeedsLayout];
}

+ (CGFloat)heightForEntry:(MTEntry *)entry
{
    NSString *review = [entry.review stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    return review.length ? 80.0 : 58.0;
}

- (void)layoutSubviews
{
    [super layoutSubviews];

    CGFloat width = CGRectGetWidth(self.contentView.bounds);
    self.poster.frame = CGRectMake(8.0, 8.0, 34.0, 50.0);

    CGFloat textX = 50.0;
    self.titleLabel.frame = CGRectMake(textX, 5.0, width - textX - 76.0, 20.0);
    self.dateLabel.frame = CGRectMake(width - 74.0, 29.0, 66.0, 14.0);
    self.stars.frame = CGRectMake(textX, 25.0, 58.0, 12.0);
    self.badgesLabel.frame = CGRectMake(textX + 62.0, 24.0, 46.0, 15.0);
    self.reviewLabel.frame = CGRectMake(textX, 42.0, width - textX - 8.0, 32.0);
}

@end


@interface MTDiaryViewController () <UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UIRefreshControl *refreshControl;
@property (nonatomic, strong) NSArray *items;
@property (nonatomic, assign) BOOL showedError;
@end

@implementation MTDiaryViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.view.backgroundColor = [MTAppearance paper];

    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStylePlain];
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.rowHeight = 78.0;
    self.tableView.separatorColor = [MTAppearance sep];
    self.tableView.backgroundColor = [UIColor whiteColor];
    [self.view addSubview:self.tableView];

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

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [super dealloc];
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
    NSString *handle = [MTStore handle];
    if (!handle.length) {
        [self.refreshControl endRefreshing];
        return;
    }

    NSString *urlString = [NSString stringWithFormat:@"https://letterboxd.com/%@/diary/", handle];
    NSURL *url = [NSURL URLWithString:urlString];
    NSURLRequest *request = [NSURLRequest requestWithURL:url];

    __block MTDiaryViewController *weakSelf = self;
    [NSURLConnection sendAsynchronousRequest:request
                                       queue:[NSOperationQueue mainQueue]
                           completionHandler:^(NSURLResponse *response, NSData *data, NSError *connectionError) {
        [weakSelf.refreshControl endRefreshing];
        
        if (connectionError) {
            [weakSelf showNetworkError:connectionError];
            return;
        }
        
        NSError *jsonError = nil;
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
        if (jsonError || !json) {
            [weakSelf showNetworkError:jsonError];
            return;
        }
        
        // Assuming the json contains an array/dictionary mapping to MTEntry items
        // Example: weakSelf.items = [MTEntry entriesFromJSON:json[@"entries"]];
        [weakSelf.tableView reloadData];
    }];
}

- (void)showNetworkError:(NSError *)error
{
    if (!self.items.count) {
        UILabel *label = [[UILabel alloc] initWithFrame:self.view.bounds];
        label.backgroundColor = [MTAppearance paper];
        label.textColor = [MTAppearance muted];
        label.font = [MTAppearance bodyFont];
        label.textAlignment = NSTextAlignmentCenter;
        label.numberOfLines = 0;
        label.text = @"Can't reach Letterboxd.\nPlease check your connection or handle.";
        self.tableView.backgroundView = label;
        return;
    }

    if (self.showedError) return;
    self.showedError = YES;
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Connection Error"
                                                    message:error ? error.localizedDescription : @"Failed to load diary."
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
    return [MTDiaryCell heightForEntry:self.items[(NSUInteger)indexPath.row]];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *identifier = @"diary";
    MTDiaryCell *cell = (MTDiaryCell *)[tableView dequeueReusableCellWithIdentifier:identifier];
    if (!cell) {
        cell = [[MTDiaryCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:identifier];
    }
    [cell configureWithEntry:self.items[(NSUInteger)indexPath.row]];
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