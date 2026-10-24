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
        [formatter setDateFormat:@"MMM d, yyyy"];
    });
    return formatter;
}

static NSDate *MTDateFromISO(NSString *string)
{
    if (!string.length) return [NSDate date];
    NSDate *date = [MTISOFormatter() dateFromString:string];
    return date ?: [NSDate date];
}


@interface MTLogHeaderCell : UITableViewCell
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
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        _poster = [[MTPosterImageView alloc] initWithFrame:CGRectZero];
        [self.contentView addSubview:_poster];

        _titleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _titleLabel.font = [UIFont boldSystemFontOfSize:14.0];
        _titleLabel.textColor = [MTAppearance ink];
        _titleLabel.numberOfLines = 2;
        [self.contentView addSubview:_titleLabel];

        _subLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _subLabel.font = [MTAppearance smallFont];
        _subLabel.textColor = [MTAppearance muted];
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
    self.poster.frame = CGRectMake(10.0, 10.0, 42.0, 63.0);
    self.titleLabel.frame = CGRectMake(64.0, 12.0, width - 76.0, 38.0);
    self.subLabel.frame = CGRectMake(64.0, 52.0, width - 76.0, 16.0);
}

@end


@interface MTLogRatingCell : UITableViewCell
@property (nonatomic, strong) MTRatingControl *control;
@property (nonatomic, strong) UILabel *caption;
- (void)configureWithRating:(CGFloat)rating;
@end

@implementation MTLogRatingCell

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        _control = [[MTRatingControl alloc] initWithFrame:CGRectZero];
        [self.contentView addSubview:_control];

        _caption = [[UILabel alloc] initWithFrame:CGRectZero];
        _caption.font = [MTAppearance smallFont];
        _caption.textColor = [MTAppearance muted];
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
    self.control.frame = CGRectMake(10.0, 8.0, width - 20.0, 30.0);
    self.caption.frame = CGRectMake(10.0, 44.0, width - 20.0, 16.0);
}

@end


@interface MTLogReviewCell : UITableViewCell
@property (nonatomic, strong) UITextView *textView;
@property (nonatomic, strong) UILabel *placeholder;
@end

@implementation MTLogReviewCell

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        _textView = [[UITextView alloc] initWithFrame:CGRectZero];
        _textView.backgroundColor = [UIColor clearColor];
        _textView.font = [UIFont systemFontOfSize:13.0];
        _textView.textColor = [MTAppearance ink];
        _textView.scrollEnabled = YES;
        [self.contentView addSubview:_textView];

        _placeholder = [[UILabel alloc] initWithFrame:CGRectZero];
        _placeholder.text = @"Optional note";
        _placeholder.font = [UIFont systemFontOfSize:13.0];
        _placeholder.textColor = [UIColor colorWithWhite:0.62 alpha:1.0];
        _placeholder.userInteractionEnabled = NO;
        [self.contentView addSubview:_placeholder];
    }
    return self;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    CGFloat width = CGRectGetWidth(self.contentView.bounds);
    self.textView.frame = CGRectMake(6.0, 6.0, width - 12.0, CGRectGetHeight(self.contentView.bounds) - 12.0);
    self.placeholder.frame = CGRectMake(12.0, 12.0, width - 24.0, 18.0);
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

    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel
                                                                                          target:self
                                                                                          action:@selector(cancelTapped:)];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemSave
                                                                                           target:self
                                                                                           action:@selector(saveTapped:)];

    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStyleGrouped];
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.backgroundColor = [MTAppearance paper];
    self.tableView.separatorColor = [MTAppearance sep];
    [self.view addSubview:self.tableView];

    self.datePicker = [[UIDatePicker alloc] initWithFrame:CGRectZero];
    self.datePicker.datePickerMode = UIDatePickerModeDate;
    self.datePicker.maximumDate = [NSDate date];
    self.datePicker.date = MTDateFromISO(self.draft.watchedDate);
    [self.datePicker addTarget:self action:@selector(dateChanged:) forControlEvents:UIControlEventValueChanged];

    UIToolbar *toolbar = [[UIToolbar alloc] initWithFrame:CGRectMake(0.0, 0.0, 320.0, 44.0)];
    toolbar.barStyle = UIBarStyleBlack;
    toolbar.items = @[
        [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil],
        [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(doneEditing:)]
    ];

    self.dateField = [[UITextField alloc] initWithFrame:CGRectMake(0.0, 0.0, 160.0, 30.0)];
    self.dateField.font = [UIFont systemFontOfSize:13.0];
    self.dateField.textColor = [MTAppearance ink];
    self.dateField.textAlignment = NSTextAlignmentRight;
    self.dateField.borderStyle = UITextBorderStyleNone;
    self.dateField.inputView = self.datePicker;
    self.dateField.inputAccessoryView = toolbar;
    self.dateField.text = [MTDisplayFormatter() stringFromDate:self.datePicker.date];

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

