#include <stdlib.h>
#include <stdio.h>
#include <time.h>
#include <errno.h>
#include <string.h>
#include <stdint.h>

#include <CL/cl.h>

const char *getErrorString(cl_int error) {
    switch(error) {
        // run-time and JIT compiler errors
        case 0: return "CL_SUCCESS";
        case -1: return "CL_DEVICE_NOT_FOUND";
        case -2: return "CL_DEVICE_NOT_AVAILABLE";
        case -3: return "CL_COMPILER_NOT_AVAILABLE";
        case -4: return "CL_MEM_OBJECT_ALLOCATION_FAILURE";
        case -5: return "CL_OUT_OF_RESOURCES";
        case -6: return "CL_OUT_OF_HOST_MEMORY";
        case -7: return "CL_PROFILING_INFO_NOT_AVAILABLE";
        case -8: return "CL_MEM_COPY_OVERLAP";
        case -9: return "CL_IMAGE_FORMAT_MISMATCH";
        case -10: return "CL_IMAGE_FORMAT_NOT_SUPPORTED";
        case -11: return "CL_BUILD_PROGRAM_FAILURE";
        case -12: return "CL_MAP_FAILURE";
        case -13: return "CL_MISALIGNED_SUB_BUFFER_OFFSET";
        case -14: return "CL_EXEC_STATUS_ERROR_FOR_EVENTS_IN_WAIT_LIST";
        case -15: return "CL_COMPILE_PROGRAM_FAILURE";
        case -16: return "CL_LINKER_NOT_AVAILABLE";
        case -17: return "CL_LINK_PROGRAM_FAILURE";
        case -18: return "CL_DEVICE_PARTITION_FAILED";
        case -19: return "CL_KERNEL_ARG_INFO_NOT_AVAILABLE";

        // compile-time errors
        case -30: return "CL_INVALID_VALUE";
        case -31: return "CL_INVALID_DEVICE_TYPE";
        case -32: return "CL_INVALID_PLATFORM";
        case -33: return "CL_INVALID_DEVICE";
        case -34: return "CL_INVALID_CONTEXT";
        case -35: return "CL_INVALID_QUEUE_PROPERTIES";
        case -36: return "CL_INVALID_COMMAND_QUEUE";
        case -37: return "CL_INVALID_HOST_PTR";
        case -38: return "CL_INVALID_MEM_OBJECT";
        case -39: return "CL_INVALID_IMAGE_FORMAT_DESCRIPTOR";
        case -40: return "CL_INVALID_IMAGE_SIZE";
        case -41: return "CL_INVALID_SAMPLER";
        case -42: return "CL_INVALID_BINARY";
        case -43: return "CL_INVALID_BUILD_OPTIONS";
        case -44: return "CL_INVALID_PROGRAM";
        case -45: return "CL_INVALID_PROGRAM_EXECUTABLE";
        case -46: return "CL_INVALID_KERNEL_NAME";
        case -47: return "CL_INVALID_KERNEL_DEFINITION";
        case -48: return "CL_INVALID_KERNEL";
        case -49: return "CL_INVALID_ARG_INDEX";
        case -50: return "CL_INVALID_ARG_VALUE";
        case -51: return "CL_INVALID_ARG_SIZE";
        case -52: return "CL_INVALID_KERNEL_ARGS";
        case -53: return "CL_INVALID_WORK_DIMENSION";
        case -54: return "CL_INVALID_WORK_GROUP_SIZE";
        case -55: return "CL_INVALID_WORK_ITEM_SIZE";
        case -56: return "CL_INVALID_GLOBAL_OFFSET";
        case -57: return "CL_INVALID_EVENT_WAIT_LIST";
        case -58: return "CL_INVALID_EVENT";
        case -59: return "CL_INVALID_OPERATION";
        case -60: return "CL_INVALID_GL_OBJECT";
        case -61: return "CL_INVALID_BUFFER_SIZE";
        case -62: return "CL_INVALID_MIP_LEVEL";
        case -63: return "CL_INVALID_GLOBAL_WORK_SIZE";
        case -64: return "CL_INVALID_PROPERTY";
        case -65: return "CL_INVALID_IMAGE_DESCRIPTOR";
        case -66: return "CL_INVALID_COMPILER_OPTIONS";
        case -67: return "CL_INVALID_LINKER_OPTIONS";
        case -68: return "CL_INVALID_DEVICE_PARTITION_COUNT";

        // extension errors
        case -1000: return "CL_INVALID_GL_SHAREGROUP_REFERENCE_KHR";
        case -1001: return "CL_PLATFORM_NOT_FOUND_KHR";
        case -1002: return "CL_INVALID_D3D10_DEVICE_KHR";
        case -1003: return "CL_INVALID_D3D10_RESOURCE_KHR";
        case -1004: return "CL_D3D10_RESOURCE_ALREADY_ACQUIRED_KHR";
        case -1005: return "CL_D3D10_RESOURCE_NOT_ACQUIRED_KHR";
        default: return "Unknown OpenCL error";
    }
}

