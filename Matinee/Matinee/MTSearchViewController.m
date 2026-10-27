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
#import <QuartzCore/QuartzCore.h>

static NSString *MTSearchString(id value)
{
    return [value isKindOfClass:[NSString class]] ? value : nil;
}

static NSInteger MTSearchInteger(id value)
{
    return [value isKindOfClass:[NSNumber class]] ? [value integerValue] : 0;
}


@interface MTSearchCell : UITableViewCell
@property (nonatomic, strong) MTCardBackgroundView *card;
@property (nonatomic, strong) MTPosterImageView *poster;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *yearLabel;
@property (nonatomic, strong) UILabel *subLabel;
@property (nonatomic, strong) UILabel *chevronLabel;
- (void)setFirst:(BOOL)first last:(BOOL)last;
@end

@implementation MTSearchCell

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

        _subLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _subLabel.backgroundColor = [UIColor clearColor];
        _subLabel.font = [UIFont systemFontOfSize:12.0];
        _subLabel.textColor = [MTAppearance muted];
        [self.contentView addSubview:_subLabel];

        _chevronLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _chevronLabel.backgroundColor = [UIColor clearColor];
        _chevronLabel.font = [UIFont systemFontOfSize:15.0];
        _chevronLabel.textColor = [UIColor colorWithRed:0.706 green:0.722 blue:0.745 alpha:1.0];
        _chevronLabel.text = @"\u203a";
        _chevronLabel.textAlignment = NSTextAlignmentRight;
        [self.contentView addSubview:_chevronLabel];
    }
    return self;
}

- (void)setFirst:(BOOL)first last:(BOOL)last
{
    self.card.first = first;
    self.card.last = last;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    CGFloat width = CGRectGetWidth(self.contentView.bounds);
    CGFloat textX = 8.0 + 10.0 + 34.0 + 9.0;
    CGFloat right = width - 8.0 - 10.0;

    self.poster.frame = CGRectMake(8.0 + 10.0, 9.0, 34.0, 50.0);

    CGSize yearSize = self.yearLabel.text.length
        ? [self.yearLabel.text sizeWithFont:self.yearLabel.font]
        : CGSizeZero;
    CGFloat yearWidth = ceil(yearSize.width);
    self.yearLabel.frame = CGRectMake(right - 18.0 - yearWidth, 8.0, yearWidth, 17.0);
    self.titleLabel.frame = CGRectMake(textX, 8.0,
                                       MAX(0.0, right - 18.0 - yearWidth - 4.0 - textX), 18.0);
    self.subLabel.frame = CGRectMake(textX, 27.0, right - textX - 18.0, 15.0);
    self.chevronLabel.frame = CGRectMake(right - 14.0, 25.0, 14.0, 18.0);
}

@end


@interface MTSearchViewController () <UITextFieldDelegate>
@property (nonatomic, strong) UIView *searchHeader;
@property (nonatomic, strong) UIView *searchFieldBackground;
@property (nonatomic, strong) UITextField *searchField;
@property (nonatomic, strong) UIButton *goButton;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSArray *results;
@property (nonatomic, strong) UILabel *noteLabel;
@property (nonatomic, strong) UIView *resultsFooter;
@end

