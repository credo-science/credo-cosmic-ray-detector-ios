//
//  GLCameraViewController.m
//  GLCamera
//
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <QuartzCore/QuartzCore.h>
#import <Photos/Photos.h>
#import <AssetsLibrary/AssetsLibrary.h>
#import <CoreLocation/CoreLocation.h>
#import <sys/utsname.h>

#import "GLCameraViewController.h"
#import "EAGLView.h"
#import "RadiationEvent.h"
#import "GLCameraAppDelegate.h"
#import "WarmupViewController.h"
#import "HelpViewController.h"

#import "JTSImageViewController.h"
#import "pixelMath.h"

#define PLAY_SOUNDS 0

#import "Cosmic_Ray-Swift.h"

const long kNumToShowInTop = 150;


// Uniform index.
enum {
    UNIFORM_VIDEOFRAME,
    UNIFORM_INPUTCOLOR,
    UNIFORM_THRESHOLD,
    NUM_UNIFORMS
};
GLint uniforms[NUM_UNIFORMS];

// Attribute index.
enum {
    ATTRIB_VERTEX,
    ATTRIB_TEXTUREPOSITON,
    NUM_ATTRIBUTES
};

typedef struct minMax_s {
    long minCol;
    long maxCol;
    long minRow;
    long maxRow;
} minMaxRect;

// Uniform index.
//enum {
//    UNIFORM_TRANSLATE,
//    NUM_UNIFORMS
//};
//GLint uniforms[NUM_UNIFORMS];
//
//// Attribute index.
//enum {
//    ATTRIB_VERTEX,
//    ATTRIB_COLOR,
//    NUM_ATTRIBUTES
//};

const double kDesiredFrameIntervalSeconds = 30.0;


@interface GLCameraViewController ()
- (void)applicationWillResignActive:(NSNotification *)notification;
- (void)applicationDidBecomeActive:(NSNotification *)notification;
- (void)applicationWillTerminate:(NSNotification *)notification;

@property AVAudioPlayer *player;
@property NSTimeInterval averageSecondsBetweenImages;
@property NSDate* lastImageDate;
@property double thresholdFactor;

@property NSDate* rayTime;
@property NSMutableArray* blockImages;

@property WarmupViewController *warmupViewController;

@property BOOL deviceIsOlderNeedsPixelBoost;
@end

@implementation GLCameraViewController

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.lastImageDate = [NSDate date];
    self.averageSecondsBetweenImages = kDesiredFrameIntervalSeconds;
    self.thresholdFactor = 2.2;

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationWillResignActive:) name:UIApplicationWillResignActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidBecomeActive:) name:UIApplicationDidBecomeActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationWillTerminate:) name:UIApplicationWillTerminateNotification object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self // put here the view controller which has to be notified
                                             selector:@selector(orientationChanged:)
                                                 name:@"UIDeviceOrientationDidChangeNotification"
                                               object:nil];
    // time constant. ~ number of frames to average over.
    self.timeConstant = 0.04; // connect to time constant of camera pixels and more importantly glow time on the scinitilator.
    [self updateUI];
    [self geoLocation];

    if (self.useVideoFrames)
    {
        self.videoCamera = [[GLCamera alloc] init];
        self.videoCamera.delegate = self;
        [self.videoCamera startSession];
    }
    else
    {
        self.stillCamera = [GLStillCamera sharedInstance];
        self.stillCamera.captureDevicePosition = AVCaptureDevicePositionBack;
        [self.stillCamera startRunning];
        [self takeAPhoto];
    }
    
    self.foundEvents = [NSMutableArray array];
    self.swipeView.dataSource = self;
    self.swipeView.delegate = self;
    self.swipeView.alignment = SwipeViewAlignmentCenter;
    
    [NSTimer scheduledTimerWithTimeInterval:0.25 target:self selector:@selector(timerCall:) userInfo:nil repeats:YES];
    
    NSString *soundFilePath = [[NSBundle mainBundle] pathForResource:@"clicksound.mp3" ofType:nil];
    NSURL *soundFileURL = [NSURL fileURLWithPath:soundFilePath];
    self.player = [[AVAudioPlayer alloc] initWithContentsOfURL:soundFileURL error:nil];
    
    self.player.enableRate=YES;
    [self.player prepareToPlay];
//    [player setNumberOfLoops:0];
    self.player.rate=0.5f;

    self.blockImages = [NSMutableArray array];
    
#if PLAY_SOUNDS
    [self.player play];
#endif
    self.biggestBlockAverage = 0.0;
    
    self.deviceIsOlderNeedsPixelBoost = [GLCameraViewController calculatePixelModeForLowLevelPixels];
}

+(BOOL)olderModelDevice;
{
    // iPhone8,1 etc iPhone 6s is iPhone8,1 while iPhone 5 is iPhone5,1
    NSString* deviceString = [GLCameraViewController deviceModel];
    if ([deviceString containsString:@"iPhone3"])
        return  YES;
    if ([deviceString containsString:@"iPhone4"])
        return  YES;
    if ([deviceString containsString:@"iPhone5"])
        return  YES;
    if ([deviceString containsString:@"iPhone6"])
        return  YES;
    if ([deviceString containsString:@"iPhone7"])
        return  YES;

    if ([deviceString containsString:@"iPod4"])
        return  YES;
    if ([deviceString containsString:@"iPod5"])
        return  YES;
    if ([deviceString containsString:@"iPad1"])
        return  YES;

    return NO;
}

// Mar 2018
// On older cameras, the pixels need sqrt() brightening.
// This is all for video mode capture.
+(BOOL)calculatePixelModeForLowLevelPixels;
{
    return [self olderModelDevice];
}

+(BOOL)shouldUseVideoMode;
{
    return [self olderModelDevice];
}


#pragma mark - Threaded callback from frame ready
-(void)setBufferPixel:(double)red green:(double)green blue:(double)blue countH:(long)countH countW:(long)countW;
{
    unsigned char *pixel = self.buffer + (countH * self.bytesPerRow) + (countW*4);
    
    double max = fmax(fmax(red, green), blue);
    
    if (max == 0.0)
    {
        pixel[0] = 0;
        pixel[1] = 0;
        pixel[2] = 0;
        pixel[3] = 0;
    }
    else
    {
        pixel[0] = red/max*255;
        pixel[1] = green/max*255;
        pixel[2] = blue/max*255;
        pixel[3] = 255;
    }
}
-(void)setBufferPixelDirect:(double)red green:(double)green blue:(double)blue countH:(long)countH countW:(long)countW;
{
    unsigned char *pixel = self.buffer + (countH * self.bytesPerRow) + (countW*4);
    pixel[0] = red;
    pixel[1] = green;
    pixel[2] = blue;
    pixel[3] = 255;
}

const long kTriggerZoneSize = 20;
const double kPixelTooHot = 8.0; // 10 is for iphone 5 pixels that are on average this value or higher don't count, they are hot.

const long kBadEdgeBlocks = 3;

