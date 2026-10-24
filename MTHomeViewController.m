//
//  MTHomeViewController.m
//  Matinee
//

#import "MTHomeViewController.h"
#import "MTFeedModels.h"
#import "MTFeedService.h"
#import "MTHomeTheme.h"
#import "MTPosterStripView.h"
#import <QuartzCore/QuartzCore.h>
#import <math.h>

#pragma mark - row bookkeeping

typedef enum {
    MTHomeRowKindHeader = 0,
    MTHomeRowKindStrip,
    MTHomeRowKindReview,
    MTHomeRowKindPlaceholder
} MTHomeRowKind;

@interface MTHomeRow : NSObject
@property (nonatomic, retain) UIView *view;
@property (nonatomic, assign) MTHomeRowKind kind;
@property (nonatomic, assign) BOOL showsByline;
@end

@implementation MTHomeRow
- (void)dealloc
{
    [_view release];
    [super dealloc];
}
@end

#pragma mark - segmented header

@protocol MTHomeSegmentedBarDelegate <NSObject>
- (void)segmentedBarDidChangeSelection:(id)bar;
@end

@interface MTHomeSegmentedBar : UIView {
    NSArray *_titles;
    NSMutableArray *_buttons;
    UIView *_underline;
    UIView *_hairline;
}
@property (nonatomic, assign) id <MTHomeSegmentedBarDelegate> delegate;
@property (nonatomic, assign) NSInteger selectedIndex;
- (id)initWithTitles:(NSArray *)titles;
- (void)layoutForWidth:(CGFloat)width;
- (void)updateButtonSelection;
- (void)positionUnderline;
@end

@implementation MTHomeSegmentedBar

@synthesize delegate = _delegate;
@synthesize selectedIndex = _selectedIndex;

- (id)initWithTitles:(NSArray *)titles
{
    self = [super initWithFrame:CGRectZero];
    if (self) {
        self.backgroundColor = MTHomeBackgroundColor();
        _titles = [titles copy];
        _buttons = [[NSMutableArray alloc] init];

        NSUInteger i = 0;
        for (i = 0; i < _titles.count; i++) {
            UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
            [button setTitle:[_titles objectAtIndex:i] forState:UIControlStateNormal];
            [button setTitleColor:MTHomeSecondaryTextColor() forState:UIControlStateNormal];
            [button setTitleColor:MTHomeTextColor() forState:UIControlStateSelected];
            button.titleLabel.font = [UIFont systemFontOfSize:14.0f];
            button.tag = (NSInteger)i;
            [button addTarget:self
                       action:@selector(buttonTapped:)
             forControlEvents:UIControlEventTouchUpInside];
            [self addSubview:button];
            [_buttons addObject:button];
        }

        _underline = [[UIView alloc] initWithFrame:CGRectZero];
        _underline.backgroundColor = MTHomeGreenColor();
        [self addSubview:_underline];

        _hairline = [[UIView alloc] initWithFrame:CGRectZero];
        _hairline.backgroundColor = MTHomeSeparatorColor();
        [self addSubview:_hairline];

        _selectedIndex = 0;
        [self updateButtonSelection];
    }
    return self;
}

- (void)dealloc
{
    [_titles release];
    [_buttons release];
    [_underline release];
    [_hairline release];
    [super dealloc];
}

- (void)buttonTapped:(UIButton *)sender
{
    if (sender.tag == _selectedIndex) return;

    _selectedIndex = sender.tag;
    [self updateButtonSelection];
    [self positionUnderline];

    if ([_delegate respondsToSelector:@selector(segmentedBarDidChangeSelection:)]) {
        [_delegate segmentedBarDidChangeSelection:self];
    }
}

- (void)updateButtonSelection
{
    UIButton *button = nil;
    for (button in _buttons) {
        button.selected = (button.tag == _selectedIndex);
    }
}

