//
//  MTProfileViewController.m
//  Matinee
//
//  Account and drafts management. No password is ever entered here:
//  connecting only stores the public Letterboxd handle.
//

#import "MTProfileViewController.h"
#import "MTAppearance.h"
#import "MTModels.h"
#import "MTStore.h"
#import <MessageUI/MessageUI.h>
#import "MTDebugViewController.h"
#import "MTSecureClient.h"

@interface MTProfileViewController () <UIAlertViewDelegate, MFMailComposeViewControllerDelegate>
@property (nonatomic, strong) UITableView *tableView;
@end

@implementation MTProfileViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.title = @"Profile";
    self.view.backgroundColor = [MTAppearance paper];

    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStyleGrouped];
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.backgroundColor = [MTAppearance paper];
    self.tableView.separatorColor = [MTAppearance sep];
    [self.view addSubview:self.tableView];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(draftsChanged:)
                                                 name:MTDraftsDidChangeNotification
                                               object:nil];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [super dealloc];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self.tableView reloadData];
}

- (void)draftsChanged:(NSNotification *)note
{
    [self.tableView reloadData];
}

#pragma mark - Table View Data Source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 3; // Reduced from 4 since relay section is removed
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (section == 0) return 3; // Handle, Change Handle, Refresh Feed
    if (section == 1) return 3; // Saved drafts, Export CSV, Clear drafts
    return 1; // About / Version
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    switch (section) {
        case 0: return @"Account";
        case 1: return @"Drafts";
        default: return @"About";
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section
{
    if (section == 1) {
        return @"Drafts are local CSV rows. Export them, then import at letterboxd.com/import. Nothing is posted without your action.";
    }
    if (section == 2) {
        return @"Matinee is an unofficial client. Not affiliated with Letterboxd. Posters and metadata belong to their owners.";
    }
    return nil;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *valueIdentifier = @"value";
    static NSString *actionIdentifier = @"action";

    if (indexPath.section == 0 && indexPath.row == 0) {
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:valueIdentifier];
        if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:valueIdentifier];
        cell.textLabel.text = @"Handle";
        cell.textLabel.font = [MTAppearance bodyFont];
        cell.detailTextLabel.text = [MTStore handle] ? [@"@" stringByAppendingString:[MTStore handle]] : @"Not connected";
        cell.detailTextLabel.font = [MTAppearance bodyFont];
        cell.detailTextLabel.textColor = [MTAppearance muted];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        cell.accessoryType = UITableViewCellAccessoryNone;
        return cell;
    }

    if (indexPath.section == 0 && indexPath.row == 2) {
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:valueIdentifier];
        if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:valueIdentifier];
        cell.textLabel.text = @"Diary";
        cell.textLabel.font = [MTAppearance bodyFont];
        cell.detailTextLabel.text = @"Refresh feed";
        cell.detailTextLabel.font = [MTAppearance bodyFont];
        cell.detailTextLabel.textColor = [MTAppearance link];
        cell.selectionStyle = UITableViewCellSelectionStyleBlue;
        return cell;
    }

    if (indexPath.section == 1) {
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:valueIdentifier];
        if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:valueIdentifier];
        cell.textLabel.font = [MTAppearance bodyFont];
        cell.detailTextLabel.font = [MTAppearance bodyFont];
        cell.selectionStyle = UITableViewCellSelectionStyleBlue;

        NSArray *drafts = [MTStore drafts];
        if (indexPath.row == 0) {
            cell.textLabel.text = @"Saved drafts";
            cell.detailTextLabel.text = [NSString stringWithFormat:@"%lu", (unsigned long)drafts.count];
            cell.detailTextLabel.textColor = [MTAppearance muted];
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
        } else if (indexPath.row == 1) {
            cell.textLabel.text = @"Export CSV";
            cell.textLabel.textColor = drafts.count ? [MTAppearance link] : [UIColor lightGrayColor];
            cell.detailTextLabel.text = drafts.count ? @"Email or copy" : @"";
            cell.detailTextLabel.textColor = [MTAppearance muted];
            cell.selectionStyle = drafts.count ? UITableViewCellSelectionStyleBlue : UITableViewCellSelectionStyleNone;
        } else {
            cell.textLabel.text = @"Clear drafts";
            cell.textLabel.textColor = drafts.count
                ? [UIColor colorWithRed:0.64 green:0.20 blue:0.17 alpha:1.0]
                : [UIColor lightGrayColor];
            cell.detailTextLabel.text = @"";
            cell.selectionStyle = drafts.count ? UITableViewCellSelectionStyleBlue : UITableViewCellSelectionStyleNone;
        }
        return cell;
    }

    if (indexPath.section == 0 && indexPath.row == 1) {
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:actionIdentifier];
        if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:actionIdentifier];
        cell.textLabel.text = [MTStore handle] ? @"Change handle" : @"Connect a profile";
        cell.textLabel.font = [MTAppearance bodyFont];
        cell.textLabel.textColor = [MTAppearance link];
        return cell;
    }

    // Section 2: About / Version
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:valueIdentifier];
    if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:valueIdentifier];
    cell.textLabel.text = @"Version";
    cell.textLabel.font = [MTAppearance bodyFont];
    cell.detailTextLabel.text = @"1.0";
    cell.detailTextLabel.font = [MTAppearance bodyFont];
    cell.detailTextLabel.textColor = [MTAppearance muted];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    if (indexPath.section == 0 && indexPath.row == 1) {
        [self showConnectAlert];
        return;
    }
    if (indexPath.section == 0 && indexPath.row == 2) {
        [[NSNotificationCenter defaultCenter] postNotificationName:MTFeedShouldReloadNotification object:nil];
        return;
    }
    if (indexPath.section == 1) {
        NSArray *drafts = [MTStore drafts];
        if (!drafts.count) return;
        if (indexPath.row == 1) {
            [self exportDrafts:drafts];
        } else if (indexPath.row == 2) {
            [self confirmClear];
        }
        return;
    }
}

