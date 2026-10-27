//
//  MTListsViewController.m
//  Matinee
//

#import "MTListsViewController.h"
#import "MTAppearance.h"
#import "MTFilmViewController.h"
#import "MTModels.h"
#import "MTRelay.h"
#import "MTStarsView.h"
#import "MTStore.h"

@interface MTListDetailViewController : UIViewController <UITableViewDataSource, UITableViewDelegate>
- (id)initWithList:(MTEntry *)list;
@end

@interface MTListsViewController ()
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSArray *lists;
@property (nonatomic, strong) UIRefreshControl *refreshControl;
@end

@implementation MTListsViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.title = @"Lists";
    self.view.backgroundColor = [MTAppearance paper];

    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStylePlain];
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.backgroundColor = [UIColor whiteColor];
    self.tableView.separatorColor = [MTAppearance sep];
    [self.view addSubview:self.tableView];

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

- (void)loadLists
{
    __weak MTListsViewController *weakSelf = self;
    [[MTRelay sharedRelay] feedForHandle:[MTStore handle] completion:^(id json, NSError *error) {
        MTListsViewController *strongSelf = weakSelf;
        if (!strongSelf) return;
        [strongSelf.refreshControl endRefreshing];
        if (error || ![json isKindOfClass:[NSDictionary class]]) return;

        NSMutableArray *lists = [NSMutableArray array];
        for (NSDictionary *dict in json[@"items"]) {
            MTEntry *entry = [MTEntry entryWithDictionary:dict];
            if (entry && [entry.kind isEqualToString:@"list"]) {
                [lists addObject:entry];
            }
        }
        strongSelf.lists = lists;
        [strongSelf.tableView reloadData];
    }];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return (NSInteger)self.lists.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *identifier = @"list";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:identifier];
    }
    MTEntry *list = self.lists[(NSUInteger)indexPath.row];
    cell.textLabel.text = list.title;
    cell.textLabel.font = [UIFont boldSystemFontOfSize:15.0];
    cell.textLabel.textColor = [MTAppearance ink];
    cell.detailTextLabel.text = [NSString stringWithFormat:@"%ld films \u00b7 %@",
                                 (long)list.total, list.published.length >= 10 ? [list.published substringToIndex:10] : @""];
    cell.detailTextLabel.font = [MTAppearance smallFont];
    cell.detailTextLabel.textColor = [MTAppearance muted];
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
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

    UITableView *table = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStylePlain];
    table.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    table.dataSource = self;
    table.delegate = self;
    table.backgroundColor = [UIColor whiteColor];
    table.separatorColor = [MTAppearance sep];
    [self.view addSubview:table];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return (NSInteger)self.list.entries.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *identifier = @"list-film";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:identifier];
    }
    MTEntry *entry = self.list.entries[(NSUInteger)indexPath.row];
    cell.textLabel.text = entry.title;
    cell.textLabel.font = [UIFont boldSystemFontOfSize:14.0];
    cell.detailTextLabel.text = [NSString stringWithFormat:@"%@%@",
                                 [entry yearText],
                                 entry.rating ? [NSString stringWithFormat:@" \u00b7 \u2605%.1f", entry.rating.doubleValue] : @""];
    cell.detailTextLabel.font = [MTAppearance smallFont];
    cell.detailTextLabel.textColor = [MTAppearance muted];
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
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