- (void)positionUnderline
{
    if (_selectedIndex < 0 || (NSUInteger)_selectedIndex >= _buttons.count) return;

    UIButton *button = [_buttons objectAtIndex:(NSUInteger)_selectedIndex];
    CGRect frame = button.frame;
    _underline.frame = CGRectMake(CGRectGetMidX(frame) - 18.0f,
                                  CGRectGetHeight(self.bounds) - 3.0f,
                                  36.0f, 3.0f);
}

- (void)layoutForWidth:(CGFloat)width
{
    CGFloat height = CGRectGetHeight(self.bounds);
    NSUInteger count = _buttons.count;
    if (count == 0) return;

    CGFloat each = floorf(width / (CGFloat)count);
    NSUInteger i = 0;
    for (i = 0; i < count; i++) {
        UIButton *button = [_buttons objectAtIndex:i];
        button.frame = CGRectMake(each * (CGFloat)i, 0.0f, each, height - 3.0f);
    }

    _hairline.frame = CGRectMake(0.0f, height - 1.0f, width, 1.0f);
    [self positionUnderline];
}

@end

#pragma mark - section header

@interface MTSectionHeader : UIView {
    UILabel *_titleLabel;
    UILabel *_chevronLabel;
}
- (id)initWithTitle:(NSString *)title;
- (void)layoutForWidth:(CGFloat)width;
@end

@implementation MTSectionHeader

- (id)initWithTitle:(NSString *)title
{
    self = [super initWithFrame:CGRectZero];
    if (self) {
        _titleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _titleLabel.text = title;
        _titleLabel.font = [UIFont boldSystemFontOfSize:17.0f];
        _titleLabel.textColor = MTHomeTextColor();
        _titleLabel.backgroundColor = [UIColor clearColor];
        [self addSubview:_titleLabel];

        _chevronLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _chevronLabel.text = @"\u203A";
        _chevronLabel.font = [UIFont boldSystemFontOfSize:22.0f];
        _chevronLabel.textColor = MTHomeSecondaryTextColor();
        _chevronLabel.textAlignment = NSTextAlignmentRight;
        _chevronLabel.backgroundColor = [UIColor clearColor];
        [self addSubview:_chevronLabel];
    }
    return self;
}

- (void)dealloc
{
    [_titleLabel release];
    [_chevronLabel release];
    [super dealloc];
}

- (void)layoutForWidth:(CGFloat)width
{
    CGFloat height = CGRectGetHeight(self.bounds);
    CGFloat inset = MTHomeScreenInset();

    _titleLabel.frame = CGRectMake(inset, 0.0f, width - (inset * 2.0f) - 24.0f, height);
    _chevronLabel.frame = CGRectMake(width - inset - 24.0f, 0.0f, 24.0f, height);
}

@end

#pragma mark - review row

@interface MTReviewRowView : UIView {
    UIImageView *_poster;
    UILabel *_nameLabel;
    UILabel *_starsLabel;
    UILabel *_snippetLabel;
}
- (void)configureWithItem:(MTFeedItem *)item;
- (void)layoutForWidth:(CGFloat)width;
@end

@implementation MTReviewRowView

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = MTHomeBackgroundColor();

        _poster = [[UIImageView alloc] initWithFrame:CGRectZero];
        _poster.backgroundColor = MTHomeSurfaceColor();
        _poster.contentMode = UIViewContentModeScaleAspectFill;
        _poster.clipsToBounds = YES;
        _poster.layer.cornerRadius = 3.0f;
        [self addSubview:_poster];

        _nameLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _nameLabel.font = [UIFont boldSystemFontOfSize:13.0f];
        _nameLabel.textColor = MTHomeTextColor();
        _nameLabel.backgroundColor = [UIColor clearColor];
        _nameLabel.lineBreakMode = NSLineBreakByTruncatingTail;
        [self addSubview:_nameLabel];

        _starsLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _starsLabel.font = [UIFont systemFontOfSize:11.0f];
        _starsLabel.textColor = MTHomeGreenColor();
        _starsLabel.backgroundColor = [UIColor clearColor];
        [self addSubview:_starsLabel];

        _snippetLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _snippetLabel.font = [UIFont systemFontOfSize:12.0f];
        _snippetLabel.textColor = MTHomeSecondaryTextColor();
        _snippetLabel.backgroundColor = [UIColor clearColor];
        _snippetLabel.numberOfLines = 2;
        [self addSubview:_snippetLabel];
    }
    return self;
}

