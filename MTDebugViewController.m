//
//  MTDebugViewController.m
//  Matinee
//

#import "MTDebugViewController.h"
#import "MTSecureClient.h"

@interface MTDebugViewController ()
@property (nonatomic, strong) UITextView *textView;
@end

@implementation MTDebugViewController

// Inside your button tap or table view selection method:
- (void)showDebugLogViewer {
    MTDebugViewController *debugVC = [[MTDebugViewController alloc] init];
    debugVC.logContent = [MTSecureClient lastDebugPayload] ?: @"No requests made yet.";
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:debugVC];
    [self presentViewController:nav animated:YES completion:nil];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Debug Log";
    self.view.backgroundColor = [UIColor whiteColor];
    
    self.textView = [[UITextView alloc] initWithFrame:self.view.bounds];
    self.textView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.textView.editable = NO;
    self.textView.font = [UIFont fontWithName:@"Courier" size:12.0];
    self.textView.text = self.logContent ?: @"No log content available.";
    [self.view addSubview:self.textView];
    
    UIBarButtonItem *doneButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                                                target:self
                                                                                action:@selector(dismiss)];
    self.navigationItem.rightBarButtonItem = doneButton;
}

- (void)dismiss {
    [self dismissViewControllerAnimated:YES completion:nil];
}

@end