// does not update the heatmap.
-(void)calculateTriggerBlocks:(uint8_t*)pixels;
{
#if DEBUG
    double start = [NSDate timeIntervalSinceReferenceDate];
#endif
    const long bufWidth = self.bufferWidth;
    const long bytesPerRow = self.bytesPerRow;
    float* heatMap = self.pixelHeatMap;

    for (long countTH = kBadEdgeBlocks; countTH < self.triggerMap_Height - kBadEdgeBlocks; countTH++)
    {
        float* triggerBlockRow = self.triggerMap + (countTH*self.triggerMap_Width);
        for (long countTW = kBadEdgeBlocks; countTW < self.triggerMap_Width - kBadEdgeBlocks; countTW++)
        {
            // add up the scores on each block.
            float blockScore = 0;
            for (long countH = countTH*kTriggerZoneSize; countH < (countTH + 1)*kTriggerZoneSize; countH++)
            {
                uint8_t* row = pixels + (countH * bytesPerRow);
                float* heatMapRow = heatMap + (countH*bufWidth);
                
                long startLoop = countTW*kTriggerZoneSize;
                long endLoop = (countTW + 1)*kTriggerZoneSize;
                
                for (long countW = startLoop; countW < endLoop; countW++)
                {
                    uint8_t* pixel = row + (countW*4);
                    long red = pixel[0];
                    long green = pixel[1];
                    long blue = pixel[2];
                    long total = red + green + blue;
                    blockScore += pixelScore(total, heatMapRow[countW]);
                }
            }
            triggerBlockRow[countTW] = blockScore;
        }
    }

    
#if DEBUG
    double end = [NSDate timeIntervalSinceReferenceDate];
    NSLog(@"trigger calculate time %f, sizeof(int) %d, sizeof(long) %d", end - start, (int) sizeof(int), (int) sizeof(long));
#endif
}

-(void)compareTriggerBlocks:(float*)triggerBlocks gpuOnes:(float*)gpuOnes;
{
    for (long countTH = kBadEdgeBlocks; countTH < self.triggerMap_Height - kBadEdgeBlocks; countTH++)
    {
        float* triggerBlockRow = triggerBlocks + (countTH*self.triggerMap_Width);
        float* gpuBlockRow = gpuOnes + (countTH*self.triggerMap_Width);
        for (long countTW = kBadEdgeBlocks; countTW < self.triggerMap_Width - kBadEdgeBlocks; countTW++)
        {
            float blockScore = triggerBlockRow[countTW];
            float gpuScore = gpuBlockRow[countTW];
            if (fabs(gpuScore - blockScore)/(blockScore + gpuScore) > 0.3)
            {
                static int count = 0;
                if (count++ % 100 == 0)
                    NSLog(@"gpuScore %f - blockScore %f", gpuScore, blockScore);
            }
        }
    }
}


-(void)doTriggerBlockStats:(float*)triggerBlocks;
{
    self.biggestBlockThisFrame = 0;
    self.biggestBlockThisFrame2nd = 0;
    self.totalFramesAnalyzed++;
    for (long countTH = kBadEdgeBlocks; countTH < self.triggerMap_Height - kBadEdgeBlocks; countTH++)
    {
        float* triggerBlockRow = triggerBlocks + (countTH*self.triggerMap_Width);
        for (long countTW = kBadEdgeBlocks; countTW < self.triggerMap_Width - kBadEdgeBlocks; countTW++)
        {
            float blockScore = triggerBlockRow[countTW];
            if (blockScore > self.biggestBlockThisFrame2nd)
            {
                if (blockScore > self.biggestBlockThisFrame)
                {
                    self.biggestBlockThisFrame2nd = self.biggestBlockThisFrame;
                    self.biggestBlockThisFrame = blockScore; // leave biggest block out of the average calc
                }
                else
                {
                    self.biggestBlockThisFrame2nd = blockScore;
                }
            }
        }
    }

    const double kBigBlockMemory = 0.1; // total up about the last  few frames to get running average noise
    if (self.biggestBlockAverage == 0.0)
    {
        self.biggestBlockAverage = self.biggestBlockThisFrame2nd;
    }
    else
    {
        self.biggestBlockAverage = kBigBlockMemory*self.biggestBlockThisFrame2nd + (1.0 - kBigBlockMemory)*self.biggestBlockAverage;
    }
}

// returns YES for very bright event.
-(BOOL)lightUpTriggeredBlocks:(uint8_t*)pixels triggerMap:(float*)triggerMap;
{
    [self.blockImages removeAllObjects];
    BOOL brightEventFound = NO;
    //    double totalPixelsPerScore = kTriggerZoneSize*kTriggerZoneSize;
//    double kLitPixel = 3.0;
    //double thresholdFactor = sqrt(totalPixelsPerScore)*kLitPixel;
    double threshold = self.biggestBlockAverage*self.thresholdFactor;//*2.0; // 1.29 was here for still camera... 2.0 on iphone 5, 2.0 on iphone 6 as well.
//    double thresholdSecondary = threshold*0.4;
    self.liveBlocksThisFrame = 0;
    for (long countTH = kBadEdgeBlocks; countTH < (self.triggerMap_Height - kBadEdgeBlocks); countTH++) // start at kBadEdgeBlocks to keep from the edges, as they act up.
    {
        float* triggerBlockRow = triggerMap + (countTH*self.triggerMap_Width);
        for (long countTW = kBadEdgeBlocks; countTW < (self.triggerMap_Width - kBadEdgeBlocks); countTW++) // 2 means keep from edges.
        {
            // A block can trigger on its own, or if that fails look at neighbors.
            double score = triggerBlockRow[countTW];
            if (score > threshold)
            {
#if DEBUG
                NSLog(@"Found block, score %f, threshold: %f, thresholdFactor: %f, avseconds: %f", score, threshold, self.thresholdFactor, self.averageSecondsBetweenImages);
#endif
                if (score > threshold*2.0)
                {
#if DEBUG
                    NSLog(@"***** BRIGHT Found block, score %f", score);
#endif

                    brightEventFound = YES;
                }
                
                double maxPixelComponent = [self maxPixelComponent:pixels countTH:countTH countTW:countTW];
                
                [self copyBlockToDisplayBuffer:pixels countTH:countTH countTW:countTW maxPixelComponent:maxPixelComponent];
                self.liveBlocksThisFrame++;
                self.totalLiveBlocks++;
                self.radiationEventFound = YES;
                [self updateStats];

                [self addImageDataForExport:pixels countTH:countTH countTW:countTW maxPixelComponent:maxPixelComponent];
                
                // Try showing all 9 blocks around the lit up one.
                for (long countW = -1; countW <= 1; countW++)
                {
                    [self copyBlockToDisplayBuffer:pixels countTH:countTH - 1 countTW:countTW + countW maxPixelComponent:maxPixelComponent];
                    self.liveBlocksThisFrame++;
                    self.totalLiveBlocks++;
                    
                    if (countW) // skip central, we already got it.
                    {
                        [self copyBlockToDisplayBuffer:pixels countTH:countTH countTW:countTW + countW maxPixelComponent:maxPixelComponent];
                        self.liveBlocksThisFrame++;
                        self.totalLiveBlocks++;
                    }
                    
                    [self copyBlockToDisplayBuffer:pixels countTH:countTH + 1 countTW:countTW + countW maxPixelComponent:maxPixelComponent];
                    self.liveBlocksThisFrame++;
                    self.totalLiveBlocks++;
                }
            }
            else
            {
            }
        }
    }
    if (self.liveBlocksThisFrame > self.maxLiveBlocksOneFrame)
        self.maxLiveBlocksOneFrame = self.liveBlocksThisFrame;
    return brightEventFound;
}

-(double)maxPixelComponent:(uint8_t*)pixels countTH:(long)countTH countTW:(long)countTW;
{
    double max = 1;
    for (long countH = countTH*kTriggerZoneSize; countH < (countTH + 1)*kTriggerZoneSize; countH++)
    {
        uint8_t* row = pixels + (countH * self.bytesPerRow);
        for (long countW = countTW*kTriggerZoneSize; countW < (countTW + 1)*kTriggerZoneSize; countW++)
        {
            uint8_t* pixel = row + (countW*4);
            
            double red = pixel[0];
            double green = pixel[1];
            double blue = pixel[2];
            double biggest = fmax(red, fmax(blue, green));
            if (biggest > max)
                max = biggest;
        }
    }
    return max;
}