- (void)dealloc
{
    [_poster release];
    [_nameLabel release];
    [_starsLabel release];
    [_snippetLabel release];
    [super dealloc];
}

- (void)configureWithItem:(MTFeedItem *)item
{
    MTLoadImage(MTPosterURLString(item.posterPath), _poster);

    NSString *name = item.reviewerName.length ? item.reviewerName : @"friend";
    if (item.yearText.length) {
        _nameLabel.text = [NSString stringWithFormat:@"%@ \u00B7 %@ (%@)",
                           name, item.title, item.yearText];
    } else {
        _nameLabel.text = [NSString stringWithFormat:@"%@ \u00B7 %@", name, item.title];
    }

    _starsLabel.text = (item.rating > 0.0f) ? MTStarsString(item.rating) : @"";
    _snippetLabel.text = item.reviewSnippet;

    [self setNeedsLayout];
}

- (void)layoutForWidth:(CGFloat)width
{
    CGFloat inset = MTHomeScreenInset();

    _poster.frame = CGRectMake(inset, 8.0f, 44.0f, 66.0f);

    CGFloat textX = inset + 44.0f + 12.0f;
    CGFloat textWidth = width - textX - inset;
    if (textWidth < 0.0f) textWidth = 0.0f;

    _nameLabel.frame = CGRectMake(textX, 7.0f, textWidth, 16.0f);
    _starsLabel.frame = CGRectMake(textX, 25.0f, textWidth, 12.0f);
    _snippetLabel.frame = CGRectMake(textX, 41.0f, textWidth, 34.0f);
}

@end

#pragma mark - controller

@interface MTHomeViewController () <MTHomeSegmentedBarDelegate> {
    MTHomeSegmentedBar *_bar;
    UIScrollView *_scrollView;
    UIView *_contentView;
    NSMutableArray *_rows;
    UILabel *_placeholderLabel;
    UILabel *_statusLabel;
    UIRefreshControl *_refreshControl;
    MTFeedService *_service;
    BOOL _loading;
}
- (void)rebuildContent;
- (void)addRowView:(UIView *)view
              kind:(MTHomeRowKind)kind
      showsByline:(BOOL)showsByline;
- (void)showPlaceholder:(NSString *)text;
- (CGFloat)heightForRow:(MTHomeRow *)row width:(CGFloat)width;
- (void)layoutRowsForWidth:(CGFloat)viewWidth;
- (void)loadFeed;
- (void)refreshPulled:(id)sender;
- (void)statusTapped:(id)sender;
@end

@implementation MTHomeViewController

@synthesize sections = _sections;

- (id)init
{
    return [self initWithSections:nil];
}

- (id)initWithSections:(NSArray *)sections
{
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _sections = [sections retain];
        _rows = [[NSMutableArray alloc] init];
        self.title = @"Matinee";
    }
    return self;
}

- (void)dealloc
{
    [_bar release];
    [_scrollView release];
    [_contentView release];
    [_rows release];
    [_sections release];
    [_placeholderLabel release];
    [_statusLabel release];
    [_refreshControl release];
    [_service release];
    [super dealloc];
}

- (void)setSections:(NSArray *)sections
{
    if (_sections == sections) return;

    [_sections release];
    _sections = [sections retain];

    if ([self isViewLoaded]) {
        [self rebuildContent];
    }
}

