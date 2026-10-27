//
//  MTLogViewController.m
//  Matinee
//

#import "MTLogViewController.h"
#import "MTAppearance.h"
#import "MTImageCache.h"
#import "MTRelay.h"
#import "MTStarsView.h"
#import "MTStore.h"
#import <QuartzCore/QuartzCore.h>

static NSString *MTRatingCaption(CGFloat rating)
{
    return rating > 0.0
        ? [NSString stringWithFormat:@"%.1f of 5", rating]
        : @"Tap a star to rate";
}

static NSDateFormatter *MTISOFormatter(void)
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

static NSDateFormatter *MTDisplayFormatter(void)
{
    static NSDateFormatter *formatter = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        formatter = [[NSDateFormatter alloc] init];
        [formatter setDateFormat:@"M/d/yyyy"];
    });
    return formatter;
}

static NSDate *MTDateFromISO(NSString *string)
{
    if (!string.length) return [NSDate date];
    NSDate *date = [MTISOFormatter() dateFromString:string];
    return date ?: [NSDate date];
}


@interface MTCalendarIconView : UIView
@end

@implementation MTCalendarIconView

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
        self.opaque = NO;
    }
    return self;
}

- (void)drawRect:(CGRect)rect
{
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    if (!ctx) return;

    UIColor *stroke = [UIColor colorWithRed:0.25 green:0.25 blue:0.27 alpha:1.0];
    CGContextSetStrokeColorWithColor(ctx, stroke.CGColor);
    CGContextSetLineWidth(ctx, 1.2);

    UIBezierPath *box = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(2.0, 3.0, 14.0, 12.0)
                                                      cornerRadius:1.5];
    [box stroke];
    CGContextMoveToPoint(ctx, 2.0, 6.5);
    CGContextAddLineToPoint(ctx, 16.0, 6.5);
    CGContextStrokePath(ctx);

    CGContextMoveToPoint(ctx, 5.5, 1.5);
    CGContextAddLineToPoint(ctx, 5.5, 4.0);
    CGContextMoveToPoint(ctx, 12.5, 1.5);
    CGContextAddLineToPoint(ctx, 12.5, 4.0);
    CGContextStrokePath(ctx);

    CGContextSetFillColorWithColor(ctx, stroke.CGColor);
    for (NSInteger row = 0; row < 2; row++) {
        for (NSInteger column = 0; column < 3; column++) {
            CGContextFillRect(ctx, CGRectMake(4.5 + (CGFloat)column * 3.5,
                                              8.0 + (CGFloat)row * 3.0,
                                              1.2, 1.2));
        }
    }
}

@end


@interface MTLogBaseCell : UITableViewCell
@property (nonatomic, strong) UIView *rule;
@end

@implementation MTLogBaseCell

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.backgroundColor = [UIColor whiteColor];
        self.contentView.backgroundColor = [UIColor whiteColor];
        self.selectionStyle = UITableViewCellSelectionStyleNone;

        _rule = [[UIView alloc] initWithFrame:CGRectZero];
        _rule.backgroundColor = [MTAppearance sep];
        [self.contentView addSubview:_rule];
    }
    return self;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    CGFloat hairline = 1.0 / (self.contentScaleFactor ?: 1.0);
    self.rule.frame = CGRectMake(0.0, CGRectGetHeight(self.contentView.bounds) - hairline,
                                 CGRectGetWidth(self.contentView.bounds), hairline);
}

@end


@interface MTLogHeaderCell : MTLogBaseCell
@property (nonatomic, strong) MTPosterImageView *poster;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *subLabel;
- (void)configureWithDraft:(MTDraft *)draft;
@end