-(void)copyBlockToDisplayBuffer:(uint8_t*)pixels countTH:(long)countTH countTW:(long)countTW maxPixelComponent:(double)maxPixelComponent;
{
//    if (maxPixelComponent < 30.0)
//        maxPixelComponent = 30.0;
    double brightness = 1.0/maxPixelComponent*sqrt(sqrt(maxPixelComponent/255.0)); // if max is say 30, then we only boost to 0.58 - so brightness will be lower on pixels that are not fully lit. Allows real events to stand out.
    
    //double brightness = 10.0/255.0; // mult be 10 and normalize
    
    BOOL needLowLevelBoost = self.deviceIsOlderNeedsPixelBoost;
    
    for (long countH = countTH*kTriggerZoneSize; countH < (countTH + 1)*kTriggerZoneSize; countH++)
    {
        uint8_t* row = pixels + (countH * self.bytesPerRow);
        for (long countW = countTW*kTriggerZoneSize; countW < (countTW + 1)*kTriggerZoneSize; countW++)
        {
            uint8_t* pixel = row + (countW*4);
            
            // mult by brightness, make unit 0  --> 1
            double red = fmin(pixel[0]*brightness, 1.0);
            double green = fmin(pixel[1]*brightness, 1.0);
            double blue = fmin(pixel[2]*brightness, 1.0);
            
            // use sqrt to get more detail from the lower lit pixels.
            if (needLowLevelBoost)
            {
                red = sqrt(red);
                green = sqrt(green);
                blue = sqrt(blue);
            }
            
            [self setBufferPixelDirect:255.0*red green:255.0*green blue:255.0*blue countH:countH countW:countW];
        }
    }

}
-(void)addImageDataForExport:(uint8_t*)pixels countTH:(long)countTH countTW:(long)countTW maxPixelComponent:(double)maxPixelComponent;
{
    if (self.blockImages.count > 200)
        return; // daylight
    
    double brightness = 1.0/maxPixelComponent*sqrt(sqrt(maxPixelComponent/255.0)); // if max is say 30, then we only boost to 0.58 - so brightness will be lower on pixels that are not fully lit. Allows real events to stand out.
    
    // we grab a 9 trigger zone region
    countTH -= 1;
    countTW -= 1;
    
    long width = kTriggerZoneSize*3;
    long height = kTriggerZoneSize*3;
    long bytesPerRow = width*4;
    BOOL needLowLevelBoost = self.deviceIsOlderNeedsPixelBoost;

    uint8_t* newImagePixels = malloc(width*height*4);
    long newH = 0;
    for (long countH = countTH*kTriggerZoneSize; countH < (countTH + 3)*kTriggerZoneSize; countH++)
    {
        uint8_t* row = pixels + (countH * self.bytesPerRow);
        long newW = 0;
        for (long countW = countTW*kTriggerZoneSize; countW < (countTW + 3)*kTriggerZoneSize; countW++)
        {
            uint8_t* pixel = row + (countW*4);
            
            // mult by brightness, make unit 0  --> 1
            double red = fmin(pixel[0]*brightness, 1.0);
            double green = fmin(pixel[1]*brightness, 1.0);
            double blue = fmin(pixel[2]*brightness, 1.0);
            
            // use sqrt to get more detail from the lower lit pixels.
            if (needLowLevelBoost)
            {
                red = sqrt(red);
                green = sqrt(green);
                blue = sqrt(blue);
            }
            
            unsigned char *pixelToSet = newImagePixels + (newH * bytesPerRow) + (newW*4);
            pixelToSet[0] = red*255.0;
            pixelToSet[1] = green*255.0;
            pixelToSet[2] = blue*255.0;
            pixelToSet[3] = 255;
            newW++;
        }
        newH++;
    }
    UIImage* outImage = [[self class] makeImage:newImagePixels width:width height:height];
    NSString *base64String = [UIImagePNGRepresentation(outImage) base64EncodedStringWithOptions:0];
    free(newImagePixels);
    newImagePixels = nil;
    NSMutableDictionary* imageDict = [NSMutableDictionary dictionary];
    
    // need [:origin_x, :origin_y, :width, :height, :pngDataBase64]
    imageDict[@"origin_x"] = @(countTH*kTriggerZoneSize);
    imageDict[@"origin_y"] = @(countTW*kTriggerZoneSize);
    imageDict[@"width"] = @(width);
    imageDict[@"height"] = @(height);
    imageDict[@"pngDataBase64"] = base64String;
    
#if DEBUG
    @synchronized(self) {
        static NSMutableDictionary* imageLocations = nil;
        if (!imageLocations)
            imageLocations = [NSMutableDictionary dictionary];
        static NSMutableDictionary* imageCounts = nil;
        if (!imageCounts)
            imageCounts = [NSMutableDictionary dictionary];
        
        static int countImages = 0;
        countImages++;
        static int totalImages = 0;
        totalImages++;

        NSString* imageDesc = [NSString stringWithFormat:@"H %d, V %d", (int) (countTH*kTriggerZoneSize), (int) (countTW*kTriggerZoneSize)];
        NSLog(@"%@", imageDesc);
        NSDate* lastOneAtThisLocation = [imageLocations objectForKey:imageDesc];
        long numberAtThisLocation = [[imageCounts objectForKey:imageDesc] integerValue];

        if (lastOneAtThisLocation)
        {
            if (numberAtThisLocation == 0)
                numberAtThisLocation = 1; // only record duplicates in imageCounts array
            numberAtThisLocation++;
            NSLog(@"Images at same location - lastone was %d seconds ago, imageCount %d", (int) -[lastOneAtThisLocation timeIntervalSinceNow], countImages);
            long numBlocksW = self.bufferWidth/kTriggerZoneSize - kBadEdgeBlocks;
            long numBlocksH = self.bufferHeight/kTriggerZoneSize - kBadEdgeBlocks;
            NSLog(@"Expect one per %d images, %d at this location so far", (int) (numBlocksW*numBlocksH), (int)numberAtThisLocation);
            NSLog(@"There are %d multiple entries for %d totalImages", (int) (imageCounts.count), (int)totalImages);
            countImages = 0;
            NSLog(@"**************");
            [imageCounts setObject:@(numberAtThisLocation) forKey:imageDesc];
        }
        [imageLocations setObject:[NSDate date] forKey:imageDesc];
    }
#endif

    [self.blockImages addObject:imageDict];
}





// When we use a pixel to calculate a trigger block, it means it went off - so we turn it up so that it will take many frames to average down
//
// we need the integer math  INT_MAX = kHeatMapMemoryTimesScaleInt*(255*3.0) + kOneMinusHeatMapInt*kVeryBrightPixel
// never overflow. Total can be 768, so figure that out,
-(void)updatePixelHeatMap:(uint8_t*)pixels;
{
#if DEBUG
    double start = [NSDate timeIntervalSinceReferenceDate];
#endif
    const long bufHeight = self.bufferHeight;
    const long bufWidth = self.bufferWidth;
    const long bytesPerRow = self.bytesPerRow;
    float* heatMap = self.pixelHeatMap;
    for (long countH = 0; countH < bufHeight; countH++)
    {
        uint8_t* row = pixels + (countH * bytesPerRow);
        float* heatMapRow = heatMap + (countH*bufWidth);
        for (long countW = 0; countW < bufWidth; countW++)
        {
            unsigned char *pixel = row + (countW*4);
            long red = pixel[0];
            long green = pixel[1];
            long blue = pixel[2];

            long total = red + green + blue;
            heatMapRow[countW] = heatMapUpdate(total, heatMapRow[countW]);
        }
    }
#if DEBUG
    double end = [NSDate timeIntervalSinceReferenceDate];
    NSLog(@"heat map time %f", end - start);
#endif
}