@implementation MTSearchViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.title = @"Search";
    self.view.backgroundColor = [MTAppearance groupBackground];

    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStylePlain];
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.backgroundColor = [UIColor colorWithPatternImage:[MTAppearance pinstripeImage]];
    [self.view addSubview:self.tableView];

    self.searchHeader = [[UIView alloc] initWithFrame:CGRectMake(0.0, 0.0, CGRectGetWidth(self.view.bounds), 56.0)];
    self.searchHeader.backgroundColor = [UIColor clearColor];
    self.searchHeader.autoresizingMask = UIViewAutoresizingFlexibleWidth;

    self.searchFieldBackground = [[UIView alloc] initWithFrame:CGRectZero];
    self.searchFieldBackground.backgroundColor = [UIColor whiteColor];
    self.searchFieldBackground.layer.cornerRadius = 20.0;
    self.searchFieldBackground.layer.borderColor =
        [UIColor colorWithRed:0.65 green:0.68 blue:0.71 alpha:1.0].CGColor;
    self.searchFieldBackground.layer.borderWidth = 1.0;
    [self.searchHeader addSubview:self.searchFieldBackground];

    UIImageView *magnifier = [[UIImageView alloc] initWithImage:
        [MTAppearance tabIconForTab:MTTabIconSearch selected:NO]];
    magnifier.frame = CGRectMake(9.0, 11.0, 16.0, 16.0);
    magnifier.contentMode = UIViewContentModeScaleAspectFit;
    [self.searchFieldBackground addSubview:magnifier];

    self.searchField = [[UITextField alloc] initWithFrame:CGRectZero];
    self.searchField.backgroundColor = [UIColor clearColor];
    self.searchField.borderStyle = UITextBorderStyleNone;
    self.searchField.font = [UIFont systemFontOfSize:13.0];
    self.searchField.textColor = [MTAppearance ink];
    self.searchField.placeholder = @"Search films and TV";
    self.searchField.returnKeyType = UIReturnKeySearch;
    self.searchField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    self.searchField.autocorrectionType = UITextAutocorrectionTypeNo;
    self.searchField.clearButtonMode = UITextFieldViewModeWhileEditing;
    self.searchField.delegate = self;
    [self.searchFieldBackground addSubview:self.searchField];

    self.goButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.goButton setTitle:@"Go" forState:UIControlStateNormal];
    self.goButton.titleLabel.font = [UIFont boldSystemFontOfSize:11.0];
    [self.goButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [self.goButton setTitleShadowColor:[UIColor colorWithWhite:0.0 alpha:0.5] forState:UIControlStateNormal];
    self.goButton.titleLabel.shadowOffset = CGSizeMake(0.0, -1.0);
    [self.goButton setBackgroundImage:[MTAppearance actionButtonImage]
                             forState:UIControlStateNormal];
    [self.goButton addTarget:self action:@selector(searchTapped:) forControlEvents:UIControlEventTouchUpInside];
    [self.searchFieldBackground addSubview:self.goButton];

    self.tableView.tableHeaderView = self.searchHeader;

    self.noteLabel = [[UILabel alloc] initWithFrame:self.view.bounds];
    self.noteLabel.backgroundColor = [UIColor clearColor];
    self.noteLabel.textColor = [MTAppearance muted];
    self.noteLabel.font = [MTAppearance bodyFont];
    self.noteLabel.textAlignment = NSTextAlignmentCenter;
    self.noteLabel.numberOfLines = 0;
    self.noteLabel.text = @"Type a title and press Go.\nSearch is powered by TMDB.";
    self.tableView.backgroundView = self.noteLabel;
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];

    CGFloat width = CGRectGetWidth(self.tableView.bounds);
    if (CGRectGetWidth(self.searchHeader.frame) != width) {
        CGRect frame = self.searchHeader.frame;
        frame.size.width = width;
        self.searchHeader.frame = frame;
        self.tableView.tableHeaderView = self.searchHeader;
    }

    self.searchFieldBackground.frame = CGRectMake(8.0, 8.0, width - 16.0, 40.0);

    CGFloat fieldWidth = CGRectGetWidth(self.searchFieldBackground.bounds);
    self.searchField.frame = CGRectMake(31.0, 4.0, fieldWidth - 31.0 - 52.0, 32.0);
    self.goButton.frame = CGRectMake(fieldWidth - 46.0, 7.0, 40.0, 26.0);
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    [textField resignFirstResponder];
    [self performSearch];
    return YES;
}

- (void)searchTapped:(id)sender
{
    [self.searchField resignFirstResponder];
    [self performSearch];
}

- (void)performSearch
{
    NSString *query = [self.searchField.text stringByTrimmingCharactersInSet:
                       [NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (!query.length) return;

    self.results = nil;
    self.tableView.tableFooterView = nil;
    self.noteLabel.text = @"Searching\u2026";
    self.tableView.backgroundView = self.noteLabel;
    [self.tableView reloadData];

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
                NSString *kind = MTSearchString(dict[@"kind"]);
                entry.kind = [kind isEqualToString:@"tv"] ? @"tv" : @"film";
                entry.title = MTSearchString(dict[@"title"]);
                entry.year = MTSearchInteger(dict[@"year"]);
                id rating = dict[@"rating"];
                if ([rating isKindOfClass:[NSNumber class]]) {
                    entry.rating = rating;
                }
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
        [strongSelf updateResultsFooter];
        [strongSelf.tableView reloadData];
    }];
}

- (void)updateResultsFooter
{
    if (!self.results.count) {
        self.tableView.tableFooterView = nil;
        return;
    }

    UIView *footer = [[UIView alloc] initWithFrame:CGRectMake(0.0, 0.0,
                                                              CGRectGetWidth(self.tableView.bounds), 58.0)];
    footer.backgroundColor = [UIColor clearColor];
    UILabel *note = [[UILabel alloc] initWithFrame:CGRectMake(14.0, 8.0,
                                                             CGRectGetWidth(footer.bounds) - 28.0, 44.0)];
    note.backgroundColor = [UIColor clearColor];
    note.font = [MTAppearance smallFont];
    note.textColor = [MTAppearance muted];
    note.textAlignment = NSTextAlignmentCenter;
    note.numberOfLines = 0;
    note.text = @"Tapping a result creates a draft keyed by tmdbID. Letterboxd's importer matches that column directly.";
    [footer addSubview:note];
    self.tableView.tableFooterView = footer;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return (NSInteger)self.results.count;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 68.0;
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
    cell.yearLabel.text = entry.year > 0 ? [entry yearText] : nil;

    NSString *type = [entry.kind isEqualToString:@"tv"] ? @"TV" : @"Film";
    cell.subLabel.text = (entry.rating && entry.rating.doubleValue > 0.0)
        ? [NSString stringWithFormat:@"%@ \u00b7 %.1f", type, entry.rating.doubleValue]
        : type;
    NSString *path = entry.poster.length ? entry.poster : entry.posterCdn;
    [cell.poster setRemoteURL:[MTRelay URLForPath:path]];
    [cell setFirst:indexPath.row == 0
              last:indexPath.row == (NSInteger)self.results.count - 1];
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