@implementation MTLogHeaderCell

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        _poster = [[MTPosterImageView alloc] initWithFrame:CGRectZero];
        [self.contentView addSubview:_poster];

        _titleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _titleLabel.backgroundColor = [UIColor clearColor];
        _titleLabel.font = [UIFont boldSystemFontOfSize:15.0];
        _titleLabel.textColor = [MTAppearance ink];
        _titleLabel.numberOfLines = 2;
        [self.contentView addSubview:_titleLabel];

        _subLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _subLabel.backgroundColor = [UIColor clearColor];
        _subLabel.font = [UIFont systemFontOfSize:11.5];
        _subLabel.textColor = [UIColor colorWithRed:0.482 green:0.482 blue:0.502 alpha:1.0];
        [self.contentView addSubview:_subLabel];
    }
    return self;
}

- (void)configureWithDraft:(MTDraft *)draft
{
    self.titleLabel.text = draft.title;
    self.subLabel.text = draft.year > 0
        ? [NSString stringWithFormat:@"%ld \u00b7 Film", (long)draft.year]
        : @"Film";
    NSString *path = draft.poster.length ? draft.poster : draft.posterCdn;
    [self.poster setRemoteURL:[MTRelay URLForPath:path]];
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    CGFloat width = CGRectGetWidth(self.contentView.bounds);
    self.poster.frame = CGRectMake(12.0, 8.0, 42.0, 63.0);
    self.titleLabel.frame = CGRectMake(66.0, 11.0, width - 78.0, 36.0);
    self.subLabel.frame = CGRectMake(66.0, 51.0, width - 78.0, 16.0);
}

@end


@interface MTLogRatingCell : MTLogBaseCell
@property (nonatomic, strong) MTRatingControl *control;
@property (nonatomic, strong) UILabel *caption;
- (void)configureWithRating:(CGFloat)rating;
@end

@implementation MTLogRatingCell

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        _control = [[MTRatingControl alloc] initWithFrame:CGRectZero];
        [self.contentView addSubview:_control];

        _caption = [[UILabel alloc] initWithFrame:CGRectZero];
        _caption.backgroundColor = [UIColor clearColor];
        _caption.font = [UIFont systemFontOfSize:11.0];
        _caption.textColor = [UIColor colorWithRed:0.482 green:0.482 blue:0.502 alpha:1.0];
        _caption.textAlignment = NSTextAlignmentCenter;
        [self.contentView addSubview:_caption];
    }
    return self;
}

- (void)configureWithRating:(CGFloat)rating
{
    self.control.rating = rating;
    self.caption.text = MTRatingCaption(rating);
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    CGFloat width = CGRectGetWidth(self.contentView.bounds);
    self.control.frame = CGRectMake(12.0, 6.0, width - 24.0, 36.0);
    self.caption.frame = CGRectMake(12.0, 48.0, width - 24.0, 15.0);
}

@end


@interface MTLogWatchedCell : MTLogBaseCell
@property (nonatomic, strong) UILabel *label;
@property (nonatomic, strong) UITextField *field;
- (void)setField:(UITextField *)field;
@end

@implementation MTLogWatchedCell

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        _label = [[UILabel alloc] initWithFrame:CGRectZero];
        _label.backgroundColor = [UIColor clearColor];
        _label.font = [UIFont systemFontOfSize:13.0];
        _label.textColor = [UIColor colorWithRed:0.227 green:0.227 blue:0.247 alpha:1.0];
        _label.text = @"Watched";
        [self.contentView addSubview:_label];
    }
    return self;
}

- (void)setField:(UITextField *)field
{
    if (_field != field) {
        [_field removeFromSuperview];
        _field = field;
        [self.contentView addSubview:_field];
        [self setNeedsLayout];
    }
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    CGFloat width = CGRectGetWidth(self.contentView.bounds);
    self.label.frame = CGRectMake(12.0, 16.0, 74.0, 18.0);
    self.field.frame = CGRectMake(96.0, 10.0, width - 108.0, 30.0);
}

@end


@interface MTLogReviewCell : MTLogBaseCell
@property (nonatomic, strong) UILabel *label;
@property (nonatomic, strong) UIView *box;
@property (nonatomic, strong) UITextView *textView;
@property (nonatomic, strong) UILabel *placeholder;
@end

