//
//  GLCamera.m
//  GLCamera
//
//  Created by Grant Davis on 7/26/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "GLCamera.h"
#import "GLCameraAppDelegate.h"
#import <sys/utsname.h> // import it in your header or implementation file.

@interface GLCamera()
@property BOOL recordingShouldWork;

- (void) createSession;
@end


@implementation GLCamera
@synthesize session;
@synthesize videoPreviewLayer;
@synthesize delegate;

- (id)init
{
    self = [super init];
    if (self) {
        // Initialization code here.
        [self createSession];
    }
    
    return self;
}

+(NSString*)deviceName;
{
    struct utsname systemInfo;
    uname(&systemInfo);

    return [NSString stringWithCString:systemInfo.machine
                              encoding:NSUTF8StringEncoding];
}

+(double)getISO:(double)min max:(double)max;
{
    if (min > 400)
        return min;
    
    if (400 < max)
        return 400;
    
    return max;
}

// Dangerou call.  How do I know how cameras on iPhone 8s will work?
+(BOOL)isOlderPhoneOrIPad;
{
// http://stackoverflow.com/questions/11197509/ios-how-to-get-device-make-and-model
//@"iPhone5,1" on iPhone 5 (model A1428, AT&T/Canada)
//@"iPhone5,2" on iPhone 5 (model A1429, everything else)
//@"iPhone5,3" on iPhone 5c (model A1456, A1532 | GSM)
//@"iPhone5,4" on iPhone 5c (model A1507, A1516, A1526 (China), A1529 | Global)
//@"iPhone6,1" on iPhone 5s (model A1433, A1533 | GSM)
//@"iPhone6,2" on iPhone 5s (model A1457, A1518, A1528 (China), A1530 | Global)
//@"iPhone7,1" on iPhone 6 Plus
//@"iPhone7,2" on iPhone 6
//@"iPhone8,1" on iPhone 6S
//@"iPhone8,2" on iPhone 6S Plus
//@"iPhone8,4" on iPhone SE
//@"iPhone9,1" on iPhone 7 (CDMA)
//@"iPhone9,3" on iPhone 7 (GSM)
//@"iPhone9,2" on iPhone 7 Plus (CDMA)
//@"iPhone9,4" on iPhone 7 Plus (GSM)
    NSString* deviceName = [self deviceName];
    if ([deviceName containsString:@"iPhone4"])
        return YES;
    if ([deviceName containsString:@"iPhone5"])
        return YES;
    if ([deviceName containsString:@"iPhone6"])
        return YES;
    if ([deviceName containsString:@"iPhone7"])
        return YES;
    if ([deviceName containsString:@"iPhone8"])
        return YES;
    if ([deviceName containsString:@"iPhone8"])
        return YES;
    
    if ([deviceName containsString:@"iPad4"])
        return YES;
    if ([deviceName containsString:@"iPad5"])
        return YES;

    return NO;
}

+(void)unlockForConfig:(AVCaptureDevice *)device;
{
    //[device unlockForConfiguration]; // leave the device locked apple says this is ok. We need it for this app.
}

