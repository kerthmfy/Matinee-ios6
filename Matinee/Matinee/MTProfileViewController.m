//
//  MTProfileViewController.m
//  Matinee
//
//  Account, drafts, and relay settings. No password is ever entered here:
//  connecting only stores the public Letterboxd handle. The optional write
//  path lives on the relay as LB_SESSION_COOKIE.
//

#import "MTProfileViewController.h"
#import "MTAppearance.h"
#import "MTModels.h"
#import "MTRelay.h"
#import "MTStore.h"
#import <MessageUI/MessageUI.h>

@interface MTProfileViewController () <UIAlertViewDelegate, MFMailComposeViewControllerDelegate>
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, copy) NSString *statusText;
@end

@implementation MTProfileViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.title = @"Profile";
    self.view.backgroundColor = [MTAppearance paper];
    self.statusText = @"Checking\u2026";

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

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self.tableView reloadData];
    [self checkHealth];
}

- (void)draftsChanged:(NSNotification *)note
{
    [self.tableView reloadData];
}

#pragma mark - Health

- (void)checkHealth
{
    self.statusText = @"Checking\u2026";
    __weak MTProfileViewController *weakSelf = self;
    [[MTRelay sharedRelay] health:^(id json, NSError *error) {
        MTProfileViewController *strongSelf = weakSelf;
        if (!strongSelf) return;

        if (error || ![json isKindOfClass:[NSDictionary class]]) {
            strongSelf.statusText = @"Unreachable";
        } else {
            BOOL configured = [json[@"session"] boolValue];
            strongSelf.statusText = configured ? @"Write configured" : @"Read-only";
        }
        [strongSelf.tableView reloadSections:[NSIndexSet indexSetWithIndex:2]
                            withRowAnimation:UITableViewRowAnimationNone];
    }];
}

#pragma mark - Table

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 4;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (section == 0) return 3;
    if (section == 1) return 3;
    if (section == 2) return 4;
    return 1;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    switch (section) {
        case 0: return @"Account";
        case 1: return @"Drafts";
        case 2: return @"Relay";
        default: return @"About";
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section
{
    if (section == 1) {
        return @"Drafts are local CSV rows. Export them, then import at letterboxd.com/import. Nothing is posted without your action.";
    }
    if (section == 3) {
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

    if (indexPath.section == 2) {
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:valueIdentifier];
        if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:valueIdentifier];
        cell.textLabel.font = [MTAppearance bodyFont];
        cell.textLabel.textColor = [MTAppearance ink];
        cell.detailTextLabel.font = [MTAppearance bodyFont];
        cell.detailTextLabel.textColor = [MTAppearance muted];
        cell.detailTextLabel.text = @"";

        if (indexPath.row == 0) {
            cell.textLabel.text = @"Server";
            cell.detailTextLabel.text = [MTStore relayBase];
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
        } else if (indexPath.row == 1) {
            cell.textLabel.text = @"Status";
            cell.detailTextLabel.text = self.statusText;
            BOOL configured = [self.statusText isEqualToString:@"Write configured"] ||
                              [self.statusText isEqualToString:@"Write enabled"];
            cell.detailTextLabel.textColor = configured ? [MTAppearance green] : [MTAppearance muted];
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
        } else if (indexPath.row == 2) {
            cell.textLabel.text = @"Test session";
            cell.textLabel.textColor = [MTAppearance link];
            cell.detailTextLabel.text = @"Check cookie";
            cell.selectionStyle = UITableViewCellSelectionStyleBlue;
        } else {
            cell.textLabel.text = @"Change server";
            cell.textLabel.textColor = [MTAppearance link];
            cell.selectionStyle = UITableViewCellSelectionStyleBlue;
        }
        return cell;
    }

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
    if (indexPath.section == 2 && indexPath.row == 2) {
        [self testSession];
        return;
    }
    if (indexPath.section == 2 && indexPath.row == 3) {
        [self showServerAlert];
    }
}

