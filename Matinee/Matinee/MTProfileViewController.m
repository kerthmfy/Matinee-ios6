//
//  MTProfileViewController.m
//  Matinee
//
//  Profile and connection settings. The relay owns the Letterboxd session;
//  the phone only stores the public diary handle and the relay address.
//

#import "MTProfileViewController.h"
#import "MTAppearance.h"
#import "MTModels.h"
#import "MTRelay.h"
#import "MTStore.h"
#import <MessageUI/MessageUI.h>
#import <QuartzCore/QuartzCore.h>

typedef NS_ENUM(NSInteger, MTSessionState) {
    MTSessionStateChecking,
    MTSessionStateValid,
    MTSessionStateMissing,
    MTSessionStateExpired,
    MTSessionStateRelayOffline,
    MTSessionStateLetterboxdOffline
};

enum {
    MTProfileAlertHandle = 1,
    MTProfileAlertClear = 2,
    MTProfileAlertServer = 3,
    MTProfileAlertSession = 4
};

static UIColor *MTSessionColor(MTSessionState state)
{
    switch (state) {
        case MTSessionStateValid:
            return [MTAppearance green];
        case MTSessionStateMissing:
            return [UIColor colorWithRed:0.48 green:0.48 blue:0.50 alpha:1.0];
        case MTSessionStateExpired:
            return [UIColor colorWithRed:0.70 green:0.22 blue:0.18 alpha:1.0];
        case MTSessionStateRelayOffline:
        case MTSessionStateLetterboxdOffline:
            return [UIColor colorWithRed:0.64 green:0.36 blue:0.12 alpha:1.0];
        default:
            return [MTAppearance muted];
    }
}

static NSString *MTProfileFeedSource(NSString *source)
{
    if ([source isEqualToString:@"live"]) return @"Live RSS";
    if ([source isEqualToString:@"stale"]) return @"Cached";
    if ([source isEqualToString:@"fixture"]) return @"Sample";
    return @"\u2014";
}


@interface MTProfileHeaderView : UIView
@property (nonatomic, strong) UIView *avatar;
@property (nonatomic, strong) CAGradientLayer *avatarGradient;
@property (nonatomic, strong) UILabel *initialLabel;
@property (nonatomic, strong) UILabel *nameLabel;
@property (nonatomic, strong) UILabel *handleLabel;
@property (nonatomic, strong) NSArray *statValues;
@property (nonatomic, strong) NSArray *statCaptions;
@property (nonatomic, strong) UIView *statsTop;
@property (nonatomic, strong) UIView *statsDividerOne;
@property (nonatomic, strong) UIView *statsDividerTwo;
@property (nonatomic, strong) UIView *bottomBorder;
- (void)updateWithName:(NSString *)name
              subtitle:(NSString *)subtitle
               entries:(NSString *)entries
                 lists:(NSString *)lists
               average:(NSString *)average;
@end


