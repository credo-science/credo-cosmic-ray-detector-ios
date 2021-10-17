//
//  MetalPixelProcessor.h
//  NaturalActivity
//
//  Created by Evan Andersen on 2018-03-23.
//

#ifndef MetalPixelProcessor_h
#define MetalPixelProcessor_h

#import <MetalKit/MetalKit.h>

@interface MetalPixelProcessor : NSObject
// The device (aka GPU) we're using to render
@property id<MTLDevice> device;

- (id)initWithWidth:(size_t)width height:(size_t)height blockSize:(size_t)blockSize initialHeat:(float*)initialHeat;
- (size_t)calculateTriggerBlocks:(uint8_t*)pixels blocks:(float**)blocks;

@end


#endif /* MetalPixelProcessor_h */
