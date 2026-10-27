//
//  MTSearchViewController.m
//  Matinee
//

#import "MTSearchViewController.h"
#import "MTAppearance.h"
#import "MTImageCache.h"
#import "MTLogViewController.h"
#import "MTModels.h"
#import "MTRelay.h"

static NSString *MTSearchString(id value)
{
    return [value isKindOfClass:[NSString class]] ? value : nil;
}

static NSInteger MTSearchInteger(id value)
{
    return [value isKindOfClass:[NSNumber class]] ? [value integerValue] : 0;
}

@interface MTSearchCell : UITableViewCell
@property (nonatomic, strong) MTPosterImageView *poster;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *subLabel;
@end

@implementation MTSearchCell

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        _poster = [[MTPosterImageView alloc] initWithFrame:CGRectZero];
        [self.contentView addSubview:_poster];

        _titleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _titleLabel.font = [UIFont boldSystemFontOfSize:15.0];
        _titleLabel.textColor = [MTAppearance ink];
        [self.contentView addSubview:_titleLabel];

        _subLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _subLabel.font = [MTAppearance smallFont];
        _subLabel.textColor = [MTAppearance muted];
        [self.contentView addSubview:_subLabel];
    }
    return self;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    CGFloat width = CGRectGetWidth(self.contentView.bounds);
    self.poster.frame = CGRectMake(8.0, 8.0, 34.0, 50.0);
    self.titleLabel.frame = CGRectMake(50.0, 10.0, width - 58.0, 20.0);
    self.subLabel.frame = CGRectMake(50.0, 32.0, width - 58.0, 16.0);
}

@end


@interface MTSearchViewController ()
@property (nonatomic, strong) UISearchBar *searchBar;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSArray *results;
@property (nonatomic, strong) UILabel *noteLabel;
@end

@implementation MTSearchViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.title = @"Search";
    self.view.backgroundColor = [UIColor whiteColor];

    self.searchBar = [[UISearchBar alloc] initWithFrame:CGRectMake(0.0, 0.0, CGRectGetWidth(self.view.bounds), 44.0)];
    self.searchBar.delegate = self;
    self.searchBar.placeholder = @"Film title";
    self.searchBar.autoresizingMask = UIViewAutoresizingFlexibleWidth;

    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStylePlain];
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.rowHeight = 66.0;
    self.tableView.separatorColor = [MTAppearance sep];
    self.tableView.tableHeaderView = self.searchBar;
    [self.view addSubview:self.tableView];

    self.noteLabel = [[UILabel alloc] initWithFrame:self.view.bounds];
    self.noteLabel.backgroundColor = [UIColor whiteColor];
    self.noteLabel.textColor = [MTAppearance muted];
    self.noteLabel.font = [MTAppearance bodyFont];
    self.noteLabel.textAlignment = NSTextAlignmentCenter;
    self.noteLabel.numberOfLines = 0;
    self.noteLabel.text = @"Search is powered by TMDB.\nAdd TMDB_API_KEY to the relay to turn it on.";
    self.tableView.backgroundView = self.noteLabel;
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar
{
    [searchBar resignFirstResponder];
    NSString *query = searchBar.text;
    if (!query.length) return;

    self.noteLabel.text = @"Searching\u2026";
    self.tableView.backgroundView = self.noteLabel;

    __weak MTSearchViewController *weakSelf = self;
    [[MTRelay sharedRelay] searchForQuery:query completion:^(id json, NSError *error) {
        MTSearchViewController *strongSelf = weakSelf;
        if (!strongSelf) return;

        if (error) {
            strongSelf.results = @[];
            strongSelf.noteLabel.text = error.localizedDescription;
            strongSelf.tableView.backgroundView = strongSelf.noteLabel;
            [strongSelf.tableView reloadData];
            return;
        }

        NSMutableArray *parsed = [NSMutableArray array];
        NSArray *raw = [json isKindOfClass:[NSDictionary class]] ? json[@"results"] : nil;
        if ([raw isKindOfClass:[NSArray class]]) {
            for (NSDictionary *dict in raw) {
                MTEntry *entry = [[MTEntry alloc] init];
                entry.kind = @"search";
                entry.title = MTSearchString(dict[@"title"]);
                entry.year = MTSearchInteger(dict[@"year"]);
                id tmdb = dict[@"tmdbId"];
                if ([tmdb isKindOfClass:[NSNumber class]]) {
                    entry.tmdbId = [tmdb stringValue];
                } else {
                    entry.tmdbId = MTSearchString(tmdb);
                }
                entry.posterCdn = MTSearchString(dict[@"posterCdn"]);
                entry.poster = MTSearchString(dict[@"poster"]);
                if (entry.title.length) [parsed addObject:entry];
            }
        }

        strongSelf.results = parsed;
        strongSelf.tableView.backgroundView = parsed.count ? nil : strongSelf.noteLabel;
        if (!parsed.count) strongSelf.noteLabel.text = @"No matches.";
        [strongSelf.tableView reloadData];
    }];
}

- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar
{
    searchBar.text = @"";
    [searchBar resignFirstResponder];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return (NSInteger)self.results.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *identifier = @"search";
    MTSearchCell *cell = (MTSearchCell *)[tableView dequeueReusableCellWithIdentifier:identifier];
    if (!cell) {
        cell = [[MTSearchCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:identifier];
    }

    MTEntry *entry = self.results[(NSUInteger)indexPath.row];
    cell.titleLabel.text = entry.title;
    cell.subLabel.text = entry.year > 0
        ? [NSString stringWithFormat:@"%@ \u00b7 Film", [entry yearText]]
        : @"Film";
    NSString *path = entry.poster.length ? entry.poster : entry.posterCdn;
    [cell.poster setRemoteURL:[MTRelay URLForPath:path]];
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    MTEntry *entry = self.results[(NSUInteger)indexPath.row];

    MTLogViewController *log = [[MTLogViewController alloc] initWithEntry:entry film:nil];
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

@end