@implementation MTProfileHeaderView

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor whiteColor];

        _avatar = [[UIView alloc] initWithFrame:CGRectZero];
        _avatar.layer.cornerRadius = 6.0;
        _avatar.layer.masksToBounds = YES;

        _avatarGradient = [CAGradientLayer layer];
        _avatarGradient.colors = @[
            (__bridge id)[UIColor colorWithRed:0.33 green:0.44 blue:0.56 alpha:1.0].CGColor,
            (__bridge id)[UIColor colorWithRed:0.14 green:0.22 blue:0.31 alpha:1.0].CGColor
        ];
        _avatarGradient.startPoint = CGPointMake(0.0, 0.0);
        _avatarGradient.endPoint = CGPointMake(1.0, 1.0);
        [_avatar.layer insertSublayer:_avatarGradient atIndex:0];
        [self addSubview:_avatar];

        _initialLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _initialLabel.backgroundColor = [UIColor clearColor];
        _initialLabel.font = [UIFont boldSystemFontOfSize:24.0];
        _initialLabel.textColor = [UIColor whiteColor];
        _initialLabel.textAlignment = NSTextAlignmentCenter;
        _initialLabel.shadowColor = [UIColor colorWithWhite:0.0 alpha:0.45];
        _initialLabel.shadowOffset = CGSizeMake(0.0, -1.0);
        [_avatar addSubview:_initialLabel];

        _nameLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _nameLabel.backgroundColor = [UIColor clearColor];
        _nameLabel.font = [UIFont boldSystemFontOfSize:17.0];
        _nameLabel.textColor = [MTAppearance ink];
        _nameLabel.lineBreakMode = NSLineBreakByTruncatingTail;
        [self addSubview:_nameLabel];

        _handleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _handleLabel.backgroundColor = [UIColor clearColor];
        _handleLabel.font = [UIFont systemFontOfSize:12.0];
        _handleLabel.textColor = [MTAppearance muted];
        _handleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
        [self addSubview:_handleLabel];

        _statValues = @[
            [[UILabel alloc] initWithFrame:CGRectZero],
            [[UILabel alloc] initWithFrame:CGRectZero],
            [[UILabel alloc] initWithFrame:CGRectZero]
        ];
        _statCaptions = @[
            [[UILabel alloc] initWithFrame:CGRectZero],
            [[UILabel alloc] initWithFrame:CGRectZero],
            [[UILabel alloc] initWithFrame:CGRectZero]
        ];
        NSArray *captions = @[@"ENTRIES", @"LISTS", @"AVG RATING"];
        for (NSUInteger i = 0; i < 3; i++) {
            UILabel *value = _statValues[i];
            value.backgroundColor = [UIColor clearColor];
            value.font = [UIFont boldSystemFontOfSize:16.0];
            value.textColor = [MTAppearance ink];
            value.textAlignment = NSTextAlignmentCenter;
            [self addSubview:value];

            UILabel *caption = _statCaptions[i];
            caption.backgroundColor = [UIColor clearColor];
            caption.font = [UIFont systemFontOfSize:10.0];
            caption.textColor = [MTAppearance muted];
            caption.textAlignment = NSTextAlignmentCenter;
            caption.text = captions[i];
            [self addSubview:caption];
        }

        _statsTop = [[UIView alloc] initWithFrame:CGRectZero];
        _statsTop.backgroundColor = [MTAppearance sep];
        [self addSubview:_statsTop];

        _statsDividerOne = [[UIView alloc] initWithFrame:CGRectZero];
        _statsDividerOne.backgroundColor = [MTAppearance sep];
        [self addSubview:_statsDividerOne];

        _statsDividerTwo = [[UIView alloc] initWithFrame:CGRectZero];
        _statsDividerTwo.backgroundColor = [MTAppearance sep];
        [self addSubview:_statsDividerTwo];

        _bottomBorder = [[UIView alloc] initWithFrame:CGRectZero];
        _bottomBorder.backgroundColor = [MTAppearance sep];
        [self addSubview:_bottomBorder];
    }
    return self;
}

- (void)updateWithName:(NSString *)name
              subtitle:(NSString *)subtitle
               entries:(NSString *)entries
                 lists:(NSString *)lists
               average:(NSString *)average
{
    self.nameLabel.text = name.length ? name : @"Matinee";
    self.handleLabel.text = subtitle;

    NSString *trimmed = [self.nameLabel.text stringByTrimmingCharactersInSet:
                         [NSCharacterSet whitespaceAndNewlineCharacterSet]];
    self.initialLabel.text = trimmed.length
        ? [[trimmed substringToIndex:1] uppercaseString]
        : @"?";

    ((UILabel *)self.statValues[0]).text = entries;
    ((UILabel *)self.statValues[1]).text = lists;
    ((UILabel *)self.statValues[2]).text = average;
    [self setNeedsLayout];
}

- (void)layoutSubviews
{
    [super layoutSubviews];

    CGFloat width = CGRectGetWidth(self.bounds);
    CGFloat height = CGRectGetHeight(self.bounds);
    CGFloat statsY = 80.0;

    self.avatar.frame = CGRectMake(12.0, 12.0, 54.0, 54.0);
    self.avatarGradient.frame = self.avatar.bounds;
    self.initialLabel.frame = self.avatar.bounds;
    self.nameLabel.frame = CGRectMake(78.0, 18.0, width - 90.0, 22.0);
    self.handleLabel.frame = CGRectMake(78.0, 41.0, width - 90.0, 16.0);

    self.statsTop.frame = CGRectMake(0.0, statsY, width, 1.0);
    CGFloat column = width / 3.0;
    for (NSUInteger i = 0; i < 3; i++) {
        UILabel *value = self.statValues[i];
        value.frame = CGRectMake(column * i, statsY + 7.0, column, 20.0);
        UILabel *caption = self.statCaptions[i];
        caption.frame = CGRectMake(column * i, statsY + 27.0, column, 14.0);
    }
    self.statsDividerOne.frame = CGRectMake(column, statsY, 1.0, height - statsY);
    self.statsDividerTwo.frame = CGRectMake(column * 2.0, statsY, 1.0, height - statsY);
    self.bottomBorder.frame = CGRectMake(0.0, height - 1.0, width, 1.0);
}

@end


@interface MTProfileStatusCell : UITableViewCell
@property (nonatomic, strong) UIView *dot;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *valueLabel;
@property (nonatomic, strong) UILabel *detailLabel;
- (void)configureWithTitle:(NSString *)title
                    detail:(NSString *)detail
                     value:(NSString *)value
                     color:(UIColor *)color;
