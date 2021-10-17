//
//  GLRawCamera.m
//  NaturalActivity
//
//  Created by Tom Andersen on 2016-01-01.
//
//

#import <AVFoundation/AVFoundation.h>
#import <QuartzCore/QuartzCore.h>
#import "GLRawCamera.h"
#import "GLCamera.h"

@interface GLRawCamera ()
@property (readwrite, nonatomic, strong) AVCaptureSession *captureSession;
@property (readwrite, nonatomic, strong) AVCaptureDevice *captureDevice;
@property (readwrite, nonatomic, strong) AVCaptureVideoPreviewLayer *previewLayer;
@property (readwrite, nonatomic, strong) AVCaptureStillImageOutput *imageOutput;
@end

#pragma mark -

@implementation GLRawCamera

static GLRawCamera *gSharedInstanceRawCamera = NULL;

+ (GLRawCamera *)sharedInstance
{
    static dispatch_once_t sOnceToken = 0;
    dispatch_once(&sOnceToken, ^{
        gSharedInstanceRawCamera = [[GLRawCamera alloc] init];
    });
    return(gSharedInstanceRawCamera);
}

- (id)init
{
    if ((self = [super init]) != NULL)
    {
        _captureDevicePosition = AVCaptureDevicePositionUnspecified;
        _preset = AVCaptureSessionPresetPhoto;
    }
    return(self);
}

- (void)dealloc
{
    [_captureSession stopRunning];
}

- (AVCaptureDevice *)captureDevice
{
    if (_captureDevice == NULL)
    {
        if (self.captureDevicePosition == AVCaptureDevicePositionUnspecified)
        {
            _captureDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
        }
        else
        {
            for (AVCaptureDevice *theDevice in [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo])
            {
                if (theDevice.position == self.captureDevicePosition)
                {
                    _captureDevice = theDevice;
                    break;
                }
            }
        }
        [self setDeviceForLowLight];
    }
    
    
    return(_captureDevice);
}

-(void)setDeviceForLowLight;
{
    [GLCamera configureCameraForLowLight:self.captureDevice];
}

- (AVCaptureVideoPreviewLayer *)previewLayer
{
    if (_previewLayer == NULL)
    {
        _previewLayer = [AVCaptureVideoPreviewLayer layerWithSession:self.captureSession];
    }
    return(_previewLayer);
}

- (void)startRunning
{
    NSError *theError = NULL;
    
    self.captureSession = [[AVCaptureSession alloc] init];
    self.captureSession.sessionPreset = self.preset;
    
    AVCaptureDeviceInput *theCaptureDeviceInput = [AVCaptureDeviceInput deviceInputWithDevice:self.captureDevice error:&theError];
    [self.captureSession addInput:theCaptureDeviceInput];
    
    self.imageOutput = [[AVCaptureStillImageOutput alloc] init];
    
    // kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange is native? I can also ask for 10 bit colour
    //  kCVPixelFormatType_32BGRA
    self.imageOutput.outputSettings = @{
                                        (__bridge NSString *)kCVPixelBufferPixelFormatTypeKey : @(kCVPixelFormatType_32BGRA)
                                        };
    [self.captureSession addOutput:self.imageOutput];
    
    [self.captureSession startRunning];
}

-(void)setForLowLight:(AVCaptureDeviceInput*)theCaptureDeviceInput;
{
    if (self.imageOutput.stillImageStabilizationSupported)
        self.imageOutput.automaticallyEnablesStillImageStabilizationWhenAvailable = NO;
    
    self.imageOutput.highResolutionStillImageOutputEnabled = YES;
}

- (void)stopRunning
{
    [self.captureSession stopRunning];
    
    self.captureDevice = NULL;
    self.captureSession = NULL;
    self.imageOutput = NULL;
    self.previewLayer = NULL;
}

-(BOOL)isRunning;
{
    if (self.captureSession)
        return YES;
    return NO;
}

- (CGSize)size
{
    AVCaptureConnection *theConnection = [self.imageOutput.connections objectAtIndex:0];
    
    __block BOOL theFinishedFlag = NO;
    __block CGSize theSize;
    
    [self.imageOutput captureStillImageAsynchronouslyFromConnection:theConnection completionHandler:^(CMSampleBufferRef imageDataSampleBuffer, NSError *error) {
        
        CVImageBufferRef theImageBuffer = CMSampleBufferGetImageBuffer(imageDataSampleBuffer);
        theSize = CVImageBufferGetEncodedSize(theImageBuffer);
        theFinishedFlag = YES;
    }];
    
    while (theFinishedFlag == NO)
    {
        [[NSRunLoop mainRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
    }
    
    return(theSize);
}

#pragma mark -

- (void)captureStillCMSampleBuffer:(void (^)(CMSampleBufferRef sampleBuffer, NSError *error))inCompletionBlock
{
    NSParameterAssert(inCompletionBlock != NULL);
    
    AVCaptureConnection *theConnection = [self.imageOutput.connections objectAtIndex:0];
    
    [self.imageOutput captureStillImageAsynchronouslyFromConnection:theConnection completionHandler:^(CMSampleBufferRef imageDataSampleBuffer, NSError *error) {
        inCompletionBlock(imageDataSampleBuffer, error);
    }];
}

- (void)captureStillCVImageBuffer:(void (^)(CVImageBufferRef imageBuffer, NSError *error))inCompletionBlock
{
    NSParameterAssert(inCompletionBlock != NULL);
    
    [self captureStillCMSampleBuffer:^(CMSampleBufferRef sampleBuffer, NSError *error) {
        CVImageBufferRef theImageBuffer = NULL;
        if (sampleBuffer != NULL)
        {
            theImageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
        }
        
        inCompletionBlock(theImageBuffer, error);
    }];
}

- (void)captureStillCIImage:(void (^)(CIImage *image, NSError *error))inCompletionBlock
{
    NSParameterAssert(inCompletionBlock != NULL);
    
    [self captureStillCVImageBuffer:^(CVImageBufferRef imageBuffer, NSError *error) {
        CIImage *theImage = NULL;
        if (imageBuffer != NULL)
        {
            theImage = [CIImage imageWithCVPixelBuffer:imageBuffer];
        }
        inCompletionBlock(theImage, error);
    }];
}

- (void)captureStillCGImage:(void (^)(CGImageRef image, NSError *error))inCompletionBlock
{
    NSParameterAssert(inCompletionBlock != NULL);
    
    [self captureStillCIImage:^(CIImage *image, NSError *error) {
        
        CGImageRef theCGImage = NULL;
        if (image != NULL)
        {
            NSDictionary *theOptions = @{
                                         // TODO
                                         };
            CIContext *theCIContext = [CIContext contextWithOptions:theOptions];
            theCGImage = [theCIContext createCGImage:image fromRect:image.extent];
        }
        
        inCompletionBlock(theCGImage, error);
        
        CGImageRelease(theCGImage);
    }];
}

- (void)captureStillUIImage:(void (^)(UIImage *image, NSError *error))inCompletionBlock
{
    NSParameterAssert(inCompletionBlock != NULL);
    
    [self captureStillCIImage:^(CIImage *image, NSError *error) {
        
        UIImage *theUIImage = NULL;
        if (image != NULL)
        {
            theUIImage = [UIImage imageWithCIImage:image];
        }
        
        inCompletionBlock(theUIImage, error);
    }];
}

@end