-(void)heatMapInitialize:(uint8_t*)pixels;
{
    const long bufHeight = self.bufferHeight;
    const long bufWidth = self.bufferWidth;
    const long bytesPerRow = self.bytesPerRow;
    float* heatMap = self.pixelHeatMap;
    for (long countH = 0; countH < bufHeight; countH++)
    {
        uint8_t* row = pixels + (countH * bytesPerRow);
        float* heatMapRow = heatMap + (countH*bufWidth);
        for (long countW = 0; countW < bufWidth; countW++)
        {
            unsigned char *pixel = row + (countW*4);
            long red = pixel[0];
            long green = pixel[1];
            long blue = pixel[2];
            
            long total = red + green + blue;
            heatMapRow[countW] = heatMapInitial(total);
        }
    }
}





- (void)processNewCameraFrame:(CVImageBufferRef)cameraFrame {
    self.rayTime = [NSDate date];
    // http://stackoverflow.com/questions/4036737/how-to-draw-a-texture-as-a-2d-background-in-opengl-es-2-0
    CVPixelBufferLockBaseAddress(cameraFrame, 0);
    uint8_t* pixels = (uint8_t*)CVPixelBufferGetBaseAddress(cameraFrame);
    
    if (!pixels)
    {
        CVPixelBufferUnlockBaseAddress(cameraFrame, 0);
        return;
    }
    
    if (self.buffer == nil)
    {
        long bufferH = (long) CVPixelBufferGetHeight(cameraFrame);
        long bufferW = (long) CVPixelBufferGetWidth(cameraFrame);
        self.pixelCount = bufferH*bufferW;
        self.bufferWidth = bufferW;
        self.bufferHeight = bufferH;
        self.bytesPerRow = (long)CVPixelBufferGetBytesPerRow(cameraFrame);
        self.buffer = calloc(bufferH, self.bytesPerRow);
        self.pixelHeatMap = calloc(self.bufferHeight, sizeof(float)*self.bufferWidth);
        self.sessionFrameCount = 0;
        self.totalFramesAnalyzed = 0;
        self.triggerMap_Height = self.bufferHeight/kTriggerZoneSize;
        self.triggerMap_Width = self.bufferWidth/kTriggerZoneSize;
        self.triggerMap = calloc(self.triggerMap_Height, sizeof(float)*self.triggerMap_Width);
        [self heatMapInitialize:pixels]; // do an intial heat map update for the GPU/cpu heat maps
        self.metalPipeline = [[MetalPixelProcessor alloc] initWithWidth:bufferW height:bufferH blockSize:kTriggerZoneSize initialHeat:self.pixelHeatMap];
    }
    
    self.sessionFrameCount++;
    

    float* theTriggerMap = nil;
    [self performSelectorOnMainThread:@selector(updateWarmupProgress:) withObject:@(self.sessionFrameCount/30.0) waitUntilDone:NO];
    if (self.sessionFrameCount < 30)
    {
        if (self.metalPipeline.device) {
            [self.metalPipeline calculateTriggerBlocks:pixels blocks:&theTriggerMap];
#if DEBUG_COMPARE_METAL
            [self updatePixelHeatMap:pixels];
#endif
        }
        else
            [self updatePixelHeatMap:pixels];
        CVPixelBufferUnlockBaseAddress(cameraFrame, 0);
        return; // let heat map come up to speed.
    }
    

    // calaculate score in each of the self.triggerMap_numH*self.triggerMap_numV
    // each pixel's average score is subtracted so we can look for heat.
    if (self.metalPipeline.device)
    {
        [self.metalPipeline calculateTriggerBlocks:pixels blocks:&theTriggerMap];
    }
    else
    {
        [self calculateTriggerBlocks:pixels];
        if (self.sessionFrameCount % 3 == 0)
            [self updatePixelHeatMap:pixels];
        theTriggerMap = self.triggerMap;
    }
    [self doTriggerBlockStats:theTriggerMap];
#if DEBUG_COMPARE_METAL
    double gpuBiggestBlock = self.biggestBlockThisFrame;
    NSLog(@"checking trigger blocks GPU %f, %f", self.biggestBlockThisFrame, self.biggestBlockThisFrame2nd);
    [self calculateTriggerBlocks:pixels];
    [self updatePixelHeatMap:pixels];
    [self doTriggerBlockStats:self.triggerMap];
    [self compareTriggerBlocks:self.triggerMap gpuOnes:theTriggerMap];
    double ratio = gpuBiggestBlock/self.biggestBlockThisFrame;
    NSLog(@"Ratio %f, checking trigger blocks OLD %f, %f", ratio, self.biggestBlockThisFrame, self.biggestBlockThisFrame2nd);
#endif
    
    
    BOOL brightFound = [self lightUpTriggeredBlocks:pixels triggerMap:theTriggerMap];
    
    if (self.radiationEventFound)
    {
        //API  Add the event as a json file to be uploaded to the server, usually this takes place real time, but it does not have to.
        [self createJSONOfEvent];
        
        UIImage* currentImage = [self makeNewImage];
        if (currentImage)
        {
            [self performSelectorOnMainThread:@selector(updateImage:) withObject:currentImage waitUntilDone:YES];
            self.radiationEventFound = NO;
            
            if (self.liveBlocksThisFrame > kBlocksPerEvent)
            {
                self.bigEventCount++;
                [self performSelectorOnMainThread:@selector(bigEventNoted:) withObject:currentImage waitUntilDone:NO];
            }
        }
    }
	CVPixelBufferUnlockBaseAddress(cameraFrame, 0);
    
    if (brightFound)
    {
        // perhaps a feature for the future.
        // [self performSelectorOnMainThread:@selector(saveImageToCameraRoll:) withObject:self waitUntilDone:NO];
    }
}

-(void)updateStats;
{
    NSUserDefaults* df = [NSUserDefaults standardUserDefaults];
    
    
    double score = self.biggestBlockThisFrame;
    
    if (![df objectForKey:@"last10Av"])
        [df setDouble:score forKey:@"last10Av"];
    double last10 = score*0.1 + 0.9*[df doubleForKey:@"last10Av"];
    [df setDouble:last10 forKey:@"last10Av"];
    
    if (![df objectForKey:@"last100Av"])
        [df setDouble:score forKey:@"last100Av"];
    double last100 = score*0.01 + 0.99*[df doubleForKey:@"last100Av"];
    [df setDouble:last100 forKey:@"last100Av"];
    
    if (![df objectForKey:@"last1000Av"])
        [df setDouble:score forKey:@"last1000Av"];
    double last1000 = score*0.001 + 0.999*[df doubleForKey:@"last1000Av"];
    [df setDouble:last1000 forKey:@"last1000Av"];
    
    if (score < 0.002*last1000 && last10 < 0.05*last1000)
    {
        // something is wrong. Perhaps a lot of daylight came through
        [df setDouble:score forKey:@"last10Av"];
        [df setDouble:score forKey:@"last100Av"];
        [df setDouble:score forKey:@"last1000Av"];
    }
}


-(void)addStats:(NSMutableDictionary*)outStats;
{
    NSUserDefaults* df = [NSUserDefaults standardUserDefaults];
    
    outStats[@"ray_time"] = @([self.rayTime timeIntervalSince1970]);

    outStats[@"score"] = @(self.biggestBlockThisFrame);
    outStats[@"last10Av"] = @([df doubleForKey:@"last10Av"]);
    outStats[@"last100Av"] = @([df doubleForKey:@"last100Av"]);
    outStats[@"last1000Av"] = @([df doubleForKey:@"last1000Av"]);
    
    outStats[@"blocks"] = @(self.liveBlocksThisFrame);
}