- (void)reload
{
    [self loadFeed];
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.view.backgroundColor = MTHomeBackgroundColor();

    _bar = [[MTHomeSegmentedBar alloc] initWithTitles:
            [NSArray arrayWithObjects:@"Films", @"Reviews", @"Lists", @"Journal", nil]];
    _bar.delegate = self;
    [self.view addSubview:_bar];

    _scrollView = [[UIScrollView alloc] initWithFrame:CGRectZero];
    _scrollView.backgroundColor = MTHomeBackgroundColor();
    _scrollView.alwaysBounceVertical = YES;
    _scrollView.showsVerticalScrollIndicator = NO;
    [self.view addSubview:_scrollView];

    _contentView = [[UIView alloc] initWithFrame:CGRectZero];
    _contentView.backgroundColor = MTHomeBackgroundColor();
    [_scrollView addSubview:_contentView];

    _placeholderLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _placeholderLabel.font = [UIFont systemFontOfSize:14.0f];
    _placeholderLabel.textColor = MTHomeSecondaryTextColor();
    _placeholderLabel.backgroundColor = [UIColor clearColor];
    _placeholderLabel.textAlignment = NSTextAlignmentCenter;
    _placeholderLabel.numberOfLines = 0;
    _placeholderLabel.hidden = YES;
    [_contentView addSubview:_placeholderLabel];

    _statusLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _statusLabel.font = [UIFont systemFontOfSize:14.0f];
    _statusLabel.textColor = MTHomeSecondaryTextColor();
    _statusLabel.backgroundColor = [UIColor clearColor];
    _statusLabel.textAlignment = NSTextAlignmentCenter;
    _statusLabel.numberOfLines = 0;
    _statusLabel.hidden = YES;
    _statusLabel.userInteractionEnabled = YES;
    [self.view addSubview:_statusLabel];

    UITapGestureRecognizer *tap =
        [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(statusTapped:)];
    [_statusLabel addGestureRecognizer:tap];
    [tap release];

    _refreshControl = [[UIRefreshControl alloc] init];
    [_refreshControl addTarget:self
                        action:@selector(refreshPulled:)
              forControlEvents:UIControlEventValueChanged];
    [_scrollView addSubview:_refreshControl];

    _service = [[MTFeedService sharedService] retain];

    if (_sections) {
        [self rebuildContent];
    } else {
        [self loadFeed];
    }
}

- (void)viewWillLayoutSubviews
{
    [super viewWillLayoutSubviews];

    CGFloat width = CGRectGetWidth(self.view.bounds);
    CGFloat height = CGRectGetHeight(self.view.bounds);
    CGFloat barHeight = MTHomeBarHeight();

    _bar.frame = CGRectMake(0.0f, 0.0f, width, barHeight);
    [_bar layoutForWidth:width];

    _scrollView.frame = CGRectMake(0.0f, barHeight, width, height - barHeight);

    _statusLabel.frame = CGRectMake(24.0f, barHeight + 40.0f, width - 48.0f, 120.0f);

    [self layoutRowsForWidth:width];
}

#pragma mark - loading

- (void)loadFeed
{
    if (_loading) {
        [_refreshControl endRefreshing];
        return;
    }

    _loading = YES;
    _statusLabel.hidden = NO;
    _statusLabel.text = @"Loading your feed\u2026";

    MTHomeViewController *controller = self;
    [_service loadFeedWithCompletion:^(NSArray *sections, NSError *error) {
        controller->_loading = NO;
        [controller->_refreshControl endRefreshing];

        if (error || !sections.count) {
            controller->_statusLabel.hidden = NO;
            NSString *message = error ? [error localizedDescription] : @"No friend activity found.";
            controller->_statusLabel.text =
                [NSString stringWithFormat:@"%@\n\nTap to retry.", message];
            controller.sections = nil;
            [controller.view setNeedsLayout];
            return;
        }

        controller->_statusLabel.hidden = YES;
        controller.sections = sections;
        [controller.view setNeedsLayout];
    }];
}

- (void)refreshPulled:(id)sender
{
    (void)sender;
    [self loadFeed];
}

- (void)statusTapped:(id)sender
{
    (void)sender;
    if (_statusLabel.hidden || _loading) return;
    [self loadFeed];
}

#pragma mark - content