@implementation MTLogReviewCell

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        _label = [[UILabel alloc] initWithFrame:CGRectZero];
        _label.backgroundColor = [UIColor clearColor];
        _label.font = [UIFont systemFontOfSize:13.0];
        _label.textColor = [UIColor colorWithRed:0.227 green:0.227 blue:0.247 alpha:1.0];
        _label.text = @"Review";
        [self.contentView addSubview:_label];

        _box = [[UIView alloc] initWithFrame:CGRectZero];
        _box.backgroundColor = [UIColor whiteColor];
        _box.layer.cornerRadius = 4.0;
        _box.layer.borderColor = [UIColor colorWithRed:0.725 green:0.745 blue:0.776 alpha:1.0].CGColor;
        _box.layer.borderWidth = 1.0;
        [self.contentView addSubview:_box];

        _textView = [[UITextView alloc] initWithFrame:CGRectZero];
        _textView.backgroundColor = [UIColor clearColor];
        _textView.font = [UIFont systemFontOfSize:13.0];
        _textView.textColor = [MTAppearance ink];
        _textView.scrollEnabled = YES;
        [_box addSubview:_textView];

        _placeholder = [[UILabel alloc] initWithFrame:CGRectZero];
        _placeholder.backgroundColor = [UIColor clearColor];
        _placeholder.text = @"Optional note";
        _placeholder.font = [UIFont systemFontOfSize:13.0];
        _placeholder.textColor = [UIColor colorWithWhite:0.62 alpha:1.0];
        _placeholder.userInteractionEnabled = NO;
        [_box addSubview:_placeholder];
    }
    return self;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    CGFloat width = CGRectGetWidth(self.contentView.bounds);
    self.label.frame = CGRectMake(12.0, 12.0, 74.0, 18.0);
    self.box.frame = CGRectMake(96.0, 10.0, width - 108.0, 84.0);
    self.textView.frame = self.box.bounds;
    self.placeholder.frame = CGRectMake(11.0, 6.0,
                                        CGRectGetWidth(self.box.bounds) - 22.0, 18.0);
}

@end


@interface MTLogSwitchCell : MTLogBaseCell
@property (nonatomic, strong) UILabel *label;
@property (nonatomic, strong) UISwitch *toggle;
- (void)configureWithTitle:(NSString *)title on:(BOOL)on tag:(NSInteger)tag;
@end

@implementation MTLogSwitchCell

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        _label = [[UILabel alloc] initWithFrame:CGRectZero];
        _label.backgroundColor = [UIColor clearColor];
        _label.font = [UIFont systemFontOfSize:13.0];
        _label.textColor = [UIColor colorWithRed:0.227 green:0.227 blue:0.247 alpha:1.0];
        [self.contentView addSubview:_label];

        _toggle = [[UISwitch alloc] initWithFrame:CGRectZero];
        [self.contentView addSubview:_toggle];
    }
    return self;
}

- (void)configureWithTitle:(NSString *)title on:(BOOL)on tag:(NSInteger)tag
{
    self.label.text = title;
    self.toggle.on = on;
    self.toggle.tag = tag;
    [self setNeedsLayout];
}

- (void)layoutSubviews
{
    [super layoutSubviews];

    [self.toggle sizeToFit];
    CGSize toggleSize = self.toggle.bounds.size;

    self.label.frame = CGRectMake(12.0, 15.0, 74.0, 18.0);
    self.toggle.frame = CGRectMake(96.0,
                                  floor((CGRectGetHeight(self.contentView.bounds) - toggleSize.height) * 0.5),
                                  toggleSize.width,
                                  toggleSize.height);
}

@end


