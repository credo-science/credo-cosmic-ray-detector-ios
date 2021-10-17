//
//  MetalPixelProcessor.m
//  Cosmic Ray
//
//  Created by Evan Andersen on 2018-03-23.
//

#import <Foundation/Foundation.h>

#import "MetalPixelProcessor.h"


// Main class performing the rendering
@interface MetalPixelProcessor ()

    
    // Our render pipeline composed of our vertex and fragment shaders in the .metal shader file
    @property id<MTLComputePipelineState> pipeline;
    
    // The command Queue from which we'll obtain command buffers
    @property id<MTLCommandQueue> commandQueue;

    @property id<MTLBuffer>pixelBuf;
    @property id<MTLBuffer>heatBuf;
    @property id<MTLBuffer>blockBuf;

    @property size_t width;
    @property size_t height;

    @property MTLSize threadGroupSize;
    @property MTLSize threadGroupCount;
@end

@implementation MetalPixelProcessor
//{
//    // The device (aka GPU) we're using to render
//    id<MTLDevice> _device;
//
//    // Our render pipeline composed of our vertex and fragment shaders in the .metal shader file
//    id<MTLComputePipelineState> _pipeline;
//
//    // The command Queue from which we'll obtain command buffers
//    id<MTLCommandQueue> _commandQueue;
//
//    id<MTLFunction> _function;
//
//    size_t _width;
//    size_t _height;
//}

- (id)initWithWidth:(size_t)width height:(size_t)height blockSize:(size_t)blockSize initialHeat:(float*)initialHeat;
{
    if ((self = [super init]) != NULL)
    {
        _width = width;
        _height = height;
        _threadGroupSize = MTLSizeMake(blockSize, blockSize, 1);
        
        //round up dimensions so that we cover all pixels
        //  + _threadGroupSize.width -  1
        _threadGroupCount.width  = (_width  ) / _threadGroupSize.width;
        _threadGroupCount.height = (_height ) / _threadGroupSize.height;
        _threadGroupCount.depth = 1;
        
        _device = MTLCreateSystemDefaultDevice();
        NSLog(@"device = %p", _device);
        _commandQueue = _device.newCommandQueue;
        id <MTLLibrary> library = _device.newDefaultLibrary;
        NSLog(@"library  = %p", library);
        id<MTLFunction> function = [library newFunctionWithName:@"sum_pixels"];
        NSLog(@"function = %p", function);
        NSError *err = nil;
        _pipeline =  [_device newComputePipelineStateWithFunction:function error:&err];
        if(err) {
            NSLog(@"The error was %@", [err description]);
        }
        
        //create the GPU buffers at init, contents can be updated later
        _pixelBuf = [_device newBufferWithLength:_width*_height*4 options:MTLResourceStorageModeShared];
        _heatBuf = [_device newBufferWithBytes:initialHeat length:_width*_height*sizeof(float) options:MTLResourceStorageModeShared];
        //_heatBuf = [_device newBufferWithLength:_width*_height*sizeof(float) options:MTLResourceStorageModePrivate];

        //total number of blocks
        size_t totalBlocks = _threadGroupCount.width * _threadGroupCount.height;
        _blockBuf = [_device newBufferWithLength:totalBlocks*sizeof(float) options:MTLResourceStorageModeShared];
    }
    return(self);
}


- (size_t)calculateTriggerBlocks:(uint8_t*)pixels blocks:(float**)blocks
{
    //buffer pixel data to GPU
    //TODO: replace this with no-copy code
    // something like CVMetalTextureCacheCreateTextureFromImage(nil, ??
    memcpy([_pixelBuf contents], pixels, _width*_height*4);

    //don't include the unnessecary copy 
#if DEBUG_COMPARE_METAL
    double start = [NSDate timeIntervalSinceReferenceDate];
#endif
    
    id<MTLCommandBuffer> commandBuffer = [_commandQueue commandBuffer];
    id<MTLComputeCommandEncoder> commandEncoder = [commandBuffer computeCommandEncoder];
    [commandEncoder setComputePipelineState:_pipeline];
    
    
    [commandEncoder setBuffer:_pixelBuf offset:0 atIndex:0];
    [commandEncoder setBuffer:_heatBuf offset:0 atIndex:1];
    [commandEncoder setBuffer:_blockBuf offset:0 atIndex:2];
    
    //
    size_t scoreBufSize = _threadGroupSize.width * _threadGroupSize.height * sizeof(float);
    [commandEncoder setThreadgroupMemoryLength:scoreBufSize atIndex:0];
    
    [commandEncoder dispatchThreadgroups:_threadGroupCount
                   threadsPerThreadgroup:_threadGroupSize];

    [commandEncoder endEncoding];
    [commandBuffer commit];
    
    //serialized for now!
    [commandBuffer waitUntilCompleted];
    
    *blocks = [_blockBuf contents];
    
#if DEBUG_COMPARE_METAL
    double end = [NSDate timeIntervalSinceReferenceDate];
   NSLog(@"GPU trigger calculate time %f", end - start);
#endif
    return _threadGroupCount.width * _threadGroupCount.height;
}

@end