@end


@implementation MTProfileStatusCell

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        self.backgroundColor = [UIColor whiteColor];

        _dot = [[UIView alloc] initWithFrame:CGRectZero];
        _dot.layer.cornerRadius = 4.0;
        [self.contentView addSubview:_dot];

        _titleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _titleLabel.backgroundColor = [UIColor clearColor];
        _titleLabel.font = [UIFont boldSystemFontOfSize:14.0];
        _titleLabel.textColor = [MTAppearance ink];
        [self.contentView addSubview:_titleLabel];

        _valueLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _valueLabel.backgroundColor = [UIColor clearColor];
        _valueLabel.font = [UIFont boldSystemFontOfSize:13.0];
        _valueLabel.textAlignment = NSTextAlignmentRight;
        _valueLabel.adjustsFontSizeToFitWidth = YES;
        _valueLabel.minimumScaleFactor = 0.75;
        [self.contentView addSubview:_valueLabel];

        _detailLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _detailLabel.backgroundColor = [UIColor clearColor];
        _detailLabel.font = [UIFont systemFontOfSize:11.0];
        _detailLabel.textColor = [MTAppearance muted];
        _detailLabel.lineBreakMode = NSLineBreakByTruncatingTail;
        [self.contentView addSubview:_detailLabel];
    }
    return self;
}

- (void)configureWithTitle:(NSString *)title
                    detail:(NSString *)detail
                     value:(NSString *)value
                     color:(UIColor *)color
{
    self.titleLabel.text = title;
    self.detailLabel.text = detail;
    self.valueLabel.text = value;
    self.valueLabel.textColor = color;
    self.dot.backgroundColor = color;
    [self setNeedsLayout];
}

- (void)layoutSubviews
{
    [super layoutSubviews];

    CGFloat width = CGRectGetWidth(self.contentView.bounds);
    CGFloat valueWidth = 108.0;

    self.dot.frame = CGRectMake(12.0, 17.0, 8.0, 8.0);
    self.titleLabel.frame = CGRectMake(28.0, 8.0, width - 28.0 - valueWidth - 18.0, 20.0);
    self.valueLabel.frame = CGRectMake(width - valueWidth - 14.0, 9.0, valueWidth, 18.0);
    self.detailLabel.frame = CGRectMake(28.0, 28.0, width - 42.0, 15.0);
}

@end


@interface MTProfileViewController () <UIAlertViewDelegate, MFMailComposeViewControllerDelegate>
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) MTProfileHeaderView *headerView;
@property (nonatomic, copy) NSString *memberName;
@property (nonatomic, copy) NSString *sessionDetail;
@property (nonatomic, copy) NSString *sessionAlertMessage;
@property (nonatomic, copy) NSString *feedSource;
@property (nonatomic, assign) MTSessionState sessionState;
@property (nonatomic, assign) BOOL checkingSession;
@property (nonatomic, assign) BOOL feedLoaded;
@property (nonatomic, assign) NSInteger diaryCount;
@property (nonatomic, assign) NSInteger listCount;
@property (nonatomic, assign) NSInteger ratedCount;
@property (nonatomic, assign) CGFloat averageRating;
@end

@implementation MTProfileViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.title = @"Profile";
    self.view.backgroundColor = [MTAppearance groupBackground];

    self.sessionState = MTSessionStateChecking;
    self.sessionDetail = @"Checking the relay\u2026";

    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStyleGrouped];
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.backgroundColor = [UIColor colorWithPatternImage:[MTAppearance pinstripeImage]];
    self.tableView.separatorColor = [MTAppearance sep];
    self.tableView.rowHeight = 44.0;
    [self.view addSubview:self.tableView];

    self.headerView = [[MTProfileHeaderView alloc] initWithFrame:CGRectMake(0.0, 0.0,
                                                                            CGRectGetWidth(self.view.bounds),
                                                                            134.0)];
    self.headerView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    self.tableView.tableHeaderView = self.headerView;
    [self updateHeader];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(draftsChanged:)
                                                 name:MTDraftsDidChangeNotification
                                               object:nil];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self refreshAll];
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];

    CGFloat width = CGRectGetWidth(self.tableView.bounds);
    if (CGRectGetWidth(self.headerView.frame) != width) {
        CGRect frame = self.headerView.frame;
        frame.size.width = width;
        self.headerView.frame = frame;
        self.tableView.tableHeaderView = self.headerView;
    }
}

- (void)draftsChanged:(NSNotification *)note
{
    [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:2]
                  withRowAnimation:UITableViewRowAnimationNone];
}

#pragma mark - Refresh