//:deviceID, :deviceBrand, :deviceSys, :app_build,
-(void)addDeviceInfo:(NSMutableDictionary*)outInfo;
{
    // These are not the best IDs as they get reset on app uninstall/reinstall.
    NSString *vendorID = [[[UIDevice currentDevice] identifierForVendor] UUIDString];
    outInfo[@"deviceID"] = vendorID;

    struct utsname systemInfo;
    uname(&systemInfo);
    NSString* deviceModel = [GLCameraViewController deviceModel];
    outInfo[@"deviceBrand"] = [NSString stringWithFormat:@"apple-%@", deviceModel];
    
    outInfo[@"deviceSys"] = [[UIDevice currentDevice] systemVersion];
    
    NSString * build = [[NSBundle mainBundle] objectForInfoDictionaryKey: (NSString *)kCFBundleVersionKey];
    outInfo[@"app_build"] = build;
}

// iPhone8,1 etc iPhone 6s is iPhone8,1 while iPhone 5 is iPhone5,1
+(NSString*)deviceModel;
{
    struct utsname systemInfo;
    uname(&systemInfo);
    NSString* deviceModel = [NSString stringWithCString:systemInfo.machine encoding:NSUTF8StringEncoding];
    return deviceModel;
}

-(void)addGeolocation:(NSMutableDictionary*)outInfo;
{
    // These are not the best IDs as they get reset on app uninstall/reinstall.
    outInfo[@"lat"] = @(self.recentLocation.coordinate.latitude);
    outInfo[@"long"] = @(self.recentLocation.coordinate.longitude);
    outInfo[@"elevation"] = @(self.recentLocation.altitude);
}

// current server we are talking to NO trailing /.
+(NSString*)serverBase;
{
    return @"http://46.101.167.242";
//        return @"http://127.0.0.1:8000";
//    return @"https://api.credo.science";
}

+(BOOL)locationServicesON;
{
    CLAuthorizationStatus status = [CLLocationManager authorizationStatus];

    if (status == kCLAuthorizationStatusAuthorizedAlways)
        return YES;

     if (status == kCLAuthorizationStatusAuthorizedWhenInUse)
        return YES;

    return NO;
}

#pragma mark API server upload
-(void)createJSONOfEvent;
{
    self.eventCount++;
    if (self.eventCount < 10) // change to like 10 on prod
        return;
    
    if (![GLCameraViewController locationServicesON])
        return;
    
    if (![[NSUserDefaults standardUserDefaults] boolForKey:@"UploadToServer"])
        return;
    
    if (self.blockImages.count > 20)
        return; // likely a bogus daylight event. Also dont want to upload actual photos...
    
    
    NSMutableArray *detectionArray = [NSMutableArray array];
    for (NSDictionary* imageDict in self.blockImages)
    {
        DetectionWrapper *detectionWrapper = [[DetectionWrapper alloc] init];
        detectionWrapper.timestamp = [self.rayTime timeIntervalSince1970] * 1000;
        detectionWrapper.latitude = self.recentLocation.coordinate.latitude;
        detectionWrapper.longitude = self.recentLocation.coordinate.longitude;
        detectionWrapper.altitude = self.recentLocation.altitude;
    //    detectionWrapper.accuracy = self.locationManager.desiredAccuracy
    //    detectionWrapper.provider = "gps"
        detectionWrapper.width = [[imageDict objectForKey:@"width"] integerValue];
        detectionWrapper.height = [[imageDict objectForKey:@"height"] integerValue];
        detectionWrapper.x = [[imageDict objectForKey:@"origin_x"] integerValue];
        detectionWrapper.y = [[imageDict objectForKey:@"origin_y"] integerValue];
    //    detectionWrapper.average =
    //    detectionWrapper.blacks =
    //    detectionWrapper.ax =
    //    detectionWrapper.ay =
    //    detectionWrapper.az =
    //    detectionWrapper.orientation =
    //    detectionWrapper.temperature =
    //    detectionWrapper.id =
    //    detectionWrapper.black_threshold =
        detectionWrapper.frame_content = imageDict[@"pngDataBase64"];
    //    detectionWrapper.max =
        [detectionArray addObject:detectionWrapper];
    }
    
    [[CredoApi shared] detection:detectionArray completion:NULL];
    
    return;
    
    // update stats
    //    [:deviceID, :deviceBrand, :deviceSys, :app_build, :ray_time, :score, :blocks, :last10Av, :last100Av, :last1000Av, :lat, :long, :elevation :images] :images is an array of [:id, :ray_id, :created_at, :updated_at, :name, :description, :origin_x, :origin_y, :width, :height, :pngDataBase64]
    NSMutableDictionary* ray = [NSMutableDictionary dictionary];
    [self addStats:ray]; // :score, :blocks, :last10Av, :last100Av, :last1000Av
    [self addDeviceInfo:ray]; //:deviceID, :deviceBrand, :deviceSys, :app_build,
    [self addGeolocation:ray]; // : lat, :long, :elevation
    
    ray[@"images"] = self.blockImages;
    
    // Now upload this to the server.
    // The plan in prod is to write the Json to a file, and have something watch the folder and upload at will.
    // I'm starting with direct upload...
    
    NSString* urlString = [NSString stringWithFormat:@"%@/api/v2/detection", [GLCameraViewController serverBase]];
    [self placePostRequestWithURL:urlString
                         withData:ray
                      withHandler:^(NSURLResponse *response, NSData *rawData, NSError *error) {
                          NSString *string = [[NSString alloc] initWithData:rawData
                                                                   encoding:NSUTF8StringEncoding];
                          
                          NSHTTPURLResponse* httpResponse = (NSHTTPURLResponse*)response;
                          NSInteger code = [httpResponse statusCode];
                          NSLog(@"%ld", (long)code);
                          
                          if (!(code >= 200 && code < 300)) {
                              NSLog(@"ERROR (%ld): %@", (long)code, string);
                              //[calledBy performSelector:failureCallback withObject:string];
                          } else {
                              NSLog(@"OK");
                              
                              NSDictionary *result = [NSDictionary dictionaryWithObjectsAndKeys:
                                                      string, @"id",
                                                      nil];
                              //[calledBy performSelector:successCallback withObject:result];
                          }
                      }];

    
    //
    // Get data, then send into dispatch_async....
    //API
    // Need[:deviceID, :deviceBrand, :deviceSys, :app_build, :ray_time, :score, :blocks, :last10Av, :last100Av, :last1000Av, :lat, :long, :elevation]
    // Actually don't need geohash - calcualte on server,
    // DON'T send first 10
    // Remember averages in UserDefaults (except last 10 average which needs to be live)
    // Use rolling averages
    
    // image array - turn to PNG, base64.
    
    // Create the JSON if we have 10 events, then call the API, which will try and POST the events it can find in a thread.
}

#pragma mark still camera shots:
-(void)takeAPhoto;
{
    if (![self.stillCamera isRunning])
        return;
    
    [self.stillCamera captureStillCMSampleBuffer: ^(CMSampleBufferRef sampleBuffer, NSError *error)
    {
        // retain the CMSampleBufferRef
        if (sampleBuffer)
        {
            CFRetain(sampleBuffer);
            
            CVImageBufferRef theImageBuffer = NULL;
            if (sampleBuffer != NULL)
            {
                theImageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
            }

            // this seems to get called on the main thread. Apple promises 'anythread'
            // put it in the background.
            dispatch_async(dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                [self processNewCameraFrame:theImageBuffer];
                CFRelease(sampleBuffer);
                [self performSelectorOnMainThread:@selector(takeAPhoto) withObject:nil waitUntilDone:YES];
            });
        }
    }];
}

#pragma mark - Application Life Cycle

- (void)applicationWillResignActive:(NSNotification *)notification
{
    if ([self isViewLoaded]) {
        if (self.useVideoFrames)
        {
            [self.videoCamera stopSession];
        }
        else
        {
            [self.stillCamera stopRunning];
        }
    }
}

