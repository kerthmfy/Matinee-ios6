//
//  MTListsViewController.m
//  Matinee
//

#import "MTListsViewController.h"
#import "MTAppearance.h"
#import "MTFilmViewController.h"
#import "MTModels.h"
#import "MTRelay.h"
#import "MTStore.h"

static NSDateFormatter *MTListISOFormatter(void)
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

static NSDateFormatter *MTListDisplayFormatter(void)
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

static NSString *MTListDateText(NSString *published)
{
    if (published.length < 10) return @"";
    NSString *day = [published substringToIndex:10];
    NSDate *date = [MTListISOFormatter() dateFromString:day];
    return date ? [MTListDisplayFormatter() stringFromDate:date] : day;
}

static UILabel *MTListEmptyLabel(UIView *host, NSString *text)
{
    UILabel *label = [[UILabel alloc] initWithFrame:host.bounds];
    label.backgroundColor = [UIColor clearColor];
    label.textColor = [MTAppearance muted];
    label.font = [MTAppearance bodyFont];
    label.textAlignment = NSTextAlignmentCenter;
    label.numberOfLines = 0;
    label.text = text;
    return label;
}


@interface MTListDetailViewController : UIViewController <UITableViewDataSource, UITableViewDelegate>
- (id)initWithList:(MTEntry *)list;
@end


@interface MTListRowCell : UITableViewCell
@property (nonatomic, strong) MTCardBackgroundView *card;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *subLabel;
@property (nonatomic, strong) UILabel *chevronLabel;
- (void)setFirst:(BOOL)first last:(BOOL)last;
@end

@implementation MTListRowCell

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

        _titleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _titleLabel.backgroundColor = [UIColor clearColor];
        _titleLabel.font = [UIFont boldSystemFontOfSize:15.0];
        _titleLabel.textColor = [MTAppearance ink];
        _titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
        [self.contentView addSubview:_titleLabel];

        _subLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _subLabel.backgroundColor = [UIColor clearColor];
        _subLabel.font = [UIFont systemFontOfSize:12.0];
        _subLabel.textColor = [MTAppearance muted];
        _subLabel.lineBreakMode = NSLineBreakByTruncatingTail;
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
    CGFloat left = 8.0 + 10.0;
    CGFloat right = width - 8.0 - 10.0;

    self.titleLabel.frame = CGRectMake(left, 8.0, right - left - 16.0, 18.0);
    self.subLabel.frame = CGRectMake(left, 27.0, right - left - 16.0, 15.0);
    self.chevronLabel.frame = CGRectMake(right - 14.0, 17.0, 14.0, 18.0);
}

@end


@interface MTListsViewController ()
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSArray *lists;
@property (nonatomic, strong) UIRefreshControl *refreshControl;
@property (nonatomic, strong) MTSectionHeadView *sectionHead;
@end

@implementation MTListsViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.title = @"Lists";
    self.view.backgroundColor = [MTAppearance groupBackground];

    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStylePlain];
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.backgroundColor = [UIColor colorWithPatternImage:[MTAppearance pinstripeImage]];
    self.tableView.tableFooterView = [[UIView alloc] initWithFrame:CGRectMake(0.0, 0.0, 320.0, 14.0)];
    [self.view addSubview:self.tableView];

    self.sectionHead = [[MTSectionHeadView alloc] initWithTitle:@"Lists"];
    self.tableView.tableHeaderView = self.sectionHead;

    self.refreshControl = [[UIRefreshControl alloc] init];
    [self.refreshControl addTarget:self action:@selector(loadLists) forControlEvents:UIControlEventValueChanged];
    [self.tableView addSubview:self.refreshControl];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(loadLists)
                                                 name:MTFeedShouldReloadNotification
                                               object:nil];

    [self loadLists];
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

