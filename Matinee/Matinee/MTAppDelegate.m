//
//  MTAppDelegate.m
//  Matinee
//

#import "MTAppDelegate.h"
#import "MTAppearance.h"
#import "MTDiaryViewController.h"
#import "MTListsViewController.h"
#import "MTProfileViewController.h"
#import "MTSearchViewController.h"
#import "MTStore.h"

@implementation MTAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    [MTStore registerDefaults];

    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    self.window.backgroundColor = [UIColor whiteColor];

    UINavigationController *diary = [self navigationControllerWithRoot:[[MTDiaryViewController alloc] init]
                                                                 title:@"Diary"
                                                                   tab:MTTabIconDiary];
    UINavigationController *lists = [self navigationControllerWithRoot:[[MTListsViewController alloc] init]
                                                                 title:@"Lists"
                                                                   tab:MTTabIconLists];
    UINavigationController *search = [self navigationControllerWithRoot:[[MTSearchViewController alloc] init]
                                                                  title:@"Search"
                                                                    tab:MTTabIconSearch];
    UINavigationController *profile = [self navigationControllerWithRoot:[[MTProfileViewController alloc] init]
                                                                   title:@"Profile"
                                                                     tab:MTTabIconProfile];

    UITabBarController *tabs = [[UITabBarController alloc] init];
    tabs.viewControllers = @[diary, lists, search, profile];
    [MTAppearance styleTabBar:tabs.tabBar];

    self.window.rootViewController = tabs;
    [self.window makeKeyAndVisible];
    return YES;
}

- (UINavigationController *)navigationControllerWithRoot:(UIViewController *)root
                                                    title:(NSString *)title
                                                      tab:(MTTabIcon)tab
{
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:root];
    [MTAppearance styleNavigationBar:nav.navigationBar];

    UIImage *normal = [MTAppearance tabIconForTab:tab selected:NO];
    UIImage *selected = [MTAppearance tabIconForTab:tab selected:YES];

    UITabBarItem *item = [[UITabBarItem alloc] initWithTitle:title image:normal tag:tab];
    [item setFinishedSelectedImage:selected withFinishedUnselectedImage:normal];

    NSDictionary *ordinary = @{
        UITextAttributeTextColor: [UIColor colorWithRed:0.60 green:0.60 blue:0.62 alpha:1.0],
        UITextAttributeTextShadowColor: [UIColor colorWithWhite:0.0 alpha:0.8],
        UITextAttributeTextShadowOffset: [NSValue valueWithUIOffset:UIOffsetMake(0.0, -1.0)],
        UITextAttributeFont: [UIFont systemFontOfSize:10.0]
    };
    NSDictionary *active = @{
        UITextAttributeTextColor: [UIColor whiteColor],
        UITextAttributeTextShadowColor: [UIColor colorWithWhite:0.0 alpha:0.8],
        UITextAttributeTextShadowOffset: [NSValue valueWithUIOffset:UIOffsetMake(0.0, -1.0)],
        UITextAttributeFont: [UIFont boldSystemFontOfSize:10.0]
    };
    [item setTitleTextAttributes:ordinary forState:UIControlStateNormal];
    [item setTitleTextAttributes:active forState:UIControlStateSelected];

    nav.tabBarItem = item;
    return nav;
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    [[NSUserDefaults standardUserDefaults] synchronize];
}

@end