- (void)applicationDidBecomeActive:(NSNotification *)notification
{
    if ([self isViewLoaded]) {
        self.sessionFrameCount = 0;
        if (self.useVideoFrames)
        {
            [self.videoCamera startSession];
        }
        else
        {
            [self.stillCamera startRunning];
            [self takeAPhoto];
        }
    }
}

- (void)applicationWillTerminate:(NSNotification *)notification
{
    if ([self isViewLoaded] && self.view.window) {
        [self.videoCamera stopSession];
        self.videoCamera.delegate = nil;
        self.videoCamera = nil;
        
        [self.stillCamera stopRunning];
    }
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Release any cached data, images, etc. that aren't in use.
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
}

- (void)viewDidUnload
{
	[super viewDidUnload];
}


#pragma mark updateUI

-(void)timerCall:(NSTimer*)timer;
{
    [self updateUI];
}

-(void)bigEventNoted:(UIImage*)image;
{
    //NSLog(@"big event %d blocks", (int) self.liveBlocksThisFrame);
    // max 10 per running of the app...
    //if (self.bigEventCount < 10)
    //    [self saveImageToCameraRoll:self];
}

-(void)sizeAndRotateImageView;
{
//    const double heightAtTop = 80.0;
//    CGRect swipeViewFrame = self.view.bounds;
//    swipeViewFrame.size.height -= heightAtTop;
//    swipeViewFrame.origin.y = heightAtTop;
//
//    self.swipeView.frame = swipeViewFrame;
}

-(void)addBorderToImageView:(UIImageView*)imageView;
{
    const CGFloat kBorderWidth = 3.0;
    const CGFloat kCornerRadius = 1.0;
    CALayer *borderLayer = [CALayer layer];
    CGRect borderFrame = CGRectMake(-kBorderWidth, -kBorderWidth, (imageView.frame.size.width + 2*kBorderWidth), (imageView.frame.size.height + 2*kBorderWidth));
    [borderLayer setBackgroundColor:[[UIColor clearColor] CGColor]];
    [borderLayer setFrame:borderFrame];
    [borderLayer setCornerRadius:kCornerRadius];
    [borderLayer setBorderWidth:kBorderWidth];
    [borderLayer setBorderColor:[[UIColor whiteColor] CGColor]];
    [imageView.layer addSublayer:borderLayer];
}

const double kFrameIntervalMemory = 0.15;
-(void)adjustThreshold;
{
    double seconds = fabs([self.lastImageDate timeIntervalSinceNow]);
    self.averageSecondsBetweenImages = kFrameIntervalMemory*seconds + (1.0 - kFrameIntervalMemory)*self.averageSecondsBetweenImages;
    self.lastImageDate = [NSDate date];
    
    if (self.averageSecondsBetweenImages/kDesiredFrameIntervalSeconds > 1.3)
    {
        // too slow, lower the threshold.
        self.thresholdFactor -= 0.04;
    }
    if (self.averageSecondsBetweenImages/kDesiredFrameIntervalSeconds > 2.3)
    {
        // too slow, lower the threshold.
        self.thresholdFactor -= 0.2;
    }
    
    if (self.averageSecondsBetweenImages/kDesiredFrameIntervalSeconds < 0.7)
    {
        // too fast, raise the threshold.
        self.thresholdFactor += 0.04;
    }
    if (self.averageSecondsBetweenImages/kDesiredFrameIntervalSeconds < 0.1)
    {
        // too fast, raise the threshold.
        self.thresholdFactor += 0.2;
    }
}

-(void)trimFoundEventsTo:(int)maxNum;
{
    // keep the maxNumBright ones
    NSArray* topOnes = [self.foundEvents sortedArrayUsingSelector:@selector(scoreCompare:)];
    if (topOnes.count > maxNum)
        topOnes = [topOnes subarrayWithRange:NSMakeRange(0, maxNum)];
    
    NSMutableArray* newArray = [[NSMutableArray alloc] init];
    for (RadiationEvent* event in self.foundEvents)
    {
        if ([topOnes containsObject:event])
            [newArray addObject:event];
    
        if (newArray.count >= maxNum)
            break;
    }
    
    [self.foundEvents setArray:newArray];
}

-(void)updateImage:(UIImage*)image;
{
    self.latestImage = image;
    
    [self adjustThreshold];
    
    
    UIImageView* imageView = [[UIImageView alloc] initWithImage:image];
    imageView.contentMode = UIViewContentModeScaleAspectFit;
    imageView.layer.borderWidth = 3.0;
    [imageView.layer setBorderColor:[[UIColor whiteColor] CGColor]];
    CGRect bounds = imageView.bounds;
    
    // make 180 wide
    double factor = 180/bounds.size.width;
    bounds.size.width *= factor;
    bounds.size.height *= factor;
    imageView.bounds = bounds;
    // [self addBorderToImageView:imageView];
    // imageView.contentScaleFactor = 6.0;
    
    [[imageView layer] setMagnificationFilter:kCAFilterNearest];
    
    RadiationEvent* event = [[RadiationEvent alloc] init];
    event.imageView = imageView;
    event.score = self.biggestBlockThisFrame;
    event.blocks = self.liveBlocksThisFrame;
    event.dateTime = [NSDate date];
    
    // if too many events, drop a bunch
    if (self.foundEvents.count > kNumToShowInTop*1.25)
        [self trimFoundEventsTo:kNumToShowInTop];
    
    [self.foundEvents addObject:event];
    
    
    
    [self.swipeView reloadData];
    
    [self sizeAndRotateImageView];
    
    [self updateUI];
    
    if (!self.showingTop)
        [self.swipeView scrollToItemAtIndex:self.foundEvents.count - 1 duration:4.0];
#if PLAY_SOUNDS
    [self.player play];
#endif
}

- (void)updateUI;
{
    long framesToShow = (long) self.totalFramesAnalyzed;
    if (framesToShow == 0)
        framesToShow = self.sessionFrameCount; // we are warming up...
    
    self.eventsCount.title = [NSString stringWithFormat:@"%d Events", (int)self.foundEvents.count];
    
    self.totalFramesAnalyzedLabel.text = [NSString stringWithFormat:@"%d", (int) framesToShow];
    self.totalLiveBlocksLabel.text = [NSString stringWithFormat:@"%d", (int)self.totalLiveBlocks/kBlocksPerEvent];
    self.liveBlocksThisFrameLabel.text = [NSString stringWithFormat:@"%d,%d", (int) self.maxLiveBlocksOneFrame/kBlocksPerEvent, (int)self.bigEventCount];
    
    static double hotPixelAverage = 0;
    if (hotPixelAverage == 0)
        hotPixelAverage = self.hotPixelCount;
    hotPixelAverage = 0.95*hotPixelAverage + 0.05*self.hotPixelCount;
    self.hotPixelCountLabel.text = [NSString stringWithFormat:@"%d", (int) hotPixelAverage];
    
    // perhaps on rotation only [self sizeAndRotateImageView];
}

-(void)orientationChangedAWhileBack;
{
    //do stuff
    [self sizeAndRotateImageView];
    [self updateUI];
}

#pragma mark
- (void)orientationChanged:(NSNotification *)notification{
    //UIDeviceOrientation orientation = [[UIDevice currentDevice] orientation];
    [self performSelector:@selector(orientationChangedAWhileBack) withObject:nil afterDelay:0.4];
#if DEBUG
    NSLog(@"Orientation changed");
#endif
}

#pragma mark scroller callback
//UIScrollViewDelegate
//-(UIView *)viewForZoomingInScrollView:(UIScrollView *)scrollView;
//{
//    return self.imageView;
//}

#pragma mark image