- (void)loadLists
{
    __weak MTListsViewController *weakSelf = self;
    [[MTRelay sharedRelay] feedForHandle:[MTStore handle] completion:^(id json, NSError *error) {
        MTListsViewController *strongSelf = weakSelf;
        if (!strongSelf) return;
        [strongSelf.refreshControl endRefreshing];
        if (error || ![json isKindOfClass:[NSDictionary class]]) {
            if (!strongSelf.lists.count) {
                strongSelf.tableView.backgroundView =
                    MTListEmptyLabel(strongSelf.view,
                                     @"Can't reach the relay.\nCheck the server in Profile.");
                strongSelf.sectionHead.titleLabel.text = @"LISTS OFFLINE";
            }
            return;
        }

        NSMutableArray *lists = [NSMutableArray array];
        for (NSDictionary *dict in json[@"items"]) {
            MTEntry *entry = [MTEntry entryWithDictionary:dict];
            if (entry && [entry.kind isEqualToString:@"list"]) {
                [lists addObject:entry];
            }
        }
        strongSelf.lists = lists;
        strongSelf.sectionHead.titleLabel.text =
            [[NSString stringWithFormat:@"%ld %@", (long)lists.count,
              lists.count == 1 ? @"list" : @"lists"] uppercaseString];
        strongSelf.tableView.backgroundView = lists.count
            ? nil
            : MTListEmptyLabel(strongSelf.view, @"No public lists in this feed.");
        [strongSelf.tableView reloadData];
    }];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return (NSInteger)self.lists.count;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 52.0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *identifier = @"list";
    MTListRowCell *cell = (MTListRowCell *)[tableView dequeueReusableCellWithIdentifier:identifier];
    if (!cell) {
        cell = [[MTListRowCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:identifier];
    }

    MTEntry *list = self.lists[(NSUInteger)indexPath.row];
    NSInteger shown = (NSInteger)list.entries.count;
    NSInteger total = list.total > 0 ? list.total : shown;
    NSString *date = MTListDateText(list.published);

    cell.titleLabel.text = list.title;
    cell.subLabel.text = date.length
        ? [NSString stringWithFormat:@"%ld of %ld films \u00b7 %@", (long)shown, (long)total, date]
        : [NSString stringWithFormat:@"%ld of %ld films", (long)shown, (long)total];
    [cell setFirst:indexPath.row == 0
              last:indexPath.row == (NSInteger)self.lists.count - 1];
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    MTEntry *list = self.lists[(NSUInteger)indexPath.row];
    MTListDetailViewController *detail = [[MTListDetailViewController alloc] initWithList:list];
    [self.navigationController pushViewController:detail animated:YES];
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations
{
    return UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad
        ? UIInterfaceOrientationMaskAll
        : UIInterfaceOrientationMaskPortrait;
}

@end


@interface MTListDetailViewController ()
@property (nonatomic, strong) MTEntry *list;
@property (nonatomic, strong) UIView *headerView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *subtitleLabel;
@property (nonatomic, strong) UIView *rule;
@property (nonatomic, strong) UITableView *tableView;
@end

@implementation MTListDetailViewController

- (id)initWithList:(MTEntry *)list
{
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _list = list;
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.title = self.list.title;
    self.view.backgroundColor = [UIColor whiteColor];

    self.headerView = [[UIView alloc] initWithFrame:CGRectMake(0.0, 0.0, CGRectGetWidth(self.view.bounds), 86.0)];
    self.headerView.backgroundColor = [UIColor whiteColor];
    self.headerView.autoresizingMask = UIViewAutoresizingFlexibleWidth;

    self.titleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.titleLabel.backgroundColor = [UIColor clearColor];
    self.titleLabel.font = [UIFont boldSystemFontOfSize:19.0];
    self.titleLabel.textColor = [MTAppearance ink];
    self.titleLabel.numberOfLines = 2;
    self.titleLabel.text = self.list.title;
    [self.headerView addSubview:self.titleLabel];

    self.subtitleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.subtitleLabel.backgroundColor = [UIColor clearColor];
    self.subtitleLabel.font = [UIFont systemFontOfSize:13.0];
    self.subtitleLabel.textColor = [UIColor colorWithRed:0.467 green:0.467 blue:0.486 alpha:1.0];
    [self.headerView addSubview:self.subtitleLabel];

    NSInteger shown = (NSInteger)self.list.entries.count;
    NSInteger total = self.list.total > 0 ? self.list.total : shown;
    self.subtitleLabel.text = [NSString stringWithFormat:@"%ld of %ld films shown in RSS",
                               (long)shown, (long)total];

    self.rule = [[UIView alloc] initWithFrame:CGRectZero];
    self.rule.backgroundColor = [MTAppearance sep];
    [self.headerView addSubview:self.rule];

    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStylePlain];
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.backgroundColor = [UIColor whiteColor];
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.tableHeaderView = self.headerView;
    [self.view addSubview:self.tableView];

    if (total > shown) {
        UIView *footer = [[UIView alloc] initWithFrame:CGRectMake(0.0, 0.0, CGRectGetWidth(self.view.bounds), 58.0)];
        footer.backgroundColor = [UIColor whiteColor];
        UILabel *note = [[UILabel alloc] initWithFrame:CGRectMake(12.0, 10.0,
                                                                  CGRectGetWidth(footer.bounds) - 24.0, 40.0)];
        note.backgroundColor = [UIColor clearColor];
        note.font = [MTAppearance smallFont];
        note.textColor = [MTAppearance muted];
        note.numberOfLines = 0;
        note.text = [NSString stringWithFormat:
                     @"The RSS feed carries the first %ld titles. The remaining %ld need Letterboxd's list page.",
                     (long)shown, (long)(total - shown)];
        [footer addSubview:note];
        self.tableView.tableFooterView = footer;
    }
}

- (void)viewWillLayoutSubviews
{
    [super viewWillLayoutSubviews];

    CGFloat width = CGRectGetWidth(self.tableView.bounds);
    if (CGRectGetWidth(self.headerView.frame) != width) {
        CGRect frame = self.headerView.frame;
        frame.size.width = width;
        self.headerView.frame = frame;
        self.tableView.tableHeaderView = self.headerView;
    }

    CGFloat headerWidth = CGRectGetWidth(self.headerView.bounds);
    self.titleLabel.frame = CGRectMake(12.0, 10.0, headerWidth - 24.0, 46.0);
    self.subtitleLabel.frame = CGRectMake(12.0, 57.0, headerWidth - 24.0, 16.0);
    self.rule.frame = CGRectMake(12.0, 85.0, headerWidth - 24.0, 1.0);
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return (NSInteger)self.list.entries.count;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 48.0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *identifier = @"list-film";
    MTListRowCell *cell = (MTListRowCell *)[tableView dequeueReusableCellWithIdentifier:identifier];
    if (!cell) {
        cell = [[MTListRowCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:identifier];
    }

    MTEntry *entry = self.list.entries[(NSUInteger)indexPath.row];
    cell.titleLabel.text = entry.title;
    NSString *subtitle = entry.year > 0 ? [entry yearText] : nil;
    if (entry.rating) {
        subtitle = subtitle.length
            ? [NSString stringWithFormat:@"%@ \u00b7 \u2605%.1f", subtitle, entry.rating.doubleValue]
            : [NSString stringWithFormat:@"\u2605%.1f", entry.rating.doubleValue];
    }
    cell.subLabel.text = subtitle;
    [cell setFirst:indexPath.row == 0
              last:indexPath.row == (NSInteger)self.list.entries.count - 1];
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    MTEntry *entry = self.list.entries[(NSUInteger)indexPath.row];
    MTFilmViewController *film = [[MTFilmViewController alloc] initWithEntry:entry];
    [self.navigationController pushViewController:film animated:YES];
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations
{
    return UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad
        ? UIInterfaceOrientationMaskAll
        : UIInterfaceOrientationMaskPortrait;
}

@end