const char *read_kernel(const char *path) {
    char * buffer = 0;
    long length;
    FILE *f = fopen (path, "rb");
    if(!f) {
        printf("Failed to open file \"%s\": %s",path, strerror(errno));
        exit(errno);
    }
    fseek (f, 0, SEEK_END);
    length = ftell (f);
    fseek (f, 0, SEEK_SET);
    buffer = malloc(length + 1);
    fread (buffer, 1, length, f);
    buffer[length] = '\0';
    fclose (f); 
    return buffer;
}


double getTime() {
    struct timespec t;
    clock_gettime(CLOCK_MONOTONIC, &t);
    return (t.tv_nsec/1.0e9) + t.tv_sec;
}

void checkCLError(const char *description, cl_int err){
    if(err) {
        printf("Failed to %s: %s\n", description, getErrorString(err));
        exit(err);
    }
}

int main(int argc, char **argv) {
    // OpenCL related declarations
    cl_int err;
    cl_platform_id platform;
    cl_device_id device;
    cl_context_properties props[3] = { CL_CONTEXT_PLATFORM, 0, 0 };
    cl_context ctx;
    cl_program program;
    cl_command_queue queue;
    cl_event event = NULL;
    cl_kernel k_sum_pixels;

    if(argc != 2) {
       printf("Usage is %s <kernel file>\n", argv[0]);
       exit(-1);
    }
    //read in kernel from file
    const char *kernel = read_kernel(argv[1]);
    
    /* Setup OpenCL environment. */
    err = clGetPlatformIDs( 1, &platform, NULL );
    checkCLError("get platform IDs", err);

    err = clGetDeviceIDs( platform, CL_DEVICE_TYPE_GPU, 1, &device, NULL );
    checkCLError("get device IDs", err);

    props[1] = (cl_context_properties)platform;
    ctx = clCreateContext( props, 1, &device, NULL, NULL, &err );
    checkCLError("create OpenCL context", err);
            
    queue = clCreateCommandQueue( ctx, device, 0, &err );
    checkCLError("create command queue", err);

    program = clCreateProgramWithSource(ctx, 1, (const char **) &kernel, NULL, &err);
    checkCLError("create program", err);

    err = clBuildProgram(program, 0, NULL, NULL, NULL, NULL);
    if (err == -11) {
        // Determine the size of the log
        size_t log_size;
        clGetProgramBuildInfo(program, device, CL_PROGRAM_BUILD_LOG, 0, NULL, &log_size);

        // Allocate memory for the log
        char *log = (char *) malloc(log_size);

        // Get the log
        clGetProgramBuildInfo(program, device, CL_PROGRAM_BUILD_LOG, log_size, log, NULL);

        // Print the log
        printf("%s\n", log);
    }
    checkCLError("build program", err);
    
    k_sum_pixels = clCreateKernel(program, "sum_pixels", &err);
    checkCLError("create kernel", err);
    
    //pixels per block 
    const size_t block_size = 32;
    const size_t pixels_per_block = block_size*block_size;
    
    //grid of blocks
    const size_t block_x = 125;
    const size_t block_y = 156;
    const size_t nblocks = block_x * block_y;
    
    //total number of pixels
    const size_t N = pixels_per_block*nblocks; // pixels
    
    uint8_t *pixels = calloc(N * 4, sizeof(uint8_t));
    float *heatmap = calloc(N, sizeof(float));
    float *blockScores = calloc(nblocks, sizeof(float));
    
    //set 2 pixel per block    
    for(int i = 0; i < block_y; i++) {
        for(int j = 0; j < block_x; j++) {
            size_t index = (pixels_per_block*block_x*i + block_size*j)*4;
            pixels[index] = i*j;
            pixels[index + block_size-4] = i + j;
        }
    }
    //cpu block scores
    
    
    //write pixels and heatmap
    cl_mem d_pixels = clCreateBuffer(ctx, CL_MEM_READ_WRITE, N*4*sizeof(*pixels), NULL, &err );
    checkCLError("create pixel buffer", err);

    err = clEnqueueWriteBuffer( queue, d_pixels, CL_TRUE, 0, N*4*sizeof(*pixels), pixels, 0, NULL, NULL );
    checkCLError("enqueue pixel buffer write", err);
    
    cl_mem d_heatmap = clCreateBuffer(ctx, CL_MEM_READ_WRITE, N*sizeof(*heatmap), NULL, &err );
    checkCLError("create heatmap buffer", err);

    err = clEnqueueWriteBuffer( queue, d_heatmap, CL_TRUE, 0, N*sizeof(*heatmap), heatmap, 0, NULL, NULL );
    checkCLError("enqueue heatmap buffer write", err);

    cl_mem d_blockScores = clCreateBuffer(ctx, CL_MEM_READ_WRITE, nblocks*sizeof(*blockScores), NULL, &err );
    checkCLError("create blockScores buffer", err);

    
    //set arguments to kernel
    err = clSetKernelArg(k_sum_pixels, 0, sizeof(cl_mem), &d_pixels);
    checkCLError("setting argument pixels", err);
    
    err = clSetKernelArg(k_sum_pixels, 1, sizeof(cl_mem), &d_heatmap);
    checkCLError("setting argument heatmap", err);

    err = clSetKernelArg(k_sum_pixels, 2, sizeof(cl_mem), &d_blockScores);
    checkCLError("setting argument blockScores", err);

    err = clSetKernelArg(k_sum_pixels, 3, pixels_per_block*sizeof(float), NULL);
    checkCLError("setting argument scores", err);

    
    size_t work_size[2] = {block_size, block_size};
    size_t global_size[2] = {block_size*block_x, block_size*block_y};
    double gpu_start = getTime();

    err = clEnqueueNDRangeKernel(queue, k_sum_pixels, 2, NULL, global_size, work_size, 0, NULL, NULL);
    if(err) {
        printf("Failed to enqueue range kernel, %s\n", getErrorString(err));
        exit(err);
    }
    err = clFinish(queue);
    err = clEnqueueNDRangeKernel(queue, k_sum_pixels, 2, NULL, global_size, work_size, 0, NULL, NULL);
    if(err) {
        printf("Failed to enqueue range kernel, %s\n", getErrorString(err));
        exit(err);
    }
    err = clFinish(queue);
    double gpu_end = getTime();
    printf("GPU processed %.1f MP in %.1fms\n", N/1.0e6, (gpu_end - gpu_start)*1000);

    err = clEnqueueReadBuffer( queue, d_blockScores, CL_TRUE, 0, nblocks*sizeof(*blockScores), blockScores, 0, NULL, NULL );
    err = clFinish(queue);
    
    /*
    printf("block scores:\n");
    for (int i = 0; i < block_y; i++) {
        for(int j = 0; j < block_x; j++) {
            printf("%5.1f ", blockScores[i*block_x + j]);
        }
        printf("\n");
    }
    printf("\n");
    */

    /* Release OpenCL memory objects. */
    clReleaseMemObject( d_pixels );
    clReleaseMemObject( d_heatmap );
    clReleaseMemObject( d_blockScores );
    free(pixels);
    free(heatmap);
    free(blockScores);
    clReleaseCommandQueue( queue );
    clReleaseContext( ctx );

    return 0;
}
