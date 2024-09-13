#include "common.h"

#define THREAD_PER_BLOCK 256

// dim3 Grid( N/(2*THREAD_PER_BLOCK),1);
__global__ void reduce3(float* d_in, float* d_out) {
    __shared__ float sdata[THREAD_PER_BLOCK];

    // each thread loads one element from global to shared mem
    unsigned int tid = threadIdx.x;
    unsigned int i = blockIdx.x * (blockDim.x * 2) + threadIdx.x;
    sdata[tid] = d_in[i] + d_in[i + blockDim.x];
    __syncthreads();

    // do reduction in shared mem
    for (unsigned int s = blockDim.x / 2; s > 0; s >>= 1) {
        if (tid < s) {
            sdata[tid] += sdata[tid + s];
        }
        __syncthreads();
    }

    // write result for this block to global mem
    if (tid == 0) d_out[blockIdx.x] = sdata[0];
}


int reduce_v3_add_during_load() 
{
    const int N = 32 * 1024 * 1024;
    float* a = (float*)malloc(N * sizeof(float));
    float* d_a;
    cudaMalloc((void**)&d_a, N * sizeof(float));

    int NUM_PER_BLOCK = 2 * THREAD_PER_BLOCK;
    int block_num = N / NUM_PER_BLOCK;
    float* out = (float*)malloc(block_num * sizeof(float));
    float* d_out;
    cudaMalloc((void**)&d_out, block_num * sizeof(float));
    float* res = (float*)malloc(block_num * sizeof(float));

    for (int i = 0; i < N; i++) {
        a[i] = 1;
    }

    for (int i = 0; i < block_num; i++) {
        float cur = 0;
        for (int j = 0; j < NUM_PER_BLOCK; j++) {
            cur += a[i * NUM_PER_BLOCK + j];
        }
        res[i] = cur;
    }

    cudaMemcpy(d_a, a, N * sizeof(float), cudaMemcpyHostToDevice);

    dim3 Grid(block_num, 1);
    dim3 Block(THREAD_PER_BLOCK, 1);

    reduce3 << <Grid, Block >> > (d_a, d_out);

    cudaMemcpy(out, d_out, block_num * sizeof(float), cudaMemcpyDeviceToHost);

    if (check(out, res, block_num))printf("the ans is right\n");
    else {
        printf("the ans is wrong\n");
        for (int i = 0; i < block_num; i++) {
            printf("%lf ", out[i]);
        }
        printf("\n");
    }

    cudaFree(d_a);
    cudaFree(d_out);
    return 0;
}