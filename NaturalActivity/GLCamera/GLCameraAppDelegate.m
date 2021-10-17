//
//  GLCameraAppDelegate.m
//  GLCamera
//
//  Created by Grant Davis on 7/26/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "GLCameraAppDelegate.h"
#import "GLApplication.h"

#import "GLCameraViewController.h"
#import "WarmupViewController.h"

#import "MyLoginViewController.h"

GLCameraAppDelegate* gAppD = nil;

CGFloat gSavedSystemBrightness = 1.0;
CGFloat gAppBrightness = 1.0;

@implementation GLCameraAppDelegate


@synthesize window = _window;
@synthesize viewController = _viewController;

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    gAppD = self;
    gSavedSystemBrightness = [UIScreen mainScreen].brightness;
    [self setDefaults];
    gAppBrightness = gSavedSystemBrightness;
    [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(adjustBrightness) userInfo:nil repeats:YES];
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    // Override point for customization after application launch.
    self.viewController = [[GLCameraViewController alloc] initWithNibName:@"GLCameraViewController" bundle:nil];
    self.loginViewController = [[MyLoginViewController alloc] initWithNibName:@"MyLoginViewController" bundle:nil];
    //self.viewController.useVideoFrames = [GLCameraViewController shouldUseVideoMode];
    self.viewController.useVideoFrames = YES;
    self.window.rootViewController = self.viewController;
    [self.window makeKeyAndVisible];
    
    self.screenSaverView = [[UIView alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    self.screenSaverView.backgroundColor = [UIColor blackColor];
    self.screenSaverView.hidden = YES;
    [self.window addSubview:self.screenSaverView];
    [((GLApplication*)[UIApplication sharedApplication]) resetIdleTimer];

    [self setUpChargingNotification];
    
    [self showWarmup:0];
    return YES;
}

-(void)setDefaults;
{
    NSMutableDictionary* dict = [NSMutableDictionary dictionary];
    dict[@"dimScreen"] = @(YES);
    [[NSUserDefaults standardUserDefaults] registerDefaults:dict];
}

-(void)showWarmup:(double)progress;
{
    if (self.warmupViewController == nil){
        self.warmupViewController = [[WarmupViewController alloc] initWithNibName:@"WarmupViewController" bundle:nil];
        [self.warmupViewController view];
        [self.viewController presentViewController:self.warmupViewController animated:YES completion:nil];
        progress = 100.0f;
    }
    self.warmupViewController.progress.progress = progress;
}

-(void)hideWarmup;
{
    if (self.warmupViewController && self.viewController.presentedViewController == self.warmupViewController)
    {
        [self.viewController dismissViewControllerAnimated:YES completion:^{
            self.warmupViewController = nil;
            [self.viewController presentViewController:self.loginViewController animated:true completion:nil];
//            [self performSelector:@selector(suggestServerUpload) withObject:nil afterDelay:4];
        }];
    }
}

-(void)suggestServerUpload;
{
    BOOL uploadingOn = [[NSUserDefaults standardUserDefaults] boolForKey:@"UploadToServer"];
    BOOL seenHint = [[NSUserDefaults standardUserDefaults] boolForKey:@"SeenHintToTurnOnServer"];
    if (!uploadingOn && !seenHint)
    {
        UIAlertController* alertController = [UIAlertController alertControllerWithTitle:@"Global Cosmic Ray Project"
                message:@"Please turn on server upload to help with the global cosmic ray observatory" preferredStyle:UIAlertControllerStyleAlert];
        [alertController addAction:[UIAlertAction actionWithTitle:@"Settings" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                [self.viewController helpButtonPressed:self];
                [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"SeenHintToTurnOnServer"];
            }]];
        
        [self.viewController presentViewController:alertController animated:YES completion:nil];
    }

}

- (void)applicationWillResignActive:(UIApplication *)application
{
    [self interactionOccured];
    self.screenSaverView.hidden = YES;

    /*
     Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
     Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
     */
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    [self interactionOccured];
    [[UIApplication sharedApplication] setIdleTimerDisabled:NO];
    self.screenSaverView.hidden = YES;


    /*
     Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later. 
     If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
     */
}

-(void)setUpChargingNotification
{
    [[UIDevice currentDevice] setBatteryMonitoringEnabled:YES];
    [self handleAllowSleep];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleAllowSleep) name:UIDeviceBatteryStateDidChangeNotification object:nil];
}

-(void)handleAllowSleep;
{
    UIDeviceBatteryState currentState = [[UIDevice currentDevice] batteryState];
    if (currentState == UIDeviceBatteryStateCharging || currentState == UIDeviceBatteryStateFull) {
        // The battery is either charging, or connected to a charger and is fully charged
        [[UIApplication sharedApplication] setIdleTimerDisabled:YES];
    } else {
        [[UIApplication sharedApplication] setIdleTimerDisabled:NO];
    }
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    [self interactionOccured];
    [((GLApplication*)[UIApplication sharedApplication]) resetIdleTimer];
    self.screenSaverView.hidden = YES;
    /*
     Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
     */
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    [self interactionOccured];
    [self handleAllowSleep];
    self.screenSaverView.hidden = YES;
    /*
     Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
     */
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    [self interactionOccured];

    /*
     Called when the application is about to terminate.
     Save data if appropriate.
     See also applicationDidEnterBackground:.
     */
}

const double kDimmedScreenBrightness = 0.0;
-(void)adjustBrightness;
{
    UIApplicationState appState = [UIApplication sharedApplication].applicationState;
    CGFloat currentBrightness = [UIScreen mainScreen].brightness;
    CGFloat desiredBrightness = gAppBrightness;
    if (appState != UIApplicationStateActive)
        desiredBrightness = gSavedSystemBrightness;
    
    if (fabs(desiredBrightness - currentBrightness) > 0.03)
    {
        //NSLog(@"adjusting brightness to %f", desiredBrightness); // [UIScreen mainScreen].wantsSoftwareDimming = YES did nothing on an iPhone 6s
        [[UIScreen mainScreen] setBrightness:desiredBrightness];
        
        if (desiredBrightness == gAppBrightness && desiredBrightness != gSavedSystemBrightness)
        {
            self.screenSaverView.frame = self.window.bounds;
            self.screenSaverView.hidden = NO;
        }
        else
        {
            self.screenSaverView.hidden = YES;
        }
    }
}

-(void)interactionOccured;
{
    gAppBrightness = gSavedSystemBrightness;
    [self adjustBrightness];
    self.screenSaverView.hidden = YES;
}

-(void)hasBeenIdleForAWhile;
{
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"dimScreen"])
        gAppBrightness = kDimmedScreenBrightness;
    else
        gAppBrightness = gSavedSystemBrightness;

    [self adjustBrightness];
}

@end