- (void)addRowView:(UIView *)view kind:(MTHomeRowKind)kind showsByline:(BOOL)showsByline
{
    MTHomeRow *row = [[MTHomeRow alloc] init];
    row.view = view;
    row.kind = kind;
    row.showsByline = showsByline;

    [_contentView addSubview:view];
    [_rows addObject:row];
    [row release];
}

- (void)rebuildContent
{
    MTHomeRow *row = nil;
    for (row in _rows) {
        [row.view removeFromSuperview];
    }
    [_rows removeAllObjects];

    _placeholderLabel.hidden = YES;

    NSInteger tab = _bar.selectedIndex;

    if (tab == 0) {
        for (MTFeedSection *section in _sections) {
            MTSectionHeader *header = [[MTSectionHeader alloc] initWithTitle:section.title];
            [self addRowView:header kind:MTHomeRowKindHeader showsByline:NO];
            [header release];

            MTPosterStripView *strip = [[MTPosterStripView alloc] initWithFrame:CGRectZero];
            [strip setItems:section.items showsByline:section.showsByline];
            [self addRowView:strip kind:MTHomeRowKindStrip showsByline:section.showsByline];
            [strip release];
        }
    } else if (tab == 1) {
        for (MTFeedSection *section in _sections) {
            for (MTFeedItem *item in section.items) {
                if (!item.reviewSnippet.length) continue;

                MTReviewRowView *review = [[MTReviewRowView alloc] initWithFrame:CGRectZero];
                [review configureWithItem:item];
                [self addRowView:review kind:MTHomeRowKindReview showsByline:YES];
                [review release];
            }
        }
        if (_rows.count == 0) {
            [self showPlaceholder:@"No friend reviews yet."];
        }
    } else if (tab == 2) {
        [self showPlaceholder:@"Lists from friends will land here."];
    } else {
        [self showPlaceholder:@"Journal entries will land here."];
    }

    [self.view setNeedsLayout];
}

- (void)showPlaceholder:(NSString *)text
{
    _placeholderLabel.text = text;
    _placeholderLabel.hidden = NO;
    [self addRowView:_placeholderLabel kind:MTHomeRowKindPlaceholder showsByline:NO];
}

#pragma mark - layout

- (CGFloat)heightForRow:(MTHomeRow *)row width:(CGFloat)width
{
    switch (row.kind) {
        case MTHomeRowKindHeader:
            return 34.0f;
        case MTHomeRowKindStrip:
            return [MTPosterStripView heightForWidth:width showsByline:row.showsByline] + 20.0f;
        case MTHomeRowKindReview:
            return 84.0f;
        case MTHomeRowKindPlaceholder:
        default:
            return 260.0f;
    }
}

- (void)layoutRowsForWidth:(CGFloat)viewWidth
{
    CGFloat maxWidth = MTHomeContentMaxWidth();
    CGFloat contentWidth = viewWidth;
    if (maxWidth > 0.0f && maxWidth < viewWidth) {
        contentWidth = maxWidth;
    }
    CGFloat originX = floorf((viewWidth - contentWidth) / 2.0f);

    CGFloat y = 0.0f;
    MTHomeRow *row = nil;
    for (row in _rows) {
        CGFloat rowHeight = [self heightForRow:row width:contentWidth];
        row.view.frame = CGRectMake(originX, y, contentWidth, rowHeight);

        if ([row.view respondsToSelector:@selector(layoutForWidth:)]) {
            [(id)row.view layoutForWidth:contentWidth];
        }
        y += rowHeight;
    }

    if (y < 1.0f) y = 1.0f;

    _contentView.frame = CGRectMake(0.0f, 0.0f, viewWidth, y + 24.0f);
    _scrollView.contentSize = CGSizeMake(viewWidth, y + 24.0f);
}

#pragma mark - segmented bar

- (void)segmentedBarDidChangeSelection:(id)bar
{
    (void)bar;
    [self rebuildContent];
}

#pragma mark - orientation

- (UIInterfaceOrientationMask)supportedInterfaceOrientations
{
    return MTHomeIsPad() ? UIInterfaceOrientationMaskAll : UIInterfaceOrientationMaskPortrait;
}

@end