-(void)exchangeRedAndBlue;
{
    const long bufHeight = self.bufferHeight;
    const long bufWidth = self.bufferWidth;
    const long bytesPerRow = self.bytesPerRow;
    uint8_t* pixels = self.buffer;
    
    for (long countH = 0; countH < bufHeight; countH++)
    {
        uint8_t* row = pixels + (countH * bytesPerRow);
        for (long countW = 0; countW < bufWidth; countW++)
        {
            unsigned char *pixel = row + (countW*4);
            uint8_t temp = pixel[0];
            pixel[0] = pixel[2];
            pixel[2] = temp;
        }
    }
}

-(minMaxRect)findImageBounds;
{
    minMaxRect outRect;
    outRect.minCol = 1000000;
    outRect.maxCol = 0;
    outRect.minRow = 100000;
    outRect.maxRow = 0;

    const long bufHeight = self.bufferHeight;
    const long bufWidth = self.bufferWidth;
    const long bytesPerRow = self.bytesPerRow;
    uint8_t* pixels = self.buffer;
    
    for (int countH = 0; countH < bufHeight; countH++)
    {
        uint8_t* row = pixels + (countH * bytesPerRow);
        for (int countW = 0; countW < bufWidth; countW++)
        {
            unsigned char *pixel = row + (countW*4);
            long total = (long) pixel[0] + (long) pixel[1] + (long) pixel[2] + (long) pixel[3];// actually just checking for a set alpha would be all we need.
            if (total > 0)
            {
                if (countH > outRect.maxRow)
                    outRect.maxRow = countH;
                if (countH < outRect.minRow)
                    outRect.minRow = countH;
                
                if (countW > outRect.maxCol)
                    outRect.maxCol = countW;
                if (countW < outRect.minCol)
                    outRect.minCol = countW;
            }
        }
    }
    
    //NSLog(@"found newImage left %d, right %d, top %d bottom %d", out.minCol, out.maxCol, out.minRow, out.maxRow);
#if DEBUG
    NSLog(@"newImage width %d, height %d", (int) (outRect.maxCol - outRect.minCol), (int) (outRect.maxRow - outRect.minRow));
#endif
    
    return outRect;
}

-(uint8_t*)mallocImageBuffer:(long*)outWidth height:(long*)outHeight;
{
    minMaxRect rect = [self findImageBounds];
    
    long netWidth = rect.maxCol - rect.minCol + 1;
    if (netWidth < 0)
        return nil;
    long netHeight = rect.maxRow - rect.minRow + 1;
    
    long bytesPerOutRow = netWidth*4;
    uint8_t* outPixels = calloc(netHeight, bytesPerOutRow);
    
    const long bytesPerRow = self.bytesPerRow;
    uint8_t* sourcePixels = self.buffer;
    //int countPixels = 0;
    for (long countH = 0; countH < netHeight; countH++)
    {
        uint8_t* sourceRow = sourcePixels + ((countH + rect.minRow)* bytesPerRow);
        uint8_t* destRow = outPixels + (countH * bytesPerOutRow);
        for (long countW = 0; countW < netWidth; countW++)
        {
            unsigned char *sourcePixel = sourceRow + ((countW + rect.minCol)*4);
            unsigned char *outPixel = destRow + (countW*4);
            //long total = sourcePixel[0] + sourcePixel[1] + sourcePixel[2];
//            if (netWidth == 20 && total == 0 && countPixels++ > 100) // width of 20 is for the usual one square problem
//                NSLog(@"likley missed ??");
            outPixel[0] = sourcePixel[0];
            outPixel[1] = sourcePixel[1];
            outPixel[2] = sourcePixel[2];
            outPixel[3] = 255;
        }
    }
    
    *outWidth = netWidth;
    *outHeight = netHeight;
    
    return outPixels;
}

-(void)clearBuffer;
{
    bzero(self.buffer, self.bufferWidth*self.bufferHeight*4);
}


+(UIImage*)makeImage:(uint8_t*)pixels width:(long)width height:(long)height;
{
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    
    size_t numberOfComponents = CGColorSpaceGetNumberOfComponents(colorSpace) + 1; // Add 1 for the alpha channel
    size_t bitsPerComponent = 8;
    size_t bytesPerPixel = (bitsPerComponent * numberOfComponents) / 8;
    size_t bytesPerRow = bytesPerPixel * width;
    
    
    CGContextRef imageContext = CGBitmapContextCreate(pixels,
                                                      width,
                                                      height,
                                                      bitsPerComponent,
                                                      bytesPerRow,
                                                      CGColorSpaceCreateWithName( kCGColorSpaceGenericRGB),
                                                      kCGImageAlphaNoneSkipLast);//
    //kCGImageAlphaLast is not supported
    
    CGColorSpaceRelease(colorSpace);
    
    CGImageRef toCGImage = CGBitmapContextCreateImage(imageContext);
    UIImage * uiimage = [[UIImage alloc] initWithCGImage:toCGImage];
    
    CGContextRelease(imageContext);
    CGImageRelease(toCGImage);
    
    return uiimage;
}

// clears the buffer for a new image.
-(UIImage*)makeNewImage;
{
    long width = 0;
    long height = 0;
    uint8_t* pixels = [self mallocImageBuffer:&width height:&height];
    if (!pixels)
        return nil;
    
    UIImage* outImage = [[self class] makeImage:pixels width:width height:height];
    
    // add text on it for info..
    double last100Av = [[NSUserDefaults standardUserDefaults] doubleForKey:@"last100Av"];

    double score = 100*self.biggestBlockThisFrame/last100Av;
    
    NSString* description = [NSString stringWithFormat:@"s:%d", (int)(score)];
    if (self.liveBlocksThisFrame > kBlocksPerEvent)
        description = [NSString stringWithFormat:@"s:%d b:%d", (int)(score), (int) self.liveBlocksThisFrame/kBlocksPerEvent];

    outImage = [self drawTextHeader:outImage text:description];
    
    free(pixels);
    [self clearBuffer];
    return outImage;
}

-(UIImage*)drawTextHeader:(UIImage*)image text:(NSString*)text;
{
    CGSize fullSize = image.size;
    // determine extra.
    long fontSize = 14;
    double theSize = sqrt(fullSize.width*fullSize.height);
    if (theSize > 100)
        fontSize = fontSize + theSize/30;
    
    
    UIFont *font = [UIFont fontWithName:@"Arial" size:fontSize];
    
    long extraHeight = fontSize*1.2;
    fullSize.width += 0;
    fullSize.height += extraHeight;
    
    UIGraphicsBeginImageContext(fullSize);
    CGContextSetShouldAntialias(UIGraphicsGetCurrentContext(), NO);
    [image drawInRect:CGRectMake(0,extraHeight,image.size.width,image.size.height)];
    CGRect textRect = CGRectMake(0, 0, image.size.width, extraHeight);
    [[UIColor blackColor] set];
    UIRectFill(textRect);
    
    NSMutableAttributedString* attString = [[NSMutableAttributedString alloc] initWithString:text];
    NSRange range = NSMakeRange(0, [attString length]);
    
    [attString addAttribute:NSFontAttributeName value:font range:range];
    [attString addAttribute:NSForegroundColorAttributeName value:[UIColor whiteColor] range:range];
    [attString drawInRect:CGRectIntegral(textRect)];
    UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return newImage;
}

// CALL ONLY ON Aquisiton THREAD. Latest image is on main thread at self.latestImage;
-(UIImage*)makeBufferImage;
{
    return [[self class] makeImage:self.buffer width:self.bufferWidth height:self.bufferHeight];
}


// Call from main thread
-(void)imageToCameraRoll:(UIImage*)image;
{
    //ALAssetsLibrary *library = [[ALAssetsLibrary alloc] init];
    //[library writeImageDataToSavedPhotosAlbum: UIImagePNGRepresentation(image) metadata:nil completionBlock:nil];
    //UIImageWriteToSavedPhotosAlbum(uiimage, nil, nil, nil);
}