- (void)refreshAll
{
    [self checkSessionWithFeedback:NO];
    [self loadHealth];
    [self loadFeedForce:NO];
}

- (void)loadHealth
{
    __weak MTProfileViewController *weakSelf = self;
    [[MTRelay sharedRelay] health:^(id json, NSError *error) {
        MTProfileViewController *strongSelf = weakSelf;
        if (!strongSelf) return;
        if (error || ![json isKindOfClass:[NSDictionary class]]) return;

        NSString *member = json[@"member"];
        if (![MTStore handle].length && [member isKindOfClass:[NSString class]] && member.length) {
            [MTStore setHandle:member];
        }

        NSDictionary *feed = json[@"feed"];
        if ([feed isKindOfClass:[NSDictionary class]]) {
            NSString *source = feed[@"source"];
            if ([source isKindOfClass:[NSString class]] && source.length) {
                strongSelf.feedSource = source;
            }
        }

        [strongSelf updateHeader];
        [strongSelf.tableView reloadSections:[NSIndexSet indexSetWithIndex:1]
                            withRowAnimation:UITableViewRowAnimationNone];
    }];
}

- (void)loadFeedForce:(BOOL)force
{
    __weak MTProfileViewController *weakSelf = self;
    [[MTRelay sharedRelay] feedForHandle:[MTStore handle] refresh:force completion:^(id json, NSError *error) {
        MTProfileViewController *strongSelf = weakSelf;
        if (!strongSelf) return;
        if (error || ![json isKindOfClass:[NSDictionary class]]) return;

        NSString *member = json[@"member"];
        if ([member isKindOfClass:[NSString class]] && member.length) {
            strongSelf.memberName = member;
        }

        NSInteger diary = 0;
        NSInteger lists = 0;
        NSInteger rated = 0;
        CGFloat sum = 0.0;
        NSArray *items = json[@"items"];
        if ([items isKindOfClass:[NSArray class]]) {
            for (id raw in items) {
                if (![raw isKindOfClass:[NSDictionary class]]) continue;
                MTEntry *entry = [MTEntry entryWithDictionary:raw];
                if (!entry) continue;
                if ([entry.kind isEqualToString:@"diary"]) {
                    diary++;
                    if (entry.rating) {
                        rated++;
                        sum += entry.rating.doubleValue;
                    }
                } else if ([entry.kind isEqualToString:@"list"]) {
                    lists++;
                }
            }
        }

        NSDictionary *counts = json[@"counts"];
        if ([counts isKindOfClass:[NSDictionary class]]) {
            id value = counts[@"diary"];
            if ([value isKindOfClass:[NSNumber class]]) diary = [value integerValue];
            value = counts[@"lists"];
            if ([value isKindOfClass:[NSNumber class]]) lists = [value integerValue];
        }

        NSString *source = json[@"source"];
        if ([source isKindOfClass:[NSString class]] && source.length) {
            strongSelf.feedSource = source;
        }

        strongSelf.diaryCount = diary;
        strongSelf.listCount = lists;
        strongSelf.ratedCount = rated;
        strongSelf.averageRating = rated ? sum / (CGFloat)rated : 0.0;
        strongSelf.feedLoaded = YES;
        [strongSelf updateHeader];
        [strongSelf.tableView reloadSections:[NSIndexSet indexSetWithIndex:1]
                            withRowAnimation:UITableViewRowAnimationNone];
    }];
}

- (void)checkSessionWithFeedback:(BOOL)feedback
{
    if (self.checkingSession) return;
    self.checkingSession = YES;
    self.sessionState = MTSessionStateChecking;
    self.sessionDetail = @"Checking the relay\u2026";
    self.sessionAlertMessage = nil;
    [self reloadConnectionSection];

    __weak MTProfileViewController *weakSelf = self;
    [[MTRelay sharedRelay] session:^(id json, NSError *error) {
        MTProfileViewController *strongSelf = weakSelf;
        if (!strongSelf) return;
        strongSelf.checkingSession = NO;

        NSDictionary *dict = [json isKindOfClass:[NSDictionary class]] ? json : nil;
        if (error) {
            strongSelf.sessionState = MTSessionStateRelayOffline;
            strongSelf.sessionDetail = @"The relay did not answer.";
            strongSelf.sessionAlertMessage = error.localizedDescription;
        } else if (!dict) {
            strongSelf.sessionState = MTSessionStateRelayOffline;
            strongSelf.sessionDetail = @"The relay returned an unreadable response.";
            strongSelf.sessionAlertMessage = @"Check the relay address and that npm start is running.";
        } else if (![dict[@"configured"] boolValue]) {
            strongSelf.sessionState = MTSessionStateMissing;
            strongSelf.sessionDetail = @"Add LB_SESSION_COOKIE on the relay.";
            strongSelf.sessionAlertMessage = @"No LB_SESSION_COOKIE is set on the relay. Add one with npm run cookie, restart the relay, then check again.";
        } else if ([dict[@"signedIn"] boolValue]) {
            strongSelf.sessionState = MTSessionStateValid;
            strongSelf.sessionDetail = @"Write path ready.";
            strongSelf.sessionAlertMessage = @"Letterboxd recognized the relay's cookie. The log sheet can post diary entries.";
        } else if ([dict[@"reason"] isEqualToString:@"network"]) {
            strongSelf.sessionState = MTSessionStateLetterboxdOffline;
            strongSelf.sessionDetail = @"The relay cannot reach Letterboxd.";
            strongSelf.sessionAlertMessage = @"The relay could not reach Letterboxd. Check the Mac's network and try again.";
        } else {
            strongSelf.sessionState = MTSessionStateExpired;
            strongSelf.sessionDetail = @"Refresh the cookie on the relay.";
            strongSelf.sessionAlertMessage = @"Letterboxd showed the signed-out page. Refresh the relay's cookie from a signed-in browser, restart the relay, then check again.";
        }

        [strongSelf reloadConnectionSection];
        if (feedback) [strongSelf showSessionAlert];
    }];
}