@interface MTLogViewController () <UITableViewDataSource, UITableViewDelegate, UITextViewDelegate, UIAlertViewDelegate>
@property (nonatomic, strong) MTEntry *entry;
@property (nonatomic, strong) MTFilm *film;
@property (nonatomic, strong) MTDraft *draft;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UITextField *dateField;
@property (nonatomic, strong) UIDatePicker *datePicker;
@property (nonatomic, strong) UITextView *reviewTextView;
@property (nonatomic, strong) UILabel *reviewPlaceholder;
@end

@implementation MTLogViewController

- (id)initWithEntry:(MTEntry *)entry film:(MTFilm *)film
{
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _entry = entry;
        _film = film;
        _draft = [MTDraft draftWithEntry:entry film:film];
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.title = @"Log film";
    self.view.backgroundColor = [MTAppearance paper];

    UIButton *cancel = [UIButton buttonWithType:UIButtonTypeCustom];
    cancel.frame = CGRectMake(0.0, 0.0, 64.0, 30.0);
    [cancel setTitle:@"Cancel" forState:UIControlStateNormal];
    cancel.titleLabel.font = [UIFont boldSystemFontOfSize:13.0];
    [cancel setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [cancel setTitleShadowColor:[UIColor colorWithWhite:0.0 alpha:0.5] forState:UIControlStateNormal];
    cancel.titleLabel.shadowOffset = CGSizeMake(0.0, -1.0);
    cancel.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
    [cancel addTarget:self action:@selector(cancelTapped:) forControlEvents:UIControlEventTouchUpInside];
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:cancel];

    UIButton *save = [UIButton buttonWithType:UIButtonTypeCustom];
    save.frame = CGRectMake(0.0, 0.0, 50.0, 30.0);
    [save setTitle:@"Save" forState:UIControlStateNormal];
    save.titleLabel.font = [UIFont boldSystemFontOfSize:13.0];
    [save setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [save setTitleShadowColor:[UIColor colorWithWhite:0.0 alpha:0.5] forState:UIControlStateNormal];
    save.titleLabel.shadowOffset = CGSizeMake(0.0, -1.0);
    save.contentHorizontalAlignment = UIControlContentHorizontalAlignmentRight;
    [save addTarget:self action:@selector(saveTapped:) forControlEvents:UIControlEventTouchUpInside];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:save];

    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStylePlain];
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.backgroundColor = [MTAppearance paper];
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    [self.view addSubview:self.tableView];

    self.datePicker = [[UIDatePicker alloc] initWithFrame:CGRectZero];
    self.datePicker.datePickerMode = UIDatePickerModeDate;
    self.datePicker.maximumDate = [NSDate date];
    self.datePicker.date = MTDateFromISO(self.draft.watchedDate);
    [self.datePicker addTarget:self action:@selector(dateChanged:) forControlEvents:UIControlEventValueChanged];

    UIToolbar *toolbar = [[UIToolbar alloc] initWithFrame:CGRectMake(0.0, 0.0, 320.0, 44.0)];
    toolbar.barStyle = UIBarStyleBlack;
    toolbar.items = @[
        [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace
                                                      target:nil action:nil],
        [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                      target:self action:@selector(doneEditing:)]
    ];

    self.dateField = [[UITextField alloc] initWithFrame:CGRectZero];
    self.dateField.font = [UIFont systemFontOfSize:13.0];
    self.dateField.textColor = [MTAppearance ink];
    self.dateField.backgroundColor = [UIColor whiteColor];
    self.dateField.borderStyle = UITextBorderStyleRoundedRect;
    self.dateField.inputView = self.datePicker;
    self.dateField.inputAccessoryView = toolbar;
    self.dateField.text = [MTDisplayFormatter() stringFromDate:self.datePicker.date];

    MTCalendarIconView *calendar = [[MTCalendarIconView alloc] initWithFrame:CGRectMake(0.0, 0.0, 22.0, 18.0)];
    self.dateField.rightView = calendar;
    self.dateField.rightViewMode = UITextFieldViewModeAlways;

    [self updateFooter];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardDidShow:)
                                                 name:UIKeyboardDidShowNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillHide:)
                                                 name:UIKeyboardWillHideNotification
                                               object:nil];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)cancelTapped:(id)sender
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)saveTapped:(id)sender
{
    [self.view endEditing:YES];
    [MTStore addDraft:self.draft];
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)dateChanged:(id)sender
{
    self.draft.watchedDate = [MTISOFormatter() stringFromDate:self.datePicker.date];
    self.dateField.text = [MTDisplayFormatter() stringFromDate:self.datePicker.date];
}

