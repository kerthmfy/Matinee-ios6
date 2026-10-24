//
//  MTSearchViewController.m
//  Matinee
//

#import "MTSearchViewController.h"
#import "MTEntry.h"
#import "MTSecureClient.h"

@interface MTSearchViewController () <UISearchBarDelegate, UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, strong) UISearchBar *searchBar;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSArray *results;
@property (nonatomic, strong) UILabel *noteLabel;
@end

@implementation MTSearchViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Search";
    self.view.backgroundColor = [UIColor whiteColor];
    
    self.searchBar = [[UISearchBar alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 44)];
    self.searchBar.delegate = self;
    self.searchBar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    self.searchBar.placeholder = @"Search films on Letterboxd";
    [self.view addSubview:self.searchBar];
    
    self.tableView = [[UITableView alloc] initWithFrame:CGRectMake(0, 44, self.view.bounds.size.width, self.view.bounds.size.height - 44) style:UITableViewStylePlain];
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    [self.view addSubview:self.tableView];
    
    self.noteLabel = [[UILabel alloc] initWithFrame:self.tableView.bounds];
    self.noteLabel.textAlignment = NSTextAlignmentCenter;
    self.noteLabel.textColor = [UIColor grayColor];
    self.noteLabel.font = [UIFont systemFontOfSize:14];
}

- (void)dealloc {
    self.searchBar.delegate = nil;
    self.tableView.dataSource = nil;
    self.tableView.delegate = nil;
    [super dealloc];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar
{
    [searchBar resignFirstResponder];
    NSString *query = searchBar.text;
    if (!query.length) return;

    self.noteLabel.text = @"Searching\u2026";
    self.tableView.backgroundView = self.noteLabel;

    NSString *encodedQuery = [query stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    NSString *path = [NSString stringWithFormat:@"/search/%@/", encodedQuery];

    __block MTSearchViewController *safeSelf = self;
    
    [MTSecureClient sendRequestToHost:@"letterboxd.com"
                                 path:path
                           completion:^(NSData *data, NSError *connectionError) {
        
        MTSearchViewController *strongSelf = safeSelf;
        if (!strongSelf) return;

        if (connectionError || !data) {
            strongSelf.results = @[];
            strongSelf.noteLabel.text = connectionError ? connectionError.localizedDescription : @"Search failed.";
            strongSelf.tableView.backgroundView = strongSelf.noteLabel;
            [strongSelf.tableView reloadData];
            return;
        }

        NSError *jsonError = nil;
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];

        NSMutableArray *parsed = [NSMutableArray array];
        NSArray *raw = [json isKindOfClass:[NSDictionary class]] ? json[@"results"] : nil;
        if ([raw isKindOfClass:[NSArray class]]) {
            for (NSDictionary *dict in raw) {
                MTEntry *entry = [MTEntry entryWithDictionary:dict];
                if (entry && entry.title.length) [parsed addObject:entry];
            }
        }

        strongSelf.results = parsed;
        strongSelf.tableView.backgroundView = parsed.count ? nil : strongSelf.noteLabel;
        if (!parsed.count) strongSelf.noteLabel.text = @"No matches.";
        [strongSelf.tableView reloadData];
    }];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.results.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellIdentifier = @"SearchCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellIdentifier];
    }
    
    MTEntry *entry = self.results[indexPath.row];
    cell.textLabel.text = entry.title;
    cell.detailTextLabel.text = entry.year > 0 ? [NSString stringWithFormat:@"%ld", (long)entry.year] : @"";
    return cell;
}

@end
