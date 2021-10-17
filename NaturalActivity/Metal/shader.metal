//
//  shader.metal
//  Cosmic Ray
//
//  Created by Tom Andersen on 2018-03-31.
//

#include <metal_stdlib>
#include <simd/simd.h>
#include <metal_compute>
#include "../pixelMathImplementation.c"

using namespace metal;


kernel void sum_pixels(
    //arguments passed explicity
    device const uchar* pixels,
    device float* heatmap,
    device float *blockScores,
    threadgroup float *scores,
                       
    //computed arguments by GPU
    uint2 gs [[threads_per_grid]],
    uint2 gid [[thread_position_in_grid]],
    uint2 bs [[threadgroups_per_grid]],
    uint2 bid [[threadgroup_position_in_grid]],
    uint2 ls [[threads_per_threadgroup]],
    uint2 lid [[thread_position_in_threadgroup]]
) {
    int index = (gid.y*gs.x + gid.x);
    
    //load the 3 bytes pixel into a vector
    uchar3 pixel;
    pixel.r = pixels[index*4 + 0];
    pixel.g = pixels[index*4 + 1];
    pixel.b = pixels[index*4 + 2];

    //total heat for this pixel
    int total = pixel.r + pixel.g + pixel.b;
    
    //historic heat of this pixel
    float heat = heatmap[index];
    
    //abnormality
    //float diff = total - heat;
    
    //calculate scores for each pixel
    
    scores[lid.y*ls.x + lid.x] = pixelScore(total, heat);
    //scores[lid.y*ls.x + lid.x] = (total > 4 && diff > 4*heat) ? diff*diff : 0;

    //update heat map
    heatmap[index] = heatMapUpdate(total, heat);
    
    //wait for all threads to write scores
    threadgroup_barrier(mem_flags::mem_threadgroup);
    
    //sum columns (summing by column because GPUs process rows at a time)
    // so by summing columns, the rows run in parallel
    if(lid.y == 0) {
        float sum = 0.0;
        for(uint i = 0; i < ls.x; i++) {
            sum += scores[i*ls.x + lid.x];
        }
        scores[lid.x] = sum;
    }
    //wait for all threads to write column sums
    threadgroup_barrier(mem_flags::mem_threadgroup);

    //sum the sums and write final answer back to global memory
    if(lid.y == 0 && lid.x == 0) {
        float sum = 0.0;
        for(uint i = 0; i < ls.x; i++) {
            sum += scores[i];
        }
        //figure out what block we are in
        blockScores[bid.y*bs.x + bid.x] = sum;
    }
}