-(void)saveImageToCameraRoll:(id)sender;
{
    [self imageToCameraRoll:self.latestImage];
}

- (IBAction)toggleTop10:(id)sender {
    self.showingTop = !self.showingTop;
    if (self.showingTop)
    {
        [self.topTenButton setTitle:@"Show All" forState:UIControlStateNormal];
        self.showTopButton.title = @"Show All";
    }
    else
    {
        [self.topTenButton setTitle:@"Show Top" forState:UIControlStateNormal];
        self.showTopButton.title = @"Show Top";
    }
    [self.swipeView reloadData];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSInteger scrollTo = 0;
        if (!self.showingTop)
            scrollTo = [self itemsForSwipeView].count;
        
        [self.swipeView scrollToItemAtIndex:scrollTo duration:2.0];
    });
}

// How to do PNG with this PHPhotoLibrary piece of crap?
//-(void)addNewAssetWithImage:(UIImage *)image toAlbum:(PHAssetCollection *)album
//{
//    [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
//        // Request creating an asset from the image.
//        PHAssetChangeRequest *createAssetRequest = [PHAssetChangeRequest creationRequestForAssetFromImage:image];
//        
//        // Request editing the album.
//        PHAssetCollectionChangeRequest *albumChangeRequest = [PHAssetCollectionChangeRequest changeRequestForAssetCollection:album];
//        
//        // Get a placeholder for the new asset and add it to the album editing request.
//        PHObjectPlaceholder *assetPlaceholder = [createAssetRequest placeholderForCreatedAsset];
//        [albumChangeRequest addAssets:@[ assetPlaceholder ]];
//        
//    } completionHandler:^(BOOL success, NSError *error) {
//        NSLog(@"Finished adding asset. %@", (success ? @"Success" : error));
//    }];
//}

#pragma mark SwipeViewDataSource

-(NSArray*)itemsForSwipeView;
{
    //show top 10 live sort...
    if (!self.showingTop)
        return self.foundEvents;
    
    NSArray* topOnes = [self.foundEvents sortedArrayUsingSelector:@selector(scoreCompare:)];
    if (topOnes.count > kNumToShowInTop)
        topOnes = [topOnes subarrayWithRange:NSMakeRange(0, kNumToShowInTop)];
    return topOnes;
}

- (NSInteger)numberOfItemsInSwipeView:(SwipeView *)swipeView;
{
    return [self itemsForSwipeView].count;
}

- (UIView *)swipeView:(SwipeView *)swipeView viewForItemAtIndex:(NSInteger)index reusingView:(UIView *)view;
{
    RadiationEvent* theEvent = [self itemsForSwipeView][index];
    UIImageView* imageView = theEvent.imageView;
    
    CGRect newFrame = imageView.bounds;
    newFrame.size.height += 20;
    UIView* entireView = [[UIView alloc] initWithFrame:newFrame];
    [entireView addSubview:imageView];
    imageView.frame = CGRectMake(20, 0, imageView.bounds.size.width, imageView.bounds.size.height);
    newFrame.size.height = 20;
    newFrame.origin.y = imageView.frame.origin.y + imageView.frame.size.height;
    newFrame.origin.x = 15;
    UITextView* textView = [[UITextView alloc]  initWithFrame:newFrame];
    
    
    static NSDateFormatter *dateFormatter = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        dateFormatter = [[NSDateFormatter alloc] init];
        dateFormatter.dateStyle = NSDateFormatterMediumStyle;
        dateFormatter.timeStyle = NSDateFormatterMediumStyle;
    });
    
    textView.text = [dateFormatter stringFromDate:theEvent.dateTime];
    [entireView addSubview:textView];
    
    return entireView;
}

- (void)swipeView:(SwipeView *)swipeView didSelectItemAtIndex:(NSInteger)index;
{
    RadiationEvent* theEvent = [self itemsForSwipeView][index];
    UIImageView* theView = theEvent.imageView;
    UIImage* image = theView.image;
    
    UIView* itemView = [swipeView itemViewAtIndex:index];
    
    // Create image info
    JTSImageInfo *imageInfo = [[JTSImageInfo alloc] init];
    imageInfo.image = image;
    imageInfo.referenceRect = itemView.frame;
    imageInfo.referenceView = swipeView;
    imageInfo.title = @"Share/Save";
    
    // Setup view controller
    JTSImageViewController *imageViewer = [[JTSImageViewController alloc]
                                           initWithImageInfo:imageInfo
                                           mode:JTSImageViewControllerMode_Image
                                           backgroundStyle:JTSImageViewControllerBackgroundOption_Scaled];
    
    // Present the view controller.
    [imageViewer showFromViewController:self transition:JTSImageViewControllerTransition_FromOriginalPosition];
}

#pragma mark SwipeViewDelegate

- (CGSize)swipeViewItemSize:(SwipeView *)swipeView;
{
    return CGSizeMake(206, 206 + 14);
//    
//    
//    if (self.imageViews.count == 0)
//        return CGSizeZero;
//    
//    UIImageView* imageView = self.imageViews[0];
//    CGSize size = imageView.frame.size;
//    
//    size.width *= 1.1;
//    size.height *= 1.1;
//    return size;
}



#pragma mark updateWarmupProgress

-(void)updateWarmupProgress:(NSNumber*)number;
{
    double progress = [number doubleValue];
    
    if (progress > 1.0)
    {
        [gAppD hideWarmup];
        return;
    }
    
    [gAppD showWarmup:progress];
}

- (IBAction)helpButtonPressed:(id)sender {
    HelpViewController* vc = [[HelpViewController alloc] initWithNibName:@"HelpViewController" bundle:nil];
    [self presentViewController:vc animated:YES completion:nil];
}

-(void)geoLocation
{
    self.geoCoder = [[CLGeocoder alloc] init];
    if (self.locationManager == nil)
    {
        self.locationManager = [[CLLocationManager alloc] init];
        self.locationManager.desiredAccuracy = kCLLocationAccuracyBest;
        self.locationManager.delegate = self;
        [self.locationManager requestWhenInUseAuthorization];
    }
    [self.locationManager startUpdatingLocation];
}
- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error
{
    NSLog(@"didFailWithError: %@", error);
//    UIAlertView *errorAlert = [[UIAlertView alloc]
//                               initWithTitle:@"Error" message:@"Failed to Get Your Location" delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
//    [errorAlert show];
}
-(void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations {
    self.recentLocation = [locations lastObject];
}

-(void)placePostRequestWithURL:(NSString *)action withData:(NSDictionary *)dataToSend withHandler:(void (^)(NSURLResponse *response, NSData *data, NSError *error))ourBlock {
    NSString *urlString = [NSString stringWithFormat:@"%@", action];
    NSLog(@"%@", urlString);
    
    NSURL *url = [NSURL URLWithString:urlString];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    
    NSError *error;
    
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:dataToSend options:0 error:&error];
    
    NSString *jsonString;
    if (! jsonData) {
        NSLog(@"Got an error: %@", error);
    } else {
        jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
        
        NSData *requestData = [NSData dataWithBytes:[jsonString UTF8String] length:[jsonString lengthOfBytesUsingEncoding:NSUTF8StringEncoding]];
        
        [request setHTTPMethod:@"POST"];
        [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
        [request setValue:@"application/json; charset=UTF-8" forHTTPHeaderField:@"Content-Type"];
        [request setValue:[NSString stringWithFormat:@"%lu", (unsigned long)[requestData length]] forHTTPHeaderField:@"Content-Length"];
        [request setHTTPBody: requestData];
        
        [NSURLConnection sendAsynchronousRequest:request queue:[NSOperationQueue mainQueue] completionHandler:ourBlock];
    }
}

@end
