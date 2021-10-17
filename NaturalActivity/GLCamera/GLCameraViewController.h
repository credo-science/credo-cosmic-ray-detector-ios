//
//  GLCameraViewController.h
//  GLCamera
//
//  Created by Grant Davis on 7/26/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>

#import <AVFoundation/AVFoundation.h>
#import <CoreLocation/CoreLocation.h>
#import <QuartzCore/QuartzCore.h>
#import <CoreVideo/CoreVideo.h>
#import "GLCamera.h"
#import "GLStillCamera.h"
#import "SwipeView.h"
#import "MetalPixelProcessor.h"

#define kBlocksPerEvent 9


@interface GLCameraViewController : UIViewController <GLCameraDelegate, SwipeViewDataSource, SwipeViewDelegate, CLLocationManagerDelegate>

@property CLGeocoder *geoCoder;
@property CLLocationManager *locationManager;
@property CLLocation *recentLocation;

@property GLCamera* videoCamera;
@property GLStillCamera* stillCamera;
@property BOOL useVideoFrames;
@property BOOL showingTop;

// Dark frame adding.
@property long sessionFrameCount;
@property double timeConstant;

/// stats
@property double totalFramesAnalyzed;
@property double totalLiveBlocks;
@property long liveBlocksThisFrame;
@property long maxLiveBlocksOneFrame;
@property long bigEventCount;
@property BOOL radiationEventFound;
@property long hotPixelCount;
@property double biggestBlockThisFrame;
@property double biggestBlockThisFrame2nd;
@property double biggestBlockAverage;

@property (strong) IBOutlet UILabel* totalFramesAnalyzedLabel;
@property (strong) IBOutlet UILabel* totalLiveBlocksLabel;
@property (strong) IBOutlet UILabel* liveBlocksThisFrameLabel;
@property (strong) IBOutlet UILabel* hotPixelCountLabel;

@property (strong) IBOutlet UIImage* latestImage;
@property (strong) NSMutableArray* foundEvents;
@property (strong, nonatomic) IBOutlet SwipeView *swipeView;
@property (strong, nonatomic) IBOutlet UIButton *topTenButton;
- (IBAction)helpButtonPressed:(id)sender;
@property (strong, nonatomic) IBOutlet UIBarButtonItem *eventsCount;
@property (strong, nonatomic) IBOutlet UIBarButtonItem *showTopButton;

// stats
@property long eventCount;

// buffers
@property double pixelCount;
@property long bufferWidth;
@property long bufferHeight;

@property uint8_t* buffer;
@property long bytesPerRow;

@property float* pixelHeatMap;
@property float* triggerMap;
@property long triggerMap_Height;
@property long triggerMap_Width;

@property MetalPixelProcessor* metalPipeline;


-(IBAction)saveImageToCameraRoll:(id)sender;
- (IBAction)toggleTop10:(id)sender;

+(NSString*)serverBase;
+(BOOL)locationServicesON;
+(NSString*)deviceModel;

+(BOOL)olderModelDevice;
+(BOOL)calculatePixelModeForLowLevelPixels;
+(BOOL)shouldUseVideoMode;


@end