- (void)doneEditing:(id)sender
{
    [self.view endEditing:YES];
}

- (void)updateFooter
{
    BOOL canSend = self.draft.slug.length > 0;
    CGFloat height = canSend ? 96.0 : 48.0;
    UIView *footer = [[UIView alloc] initWithFrame:CGRectMake(0.0, 0.0,
                                                              CGRectGetWidth(self.tableView.bounds),
                                                              height)];
    footer.backgroundColor = [MTAppearance paper];

    UIView *topRule = [[UIView alloc] initWithFrame:CGRectMake(0.0, 0.0,
                                                               CGRectGetWidth(footer.bounds), 1.0)];
    topRule.backgroundColor = [MTAppearance sep];
    [footer addSubview:topRule];

    CGFloat noteY = 10.0;
    if (canSend) {
        UIButton *send = [UIButton buttonWithType:UIButtonTypeCustom];
        send.frame = CGRectMake(12.0, 10.0, CGRectGetWidth(footer.bounds) - 24.0, 38.0);
        [send setTitle:@"Send to Letterboxd" forState:UIControlStateNormal];
        send.titleLabel.font = [UIFont boldSystemFontOfSize:14.0];
        [send setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        [send setTitleShadowColor:[UIColor colorWithWhite:0.0 alpha:0.45] forState:UIControlStateNormal];
        send.titleLabel.shadowOffset = CGSizeMake(0.0, -1.0);
        [send setBackgroundImage:[MTAppearance dangerButtonImage] forState:UIControlStateNormal];
        [send addTarget:self action:@selector(sendTapped) forControlEvents:UIControlEventTouchUpInside];
        [footer addSubview:send];
        noteY = 58.0;
    }

    UILabel *note = [[UILabel alloc] initWithFrame:CGRectMake(12.0, noteY,
                                                              CGRectGetWidth(footer.bounds) - 24.0, 30.0)];
    note.backgroundColor = [UIColor clearColor];
    note.font = [MTAppearance smallFont];
    note.textColor = [UIColor colorWithRed:0.482 green:0.482 blue:0.502 alpha:1.0];
    note.textAlignment = NSTextAlignmentCenter;
    note.numberOfLines = 0;
    note.text = canSend
        ? @"Experimental \u00b7 uses a session cookie on the relay"
        : (self.draft.slug.length
           ? @"Saves as a draft on this device \u00b7 export from Profile"
           : @"Search result \u00b7 matches by tmdbID on CSV import");
    [footer addSubview:note];

    self.tableView.tableFooterView = footer;
}

- (void)keyboardDidShow:(NSNotification *)note
{
    CGRect frame = [note.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
    frame = [self.view convertRect:frame fromView:nil];
    CGFloat overlap = CGRectGetMaxY(self.view.bounds) - CGRectGetMinY(frame);
    UIEdgeInsets inset = UIEdgeInsetsMake(0.0, 0.0, MAX(0.0, overlap), 0.0);
    self.tableView.contentInset = inset;
    self.tableView.scrollIndicatorInsets = inset;
}

- (void)keyboardWillHide:(NSNotification *)note
{
    self.tableView.contentInset = UIEdgeInsetsZero;
    self.tableView.scrollIndicatorInsets = UIEdgeInsetsZero;
}

#pragma mark - Table

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return 6;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    switch (indexPath.row) {
        case 0: return 80.0;
        case 1: return 72.0;
        case 2: return 50.0;
        case 3: return 104.0;
        default: return 50.0;
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.row == 0) {
        MTLogHeaderCell *cell = [[MTLogHeaderCell alloc] initWithStyle:UITableViewCellStyleDefault
                                                        reuseIdentifier:nil];
        [cell configureWithDraft:self.draft];
        return cell;
    }

    if (indexPath.row == 1) {
        MTLogRatingCell *cell = [[MTLogRatingCell alloc] initWithStyle:UITableViewCellStyleDefault
                                                        reuseIdentifier:nil];
        [cell configureWithRating:self.draft.rating ? self.draft.rating.doubleValue : 0.0];

        __weak MTLogRatingCell *weakCell = cell;
        __weak MTLogViewController *weakSelf = self;
        cell.control.onChange = ^(CGFloat rating) {
            weakSelf.draft.rating = rating > 0.0 ? @(rating) : nil;
            weakCell.caption.text = MTRatingCaption(rating);
        };
        return cell;
    }

    if (indexPath.row == 2) {
        MTLogWatchedCell *cell = [[MTLogWatchedCell alloc] initWithStyle:UITableViewCellStyleDefault
                                                          reuseIdentifier:nil];
        [cell setField:self.dateField];
        return cell;
    }

    if (indexPath.row == 3) {
        MTLogReviewCell *cell = [[MTLogReviewCell alloc] initWithStyle:UITableViewCellStyleDefault
                                                        reuseIdentifier:nil];
        cell.textView.text = self.draft.review;
        cell.textView.delegate = self;
        cell.placeholder.hidden = self.draft.review.length > 0;
        self.reviewTextView = cell.textView;
        self.reviewPlaceholder = cell.placeholder;
        return cell;
    }

    MTLogSwitchCell *cell = [[MTLogSwitchCell alloc] initWithStyle:UITableViewCellStyleDefault
                                                    reuseIdentifier:nil];
    if (indexPath.row == 4) {
        [cell configureWithTitle:@"Rewatch" on:self.draft.rewatch tag:2];
    } else {
        [cell configureWithTitle:@"Like" on:self.draft.liked tag:3];
    }
    [cell.toggle addTarget:self action:@selector(switchChanged:) forControlEvents:UIControlEventValueChanged];
    return cell;
}

- (void)switchChanged:(UISwitch *)toggle
{
    if (toggle.tag == 2) {
        self.draft.rewatch = toggle.on;
    } else {
        self.draft.liked = toggle.on;
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    if (indexPath.row == 2) {
        [self.dateField becomeFirstResponder];
    } else if (indexPath.row == 3) {
        [self.reviewTextView becomeFirstResponder];
    }
}

- (void)textViewDidChange:(UITextView *)textView
{
    self.draft.review = textView.text;
    self.reviewPlaceholder.hidden = textView.text.length > 0;
}

#pragma mark - Send

- (void)sendTapped
{
    if (!self.draft.slug.length) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"No Letterboxd slug"
                                                        message:@"This film came from search. Export it as CSV from Profile; the importer matches it by tmdbID."
                                                       delegate:nil
                                              cancelButtonTitle:@"OK"
                                              otherButtonTitles:nil];
        [alert show];
        return;
    }

    __weak MTLogViewController *weakSelf = self;
    [[MTRelay sharedRelay] logDraft:self.draft completion:^(id json, NSError *error) {
        MTLogViewController *strongSelf = weakSelf;
        if (!strongSelf) return;

        if (error) {
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Not logged"
                                                            message:error.localizedDescription
                                                           delegate:nil
                                                  cancelButtonTitle:@"OK"
                                                  otherButtonTitles:nil];
            [alert show];
            return;
        }

        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Logged"
                                                        message:@"The relay accepted the entry."
                                                       delegate:strongSelf
                                              cancelButtonTitle:@"OK"
                                              otherButtonTitles:nil];
        alert.tag = 2;
        [alert show];
    }];
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (alertView.tag == 2) {
        [self dismissViewControllerAnimated:YES completion:nil];
    }
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