- (void)reloadConnectionSection
{
    [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:0]
                  withRowAnimation:UITableViewRowAnimationNone];
}

- (void)updateHeader
{
    NSString *handle = [MTStore handle];
    NSString *name = self.memberName.length ? self.memberName : (handle.length ? handle : @"Matinee");
    NSString *subtitle = handle.length
        ? [NSString stringWithFormat:@"@%@ \u00b7 letterboxd.com", handle]
        : @"No diary handle set";

    NSString *entries = self.feedLoaded ? [NSString stringWithFormat:@"%ld", (long)self.diaryCount] : @"\u2014";
    NSString *lists = self.feedLoaded ? [NSString stringWithFormat:@"%ld", (long)self.listCount] : @"\u2014";
    NSString *average = self.feedLoaded && self.ratedCount > 0
        ? [NSString stringWithFormat:@"%.2f", self.averageRating]
        : @"\u2014";

    [self.headerView updateWithName:name subtitle:subtitle entries:entries lists:lists average:average];
}

#pragma mark - Table

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 4;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (section == 0) return 4;
    if (section == 1) return 3;
    if (section == 2) return 3;
    return 1;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return (indexPath.section == 0 && indexPath.row == 0) ? 54.0 : 44.0;
}

- (NSString *)footerTextForSection:(NSInteger)section
{
    if (section == 0) {
        return @"The relay holds the Letterboxd session. The phone only talks to the relay.";
    }
    if (section == 1) {
        return @"The diary is the public RSS feed. The handle is separate from the relay's session.";
    }
    if (section == 2) {
        return @"Drafts stay on this phone. Export them for letterboxd.com/import, or send from the log sheet.";
    }
    return @"Matinee is an unofficial client. Not affiliated with Letterboxd. Posters and metadata belong to their owners.";
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    return 26.0;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    UIView *view = [[UIView alloc] initWithFrame:CGRectMake(0.0, 0.0, CGRectGetWidth(tableView.bounds), 26.0)];
    view.backgroundColor = [UIColor clearColor];

    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(14.0, 8.0, CGRectGetWidth(view.bounds) - 28.0, 15.0)];
    label.backgroundColor = [UIColor clearColor];
    label.font = [MTAppearance groupTitleFont];
    label.textColor = [UIColor colorWithRed:0.30 green:0.34 blue:0.39 alpha:1.0];
    label.shadowColor = [UIColor colorWithWhite:1.0 alpha:0.7];
    label.shadowOffset = CGSizeMake(0.0, 1.0);

    NSArray *titles = @[@"CONNECTION", @"DIARY", @"DRAFTS", @"ABOUT"];
    label.text = titles[(NSUInteger)section];
    [view addSubview:label];
    return view;
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section
{
    NSString *text = [self footerTextForSection:section];
    CGSize size = [text sizeWithFont:[MTAppearance smallFont]
                   constrainedToSize:CGSizeMake(CGRectGetWidth(tableView.bounds) - 32.0, MAXFLOAT)
                       lineBreakMode:NSLineBreakByWordWrapping];
    return size.height + 12.0;
}

