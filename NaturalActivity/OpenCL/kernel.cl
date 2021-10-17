
__kernel void sum_pixels(__global const uchar* pixels, __global float* heatmap, __global float *blockScores, __local float *scores) {
    int global_x = get_global_id(0);
    int global_y = get_global_id(1);
    int stride = get_global_size(0);
    
    int index = global_y*stride + global_x;

    //load a 4 byte pixel into a vector
    uchar4 pixel = vload4(index, pixels);
    
    //total heat for this pixel
    int total = pixel.x + pixel.y + pixel.z;
    
    //historic heat of this pixel
    float heat = heatmap[index];
    
    //abnormality
    float diff = total - heat;   
    
    //calculate scores for each pixel
    int x = get_local_id(0);
    int y = get_local_id(1);
    int lstride = get_local_size(0);
    scores[y*lstride + x] = (diff > 4*heat) ? diff*diff : 0; 
    
    //update heat map
    heatmap[index] = heat*0.97 + total*0.03;
    
    //wait for all threads to write scores
    barrier(CLK_LOCAL_MEM_FENCE);

    //sum columns (summing by column because GPUs process rows at a time)
    // so by summing columns, the rows run in parallel 
    if(y == 0) {
        float sum = 0.0;
        for(int i = 0; i < lstride; i++) {
            sum += scores[i*lstride + x];
        }
        scores[x] = sum;
    }
    //wait for all threads to write column sums
    barrier(CLK_LOCAL_MEM_FENCE);
    
    //sum the sums and write final answer back to global memory
    if(y == 0 && x == 0) {
        float sum = 0.0;
        for(int i = 0; i < lstride; i++) {
            sum += scores[i];
        }
        //figure out what block we are in
        int group_x = get_group_id(0);
        int group_y = get_group_id(1);
        int group_stride = get_num_groups(0);
        int group_index = group_y*group_stride + group_x;
        blockScores[group_index] = sum;
    }
}

