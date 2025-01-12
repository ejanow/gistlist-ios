//
//  AppDelegate.m
//  gistlist
//
//  Created by Aaron Geisler on 3/28/15.
//  Copyright (c) 2015 Aaron Geisler. All rights reserved.
//

#import "AppDelegate.h"
#import <OCTClient.h>
#import <iRate.h>
#import <Crittercism.h>
#import <Mixpanel.h>
#import <CocoaLumberjack.h>
#import <SVProgressHUD.h>
#import "LandingViewController.h"
#import "AppService.h"
#import "NotificationHelper.h"
#import "AnalyticsHelper.h"
#import "LocalStorage.h"
#import "InterfaceConsts.h"
#import "TokensAndKeys.h"
#import "GLTheme.h"
#import "DialogHelper.h"

@interface AppDelegate ()

@end

@implementation AppDelegate

#pragma mark - Static

+ (void) initialize{
    [self setupIRate];
}

#pragma mark - Local Notifications

- (void) registerAndScheduleNotifications{
    [self registerForNotifications];
    [NotificationHelper attemptScheduleLocalNotification];
}

- (void) registerForNotifications{
    UIUserNotificationType types = UIUserNotificationTypeSound | UIUserNotificationTypeBadge | UIUserNotificationTypeAlert;
    UIUserNotificationSettings *notificationSettings = [UIUserNotificationSettings settingsForTypes:types categories:nil];
    [[UIApplication sharedApplication] registerUserNotificationSettings:notificationSettings];
}

- (void) application:(UIApplication *)application didRegisterUserNotificationSettings:(UIUserNotificationSettings *)notificationSettings{

}

- (void)application:(UIApplication *)app didReceiveLocalNotification:(UILocalNotification *)notif {
    [AnalyticsHelper localNotifcation];
}

- (void) handleNotificationOnAppLaunch:(UILocalNotification*) localNotification{
    [AnalyticsHelper localNotifcation];
}

#pragma mark - Third Party

+ (void) setupIRate{
    [iRate sharedInstance].appStoreID = APP_STORE_ID;
#if DEBUG
    [iRate sharedInstance].previewMode = NO;
#else
    [iRate sharedInstance].previewMode = NO;
#endif
    [iRate sharedInstance].eventsUntilPrompt = 3;
}

- (void) setupThirdParty{
    [Crittercism enableWithAppID:CRITTERCISM_TOKEN];
    
    [Mixpanel sharedInstanceWithToken:MIXPANEL_TOKEN];
    
    [DDLog addLogger:[DDASLLogger sharedInstance]];
    [DDLog addLogger:[DDTTYLogger sharedInstance]];
    [[DDTTYLogger sharedInstance] setColorsEnabled:YES];
    
    [SVProgressHUD setBackgroundColor:[GLTheme backgroundColorSpinner]];
    [SVProgressHUD setForegroundColor:[GLTheme textColorSpinner]];
    [SVProgressHUD setFont:[UIFont fontWithName:FONT size:16]];
}

#pragma mark - Application Lifecycle

- (BOOL)application:(UIApplication *)application openURL:(NSURL *)URL sourceApplication:(NSString *)sourceApplication annotation:(id)annotation {
    if ([URL.host isEqual:@"oauth"]) {
        [OCTClient completeSignInWithCallbackURL:URL];
        return YES;
    } else {
        return NO;
    }
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    // Thirdparty libraries
    [self setupThirdParty];
    
    // Setup window and root view controller
    _window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    _window.backgroundColor = UIColor.blackColor;
    LandingViewController* vc = [[LandingViewController alloc] init];
    _navController = [[UINavigationController alloc] initWithRootViewController:vc];
    _navController.navigationBarHidden = YES;
    _window.rootViewController = _navController;
    [_window addSubview:vc.view];
    [_window makeKeyAndVisible];
    
    // Kick things off
    [AppService start];
    
    // Handle launching from a notification
    UILocalNotification *localNotification = launchOptions[UIApplicationLaunchOptionsLocalNotificationKey];
    if (localNotification) {
        [self handleNotificationOnAppLaunch:localNotification];
    }
    
    return YES;
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    [UIApplication sharedApplication].applicationIconBadgeNumber = 0;
    RACSignal* sync = [AppService attemptSync];
    sync = AppService.performedInitialSync ? [sync withLoadingSpinner] : sync;
    [sync subscribeNext:^(id x) {
    } error:^(NSError *error) {
        [DialogHelper showSyncFailedToast];
    }];
}

@end