#pragma mark - Keyboard

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
    return 4;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (section == 2) return 4;
    return 1;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == 0) return 84.0;
    if (indexPath.section == 1) return 78.0;
    if (indexPath.section == 2 && indexPath.row == 1) return 120.0;
    return 44.0;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section
{
    if (section == 2) {
        return @"Drafts stay on this device. Export a CSV from Profile and import it at letterboxd.com/import.";
    }
    if (section == 3) {
        return @"Experimental: the relay needs LB_SESSION_COOKIE. CSV export always works.";
    }
    return nil;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == 0) {
        MTLogHeaderCell *cell = [[MTLogHeaderCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
        [cell configureWithDraft:self.draft];
        return cell;
    }

    if (indexPath.section == 1) {
        MTLogRatingCell *cell = [[MTLogRatingCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
        [cell configureWithRating:self.draft.rating ? self.draft.rating.doubleValue : 0.0];

        __weak MTLogRatingCell *weakCell = cell;
        __weak MTLogViewController *weakSelf = self;
        cell.control.onChange = ^(CGFloat rating) {
            weakSelf.draft.rating = rating > 0.0 ? @(rating) : nil;
            weakCell.caption.text = MTRatingCaption(rating);
        };
        return cell;
    }

    if (indexPath.section == 2) {
        if (indexPath.row == 0) {
            UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            cell.textLabel.text = @"Watched";
            cell.textLabel.font = [MTAppearance bodyFont];
            cell.textLabel.textColor = [MTAppearance ink];
            cell.accessoryView = self.dateField;
            return cell;
        }

        if (indexPath.row == 1) {
            MTLogReviewCell *cell = [[MTLogReviewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
            cell.textView.text = self.draft.review;
            cell.textView.delegate = self;
            cell.placeholder.hidden = self.draft.review.length > 0;
            self.reviewTextView = cell.textView;
            self.reviewPlaceholder = cell.placeholder;
            return cell;
        }

        UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        cell.textLabel.font = [MTAppearance bodyFont];
        cell.textLabel.textColor = [MTAppearance ink];
        UISwitch *toggle = [[UISwitch alloc] initWithFrame:CGRectZero];
        toggle.tag = indexPath.row; // 2 = rewatch, 3 = like
        [toggle addTarget:self action:@selector(switchChanged:) forControlEvents:UIControlEventValueChanged];
        if (indexPath.row == 2) {
            cell.textLabel.text = @"Rewatch";
            toggle.on = self.draft.rewatch;
        } else {
            cell.textLabel.text = @"Like";
            toggle.on = self.draft.liked;
        }
        cell.accessoryView = toggle;
        return cell;
    }

    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
    cell.textLabel.text = @"Send to Letterboxd";
    cell.textLabel.textAlignment = NSTextAlignmentCenter;
    cell.textLabel.font = [UIFont boldSystemFontOfSize:14.0];
    cell.textLabel.textColor = [UIColor colorWithRed:0.64 green:0.20 blue:0.17 alpha:1.0];
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

    if (indexPath.section == 2 && indexPath.row == 0) {
        [self.dateField becomeFirstResponder];
        return;
    }
    if (indexPath.section == 2 && indexPath.row == 1) {
        [self.reviewTextView becomeFirstResponder];
        return;
    }
    if (indexPath.section == 3) {
        [self sendTapped];
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

- (NSUInteger)supportedInterfaceOrientations
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