- (UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section
{
    NSString *text = [self footerTextForSection:section];
    CGFloat height = [self tableView:tableView heightForFooterInSection:section];
    UIView *view = [[UIView alloc] initWithFrame:CGRectMake(0.0, 0.0, CGRectGetWidth(tableView.bounds), height)];
    view.backgroundColor = [UIColor clearColor];

    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(16.0, 6.0,
                                                               CGRectGetWidth(view.bounds) - 32.0,
                                                               height - 12.0)];
    label.backgroundColor = [UIColor clearColor];
    label.font = [MTAppearance smallFont];
    label.textColor = [MTAppearance muted];
    label.numberOfLines = 0;
    label.lineBreakMode = NSLineBreakByWordWrapping;
    label.text = text;
    [view addSubview:label];
    return view;
}

- (UITableViewCell *)valueCellWithTitle:(NSString *)title
                                  detail:(NSString *)detail
                                tappable:(BOOL)tappable
{
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1
                                                           reuseIdentifier:nil];
    cell.textLabel.text = title;
    cell.textLabel.font = [UIFont systemFontOfSize:15.0];
    cell.textLabel.textColor = [MTAppearance ink];
    cell.detailTextLabel.text = detail ?: @"";
    cell.detailTextLabel.font = [UIFont systemFontOfSize:12.0];
    cell.detailTextLabel.textColor = [MTAppearance muted];
    cell.selectionStyle = tappable ? UITableViewCellSelectionStyleBlue : UITableViewCellSelectionStyleNone;
    cell.accessoryType = tappable ? UITableViewCellAccessoryDisclosureIndicator : UITableViewCellAccessoryNone;
    return cell;
}

- (NSString *)sessionValue
{
    switch (self.sessionState) {
        case MTSessionStateValid: return @"Cookie valid";
        case MTSessionStateMissing: return @"No cookie";
        case MTSessionStateExpired: return @"Cookie expired";
        case MTSessionStateRelayOffline: return @"Relay offline";
        case MTSessionStateLetterboxdOffline: return @"LB unreachable";
        default: return @"Checking\u2026";
    }
}

- (NSString *)relayDisplay
{
    NSString *base = [MTStore relayBase];
    if ([base hasPrefix:@"http://"]) base = [base substringFromIndex:7];
    if ([base hasPrefix:@"https://"]) base = [base substringFromIndex:8];
    return base;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == 0 && indexPath.row == 0) {
        MTProfileStatusCell *cell = [[MTProfileStatusCell alloc] initWithStyle:UITableViewCellStyleDefault
                                                                reuseIdentifier:nil];
        [cell configureWithTitle:@"Letterboxd session"
                          detail:self.sessionDetail
                           value:[self sessionValue]
                           color:MTSessionColor(self.sessionState)];
        return cell;
    }

    if (indexPath.section == 0) {
        if (indexPath.row == 1) {
            return [self valueCellWithTitle:@"Check session" detail:nil tappable:YES];
        }
        if (indexPath.row == 2) {
            return [self valueCellWithTitle:@"Refresh cookie\u2026" detail:nil tappable:YES];
        }
        return [self valueCellWithTitle:@"Relay" detail:[self relayDisplay] tappable:YES];
    }

    if (indexPath.section == 1) {
        if (indexPath.row == 0) {
            NSString *handle = [MTStore handle];
            return [self valueCellWithTitle:@"Diary handle"
                                      detail:handle.length ? [@"@" stringByAppendingString:handle] : @"Not set"
                                    tappable:YES];
        }
        if (indexPath.row == 1) {
            return [self valueCellWithTitle:@"Refresh diary" detail:@"RSS" tappable:YES];
        }
        return [self valueCellWithTitle:@"Feed source" detail:MTProfileFeedSource(self.feedSource) tappable:NO];
    }

    if (indexPath.section == 2) {
        NSArray *drafts = [MTStore drafts];
        if (indexPath.row == 0) {
            return [self valueCellWithTitle:@"Saved drafts"
                                      detail:[NSString stringWithFormat:@"%lu", (unsigned long)drafts.count]
                                    tappable:NO];
        }
        if (indexPath.row == 1) {
            UITableViewCell *cell = [self valueCellWithTitle:@"Export CSV"
                                                      detail:drafts.count ? @"Email or copy" : @""
                                                    tappable:drafts.count > 0];
            if (!drafts.count) cell.textLabel.textColor = [UIColor lightGrayColor];
            return cell;
        }
        UITableViewCell *cell = [self valueCellWithTitle:@"Clear drafts" detail:@"" tappable:drafts.count > 0];
        if (drafts.count) {
            cell.textLabel.textColor = [UIColor colorWithRed:0.64 green:0.20 blue:0.17 alpha:1.0];
        } else {
            cell.textLabel.textColor = [UIColor lightGrayColor];
        }
        return cell;
    }

    NSString *version = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"] ?: @"1.0";
    NSString *build = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"];
    NSString *detail = build.length ? [NSString stringWithFormat:@"%@ (%@)", version, build] : version;
    return [self valueCellWithTitle:@"Version" detail:detail tappable:NO];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    if (indexPath.section == 0) {
        if (indexPath.row == 1) {
            [self checkSessionWithFeedback:YES];
        } else if (indexPath.row == 2) {
            [self showCookieHelp];
        } else if (indexPath.row == 3) {
            [self showServerAlert];
        }
        return;
    }

    if (indexPath.section == 1) {
        if (indexPath.row == 0) {
            [self showHandleAlert];
        } else if (indexPath.row == 1) {
            [self refreshDiary];
        }
        return;
    }

    if (indexPath.section == 2) {
        NSArray *drafts = [MTStore drafts];
        if (!drafts.count) return;
        if (indexPath.row == 1) {
            [self exportDrafts:drafts];
        } else if (indexPath.row == 2) {
            [self confirmClear];
        }
    }
}