// we may want lowest rate, raw size, etc
+ (void)configureCameraForLowLight:(AVCaptureDevice *)device
{
    
    if ([device lockForConfiguration:NULL] == YES)
    {
        if ([device isFocusModeSupported:AVCaptureFocusModeLocked])
            device.focusMode = AVCaptureFocusModeLocked;
        
        if ([device isExposureModeSupported:AVCaptureExposureModeLocked])
            device.exposureMode = AVCaptureExposureModeLocked;
        [self unlockForConfig:device];
    }
    
    // can't get the settings right for iphone 7
    if (YES)//[self isOlderPhoneOrIPad])
    {
        AVCaptureDeviceFormat *bestFormat = nil;
        AVFrameRateRange *bestFrameRateRange = nil;
        double minFrameRate = 1000000000.0;
        double maxISO = 0;
        for ( AVCaptureDeviceFormat *format in [device formats] ) {
            NSLog(@"Format is %@, binned: %d, maxISO %f, minISO %f", [format description], (int) format.isVideoBinned, format.maxISO, format.minISO);
            for ( AVFrameRateRange *range in format.videoSupportedFrameRateRanges ) {
#if DEBUG
                NSLog(@"Min rate %f", range.minFrameRate);
#endif
                if ( range.minFrameRate <= minFrameRate && format.maxISO >= maxISO) {
                    bestFormat = format;
                    bestFrameRateRange = range;
                    minFrameRate = range.minFrameRate;
                }
            }
        }
        
#if DEBUG
        NSLog(@"BEST Format is %@, binned: %d, maxISO %f, minISO %f", [bestFormat description], (int) bestFormat.isVideoBinned, bestFormat.maxISO, bestFormat.minISO);
        NSLog(@"BEST Min rate %f, duration: %f", bestFrameRateRange.minFrameRate, bestFrameRateRange.maxFrameDuration);
#endif

        if (bestFormat) {
            if ([device lockForConfiguration:NULL] == YES)
            {
                device.activeFormat = bestFormat;
                double minFrameDuration = ((double)bestFrameRateRange.minFrameDuration.value)/bestFrameRateRange.minFrameDuration.timescale;
                double maxFrameDuration = ((double)bestFrameRateRange.maxFrameDuration.value)/bestFrameRateRange.maxFrameDuration.timescale;
                
#if DEBUG
                NSLog(@"min frame duration is %f, max %f", minFrameDuration, maxFrameDuration);
#endif

                
                if ([device isTorchModeSupported:AVCaptureTorchModeOff])
                    device.torchMode = AVCaptureTorchModeOff;

                // what do these calls do when apple says that
                device.activeVideoMinFrameDuration = bestFrameRateRange.minFrameDuration;
                device.activeVideoMaxFrameDuration = bestFrameRateRange.maxFrameDuration;
                
                // Apple says: This method is the only way of setting exposureDuration and ISO.
                if([device isExposureModeSupported:AVCaptureExposureModeCustom]){
                    [device setExposureMode:AVCaptureExposureModeCustom];
                
                   // [device setExposureModeCustomWithDuration:bestFrameRateRange.maxFrameDuration ISO:bestFormat.maxISO completionHandler:^(CMTime syncTime) {
                  // double isoToUse = (bestFormat.minISO + bestFormat.maxISO)/2.0;
                    @try
                    {
                        double isoToUse = [self getISO:bestFormat.minISO  max:bestFormat.maxISO];
                        [device setExposureModeCustomWithDuration:bestFrameRateRange.maxFrameDuration ISO:isoToUse completionHandler:^(CMTime syncTime) {
                            NSLog(@"exposure time set to %f", maxFrameDuration);
                        }];
                    }
                    @catch(NSException* ex)
                    {
                        NSLog(@"Well setExposureModeCustomWithDuration did not work!, %@", ex);
                    }
                    
//                    if (device.stillImageStabilizationSupported )
//                        device.automaticallyEnablesStillImageStabilizationWhenAvailable = NO;

    //                minExposureTargetBias
    //                maxExposureTargetBias
//                    double biasToUse = device.maxExposureTargetBias;
//                    [device setExposureTargetBias:biasToUse completionHandler:^(CMTime syncTime) {
//                        NSLog(@"exposure bias set to %f", (double) biasToUse);
//                    }];
                    
    //
    //    highResolutionStillImageDimensions
                
//                    if (device.lowLightBoostSupported)
//                        device.automaticallyEnablesLowLightBoostWhenAvailable = NO;
                    
//                    if (device.activeFormat.isVideoHDRSupported) {
//                        device.automaticallyAdjustsVideoHDREnabled = NO;
//                        device.videoHDREnabled = YES;
//                    }
                    
                    //device.highResolutionStillImageOutputEnabled = YES;
                    //automaticallyAdjustsVideoHDREnabled
                }
                
                [self unlockForConfig:device];
            }
        }
        
        if ([device lockForConfiguration:NULL] == YES)
        {
            if (device.lowLightBoostSupported)
                device.automaticallyEnablesLowLightBoostWhenAvailable = YES;
            
            [device setFocusModeLockedWithLensPosition:AVCaptureLensPositionCurrent completionHandler:nil];
            [self unlockForConfig:device];
        }
    }
}

