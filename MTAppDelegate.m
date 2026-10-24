//
//  MTAppDelegate.m
//  Matinee
//

#import "MTAppDelegate.h"
#import "MTAppearance.h"
#import "MTHomeViewController.h"
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

    UINavigationController *home = [self navigationControllerWithRoot:[[MTHomeViewController alloc] init]
                                                                 title:@"Home"
                                                            systemItem:UITabBarSystemItemMostRecent];
    UINavigationController *lists = [self navigationControllerWithRoot:[[MTListsViewController alloc] init]
                                                                 title:@"Lists"
                                                            systemItem:UITabBarSystemItemBookmarks];
    UINavigationController *search = [self navigationControllerWithRoot:[[MTSearchViewController alloc] init]
                                                                  title:@"Search"
                                                             systemItem:UITabBarSystemItemSearch];
    UINavigationController *profile = [self navigationControllerWithRoot:[[MTProfileViewController alloc] init]
                                                                   title:@"Profile"
                                                              systemItem:UITabBarSystemItemContacts];

    UITabBarController *tabs = [[UITabBarController alloc] init];
    tabs.viewControllers = @[home, lists, search, profile];
    [MTAppearance styleTabBar:tabs.tabBar];

    self.window.rootViewController = tabs;
    [self.window makeKeyAndVisible];
    return YES;
}

- (UINavigationController *)navigationControllerWithRoot:(UIViewController *)root
                                                   title:(NSString *)title
                                              systemItem:(UITabBarSystemItem)systemItem
{
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:root];
    [MTAppearance styleNavigationBar:nav.navigationBar];

    UITabBarItem *item = [[UITabBarItem alloc] initWithTabBarSystemItem:systemItem tag:0];
    item.title = title;
    nav.tabBarItem = item;
    
    [root release];
    [item release];
    
    return [nav autorelease];
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    [[NSUserDefaults standardUserDefaults] synchronize];
}

@end