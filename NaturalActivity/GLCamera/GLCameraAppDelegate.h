//
//  GLCameraAppDelegate.h
//  GLCamera
//
//  Created by Grant Davis on 7/26/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>

@class GLCameraViewController;
@class WarmupViewController;
@class MyLoginViewController;


@interface GLCameraAppDelegate : UIResponder <UIApplicationDelegate>

@property (strong, nonatomic) UIWindow *window;

@property (strong, nonatomic) GLCameraViewController *viewController;
@property (strong, nonatomic) WarmupViewController *warmupViewController;
@property(nonatomic, strong) MyLoginViewController *loginViewController;
@property UIView* screenSaverView;

-(void)showWarmup:(double)progress;
-(void)hideWarmup;

// brightness control
-(void)interactionOccured;
-(void)hasBeenIdleForAWhile;

@end

extern GLCameraAppDelegate* gAppD;