#pragma mark - Alerts & Input

- (void)showConnectAlert
{
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Connect a profile"
                                                    message:@"Enter your Letterboxd handle."
                                                   delegate:self
                                          cancelButtonTitle:@"Cancel"
                                          otherButtonTitles:@"Connect", nil];
    alert.alertViewStyle = UIAlertViewStylePlainTextInput;
    alert.tag = 1;
    UITextField *field = [alert textFieldAtIndex:0];
    field.text = [MTStore handle] ?: @"";
    field.autocapitalizationType = UITextAutocapitalizationTypeNone;
    field.autocorrectionType = UITextAutocorrectionTypeNo;
    field.placeholder = @"yourname";
    [alert show];
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (buttonIndex == 0) return;

    if (alertView.tag == 1) {
        NSString *input = [[alertView textFieldAtIndex:0].text stringByTrimmingCharactersInSet:
                           [NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (!input.length) return;
        
        [MTStore setHandle:input];
        [[NSNotificationCenter defaultCenter] postNotificationName:MTFeedShouldReloadNotification object:nil];
        [self.tableView reloadData];

        UIAlertView *successAlert = [[UIAlertView alloc] initWithTitle:@"Connected"
                                                                message:[NSString stringWithFormat:@"Profile @%@ saved.", input]
                                                               delegate:nil
                                                      cancelButtonTitle:@"OK"
                                                      otherButtonTitles:nil];
        [successAlert show];
    } else if (alertView.tag == 2) {
        [MTStore clearDrafts];
        [self.tableView reloadData];
    }
}

- (void)confirmClear
{
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Clear drafts?"
                                                    message:@"This removes every CSV row saved on this device."
                                                   delegate:self
                                          cancelButtonTitle:@"Cancel"
                                          otherButtonTitles:@"Clear", nil];
    alert.tag = 2;
    [alert show];
}

#pragma mark - CSV Export

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
        [mail setMessageBody:@"Attach this CSV at letterboxd.com/import.\n\nRatings are half-stars. Rewatches are marked Yes. Nothing is posted until you finish the import." isHTML:NO];
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

- (void)showDebugLogViewer {
    MTDebugViewController *debugVC = [[MTDebugViewController alloc] init];
    debugVC.logContent = [MTSecureClient lastDebugPayload] ?: @"No requests made yet.";
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:debugVC];
    [self presentViewController:nav animated:YES completion:nil];
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