- (void)refreshDiary
{
    [[NSNotificationCenter defaultCenter] postNotificationName:MTFeedShouldReloadNotification object:nil];
    [self loadFeedForce:YES];
}

#pragma mark - Session copy

- (void)showSessionAlert
{
    NSString *title;
    switch (self.sessionState) {
        case MTSessionStateValid: title = @"Session valid"; break;
        case MTSessionStateMissing: title = @"No session cookie"; break;
        case MTSessionStateExpired: title = @"Session expired"; break;
        case MTSessionStateLetterboxdOffline: title = @"Letterboxd unreachable"; break;
        case MTSessionStateRelayOffline: title = @"Relay unreachable"; break;
        default: title = @"Checking"; break;
    }

    NSString *message = self.sessionAlertMessage.length
        ? self.sessionAlertMessage
        : @"Checking the relay\u2026";

    BOOL canRefresh = self.sessionState == MTSessionStateMissing ||
                      self.sessionState == MTSessionStateExpired;
    UIAlertView *alert = nil;
    if (canRefresh) {
        alert = [[UIAlertView alloc] initWithTitle:title
                                           message:message
                                          delegate:self
                                 cancelButtonTitle:@"OK"
                                 otherButtonTitles:@"Refresh cookie\u2026", nil];
    } else {
        alert = [[UIAlertView alloc] initWithTitle:title
                                           message:message
                                          delegate:self
                                 cancelButtonTitle:@"OK"
                                 otherButtonTitles:nil];
    }
    alert.tag = MTProfileAlertSession;
    [alert show];
}

- (void)showCookieHelp
{
    UIAlertView *alert = [[UIAlertView alloc]
        initWithTitle:@"Refresh the relay session"
              message:@"The relay holds the Letterboxd session; the phone never receives it.\n\n"
                      @"On the Mac: sign in at letterboxd.com, copy the full Cookie request header, then run:\n\n"
                      @"pbpaste | npm run cookie\n\n"
                      @"Restart the relay, then tap Check session."
             delegate:nil
    cancelButtonTitle:@"OK"
    otherButtonTitles:nil];
    [alert show];
}

#pragma mark - Alerts

- (void)showHandleAlert
{
    NSString *handle = [MTStore handle];
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Diary handle"
                                                    message:@"The public handle used for the RSS diary. This is not a Letterboxd sign-in."
                                                   delegate:self
                                          cancelButtonTitle:@"Cancel"
                                          otherButtonTitles:@"Save", nil];
    alert.alertViewStyle = UIAlertViewStylePlainTextInput;
    alert.tag = MTProfileAlertHandle;
    UITextField *field = [alert textFieldAtIndex:0];
    field.text = handle ?: @"";
    field.autocapitalizationType = UITextAutocapitalizationTypeNone;
    field.autocorrectionType = UITextAutocorrectionTypeNo;
    field.placeholder = @"yourname";
    [alert show];
}

