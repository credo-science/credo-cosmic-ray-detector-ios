//
//  GLStillCamera.h
//  NaturalActivity
//
//  Created by Tom Andersen on 2016-01-01.
//
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

@interface GLStillCamera : NSObject

@property (readwrite, nonatomic, assign) AVCaptureDevicePosition captureDevicePosition;
@property (readwrite, nonatomic, strong) NSString *preset;
@property (readonly, nonatomic, strong) AVCaptureDevice *captureDevice;
@property (readonly, nonatomic, strong) AVCaptureVideoPreviewLayer *previewLayer;

+ (GLStillCamera *)sharedInstance;

- (void)startRunning;
- (void)stopRunning;

-(BOOL)isRunning;

- (CGSize)size;

- (void)captureStillCMSampleBuffer:(void (^)(CMSampleBufferRef sampleBuffer, NSError *error))inCompletionBlock;
- (void)captureStillCVImageBuffer:(void (^)(CVImageBufferRef imageBuffer, NSError *error))inCompletionBlock;
- (void)captureStillCIImage:(void (^)(CIImage *image, NSError *error))inCompletionBlock;
- (void)captureStillCGImage:(void (^)(CGImageRef image, NSError *error))inCompletionBlock;
- (void)captureStillUIImage:(void (^)(UIImage *image, NSError *error))inCompletionBlock;

@end