//
- (void) createSession {
    // create a capture session
    session = [[AVCaptureSession alloc] init];
    
    
    // setup the device and input
    AVCaptureDevice *videoCaptureDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    NSError *error = nil;
    [GLCamera configureCameraForLowLight:videoCaptureDevice];
    
    AVCaptureDeviceInput *videoInput = [AVCaptureDeviceInput deviceInputWithDevice:videoCaptureDevice error:&error];
    
    if (videoInput) {
        self.recordingShouldWork = YES;
        [session addInput:videoInput];
        
        // Create a VideoDataOutput and add it to the session
        output = [[AVCaptureVideoDataOutput alloc] init];
        output.alwaysDiscardsLateVideoFrames = YES;
        [session addOutput:output];
        
        // Configure your output.
        dispatch_queue_t queue = dispatch_queue_create("myQueue", DISPATCH_QUEUE_SERIAL);
        [output setSampleBufferDelegate:self queue:queue];
        // ARC 2015 Tom dispatch_release(queue);
        
        // test - this looks like an old resolution setting, is 900 x 600 or like that on iPhone 5 session.sessionPreset = AVCaptureSessionPresetPhoto;
        
        if ([videoCaptureDevice supportsAVCaptureSessionPreset:AVCaptureSessionPreset3840x2160])
            session.sessionPreset = AVCaptureSessionPreset3840x2160;
        else if ([videoCaptureDevice supportsAVCaptureSessionPreset:AVCaptureSessionPreset1920x1080])
            session.sessionPreset = AVCaptureSessionPreset1920x1080;
        else
            session.sessionPreset = AVCaptureSessionPresetHigh;
        
        // Specify the pixel format
        
//        perhaps using native format will work - try setting videoSettings to nil
//        http://stackoverflow.com/questions/8838481/kcvpixelformattype-420ypcbcr8biplanarfullrange-frame-to-uiimage-conversion/31553521
//try it
        //output.videoSettings = nil; // usually results in a planar --
        output.videoSettings = [NSDictionary dictionaryWithObject:[NSNumber numberWithInt:kCVPixelFormatType_32BGRA]  forKey:(id)kCVPixelBufferPixelFormatTypeKey];
    }
    else { 
        // Handle the failure.
        self.recordingShouldWork = NO;
        NSLog(@"No camera input available.");
        
        [gAppD performSelector:@selector(hideWarmup) withObject:nil afterDelay:5];
    }
}

- (void)startSession {
    
    if( session == nil ) 
        [self createSession];
    
    if (self.recordingShouldWork)
        [session startRunning];
}


- (void)stopSession {
    [session stopRunning];
    session = nil;
    
    output = nil;
    
    videoPreviewLayer = nil;
}

- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    CVImageBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
	[self.delegate processNewCameraFrame:pixelBuffer];   
}



- (AVCaptureVideoPreviewLayer *)videoPreviewLayer;
{
	if (videoPreviewLayer == nil)
	{
		videoPreviewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:session];
        if (videoPreviewLayer.orientationSupported)
		{
            [videoPreviewLayer setOrientation:AVCaptureVideoOrientationPortrait];
        }
        
        [videoPreviewLayer setVideoGravity:AVLayerVideoGravityResizeAspectFill];
	}
	
	return videoPreviewLayer;
}


@end