- (void)showServerAlert
{
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Relay server"
                                                    message:@"Base URL of the Node relay on your network."
                                                   delegate:self
                                          cancelButtonTitle:@"Cancel"
                                          otherButtonTitles:@"Save", nil];
    alert.alertViewStyle = UIAlertViewStylePlainTextInput;
    alert.tag = MTProfileAlertServer;
    UITextField *field = [alert textFieldAtIndex:0];
    field.text = [MTStore relayBase];
    field.keyboardType = UIKeyboardTypeURL;
    field.autocapitalizationType = UITextAutocapitalizationTypeNone;
    field.autocorrectionType = UITextAutocorrectionTypeNo;
    [alert show];
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (buttonIndex == 0) return;

    if (alertView.tag == MTProfileAlertHandle) {
        NSString *input = [[alertView textFieldAtIndex:0].text stringByTrimmingCharactersInSet:
                           [NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (!input.length) return;
        [self connectInput:input];
    } else if (alertView.tag == MTProfileAlertClear) {
        [MTStore clearDrafts];
        [self.tableView reloadData];
    } else if (alertView.tag == MTProfileAlertServer) {
        NSString *server = [[alertView textFieldAtIndex:0].text stringByTrimmingCharactersInSet:
                            [NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (!server.length) return;
        [MTStore setRelayBase:server];
        self.memberName = nil;
        self.feedSource = nil;
        self.feedLoaded = NO;
        self.diaryCount = 0;
        self.listCount = 0;
        self.ratedCount = 0;
        self.averageRating = 0.0;
        [self updateHeader];
        [self.tableView reloadData];
        [self refreshAll];
    } else if (alertView.tag == MTProfileAlertSession && buttonIndex == 1) {
        [self showCookieHelp];
    }
}

- (void)connectInput:(NSString *)input
{
    __weak MTProfileViewController *weakSelf = self;
    [[MTRelay sharedRelay] connectInput:input completion:^(id json, NSError *error) {
        MTProfileViewController *strongSelf = weakSelf;
        if (!strongSelf) return;

        if (error) {
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Handle not saved"
                                                            message:error.localizedDescription
                                                           delegate:nil
                                                  cancelButtonTitle:@"OK"
                                                  otherButtonTitles:nil];
            [alert show];
            return;
        }

        if (![json isKindOfClass:[NSDictionary class]]) return;
        NSString *handle = json[@"handle"];
        if (![handle isKindOfClass:[NSString class]] || !handle.length) return;

        [MTStore setHandle:handle];
        [strongSelf updateHeader];
        [strongSelf.tableView reloadData];
        [[NSNotificationCenter defaultCenter] postNotificationName:MTFeedShouldReloadNotification object:nil];
        [strongSelf loadFeedForce:YES];

        NSDictionary *counts = [json[@"counts"] isKindOfClass:[NSDictionary class]] ? json[@"counts"] : nil;
        NSString *message = counts
            ? [NSString stringWithFormat:@"@%@ \u00b7 %ld entries, %ld lists.",
               handle,
               (long)[counts[@"diary"] integerValue],
               (long)[counts[@"lists"] integerValue]]
            : [NSString stringWithFormat:@"@%@ saved.", handle];
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Handle saved"
                                                        message:message
                                                       delegate:nil
                                              cancelButtonTitle:@"OK"
                                              otherButtonTitles:nil];
        [alert show];
    }];
}

- (void)confirmClear
{
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Clear drafts?"
                                                    message:@"This removes every CSV row saved on this device."
                                                   delegate:self
                                          cancelButtonTitle:@"Cancel"
                                          otherButtonTitles:@"Clear", nil];
    alert.tag = MTProfileAlertClear;
    [alert show];
}

#pragma mark - CSV

- (NSString *)csvForDrafts:(NSArray *)drafts
{
    NSMutableString *csv = [NSMutableString stringWithString:
        @"LetterboxdURI,tmdbID,imdbID,Title,Year,Directors,Rating,Rating10,WatchedDate,Rewatch,Tags,Review\r\n"];
    for (MTDraft *draft in drafts) {
        [csv appendString:[draft csvRow]];
        [csv appendString:@"\r\n"];
    }
    return csv;
}

- (void)exportDrafts:(NSArray *)drafts
{
    NSString *csv = [self csvForDrafts:drafts];
    NSData *data = [csv dataUsingEncoding:NSUTF8StringEncoding];

    if ([MFMailComposeViewController canSendMail]) {
        MFMailComposeViewController *mail = [[MFMailComposeViewController alloc] init];
        mail.mailComposeDelegate = self;
        [mail setSubject:@"Matinee drafts"];
        [mail setMessageBody:
            @"Attach this CSV at letterboxd.com/import.\n\n"
            @"Ratings are half-stars. Rewatches are marked Yes. "
            @"Nothing is posted until you finish the import."
            isHTML:NO];
        [mail addAttachmentData:data mimeType:@"text/csv" fileName:@"matinee-drafts.csv"];
        [self presentViewController:mail animated:YES completion:nil];
        return;
    }

    [[UIPasteboard generalPasteboard] setString:csv];
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"CSV copied"
                                                    message:@"Mail is not set up on this device, so the CSV is on the pasteboard. Paste it into a file, then import it at letterboxd.com/import."
                                                   delegate:nil
                                          cancelButtonTitle:@"OK"
                                          otherButtonTitles:nil];
    [alert show];
}

- (void)mailComposeController:(MFMailComposeViewController *)controller
          didFinishWithResult:(MFMailComposeResult)result
                        error:(NSError *)error
{
    [self dismissViewControllerAnimated:YES completion:nil];
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