- (void)testSession
{
    self.statusText = @"Checking\u2026";
    [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:2]
                  withRowAnimation:UITableViewRowAnimationNone];

    __weak MTProfileViewController *weakSelf = self;
    [[MTRelay sharedRelay] session:^(id json, NSError *error) {
        MTProfileViewController *strongSelf = weakSelf;
        if (!strongSelf) return;

        NSDictionary *dict = [json isKindOfClass:[NSDictionary class]] ? json : nil;
        BOOL configured = [dict[@"configured"] boolValue];
        BOOL signedIn = [dict[@"signedIn"] boolValue];
        NSString *reason = [dict[@"reason"] isKindOfClass:[NSString class]] ? dict[@"reason"] : nil;

        if (error) {
            strongSelf.statusText = @"Check failed";
        } else if (!configured) {
            strongSelf.statusText = @"Read-only";
        } else if (signedIn) {
            strongSelf.statusText = @"Write enabled";
        } else if ([reason isEqualToString:@"network"]) {
            strongSelf.statusText = @"Check failed";
        } else {
            strongSelf.statusText = @"Session invalid";
        }

        [strongSelf.tableView reloadSections:[NSIndexSet indexSetWithIndex:2]
                            withRowAnimation:UITableViewRowAnimationNone];

        NSString *title;
        if (error) {
            title = @"Session check failed";
        } else if (!configured) {
            title = @"No session";
        } else if (signedIn) {
            title = @"Session valid";
        } else if ([reason isEqualToString:@"network"]) {
            title = @"Session check failed";
        } else {
            title = @"Session not valid";
        }
        NSString *message;
        if (error) {
            message = error.localizedDescription;
        } else if (!configured) {
            message = @"No LB_SESSION_COOKIE is set on the relay. Add one with npm run cookie, then restart the relay.";
        } else if (signedIn) {
            message = @"Letterboxd recognized the relay's cookie. The log sheet can post diary entries.";
        } else if ([reason isEqualToString:@"network"]) {
            message = @"The relay could not reach Letterboxd. Check the Mac's network and try again.";
        } else {
            message = @"Letterboxd showed the signed-out form. The cookie is missing, expired, or from a different session.";
        }

        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:title
                                                        message:message
                                                       delegate:nil
                                              cancelButtonTitle:@"OK"
                                              otherButtonTitles:nil];
        [alert show];
    }];
}

#pragma mark - Alerts

- (void)showConnectAlert
{
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Connect a profile"
                                                    message:@"Letterboxd handle, profile link, or RSS URL."
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

- (void)showServerAlert
{
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Relay server"
                                                    message:@"Base URL of the Node relay on your network."
                                                   delegate:self
                                          cancelButtonTitle:@"Cancel"
                                          otherButtonTitles:@"Save", nil];
    alert.alertViewStyle = UIAlertViewStylePlainTextInput;
    alert.tag = 3;
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

    if (alertView.tag == 1) {
        NSString *input = [[alertView textFieldAtIndex:0].text stringByTrimmingCharactersInSet:
                           [NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (!input.length) return;
        [self connectInput:input];
    } else if (alertView.tag == 2) {
        [MTStore clearDrafts];
        [self.tableView reloadData];
    } else if (alertView.tag == 3) {
        NSString *server = [[alertView textFieldAtIndex:0].text stringByTrimmingCharactersInSet:
                            [NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (!server.length) return;
        [MTStore setRelayBase:server];
        [self.tableView reloadData];
        [self checkHealth];
    }
}

- (void)connectInput:(NSString *)input
{
    __weak MTProfileViewController *weakSelf = self;
    [[MTRelay sharedRelay] connectInput:input completion:^(id json, NSError *error) {
        MTProfileViewController *strongSelf = weakSelf;
        if (!strongSelf) return;

        if (error) {
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Not connected"
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
        [[NSNotificationCenter defaultCenter] postNotificationName:MTFeedShouldReloadNotification object:nil];
        [strongSelf.tableView reloadData];

        NSString *member = json[@"member"];
        NSString *message = [NSString stringWithFormat:@"@%@ connected.%@", handle,
                             [member isKindOfClass:[NSString class]] && member.length
                                 ? [NSString stringWithFormat:@" Found %@.", member]
                                 : @""];
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Connected"
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
    alert.tag = 2;
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
