/*
 * Copyright (c) 2017-2018 ARM Limited.
 *
 * SPDX-License-Identifier: MIT
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to
 * deal in the Software without restriction, including without limitation the
 * rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
 * sell copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */

#include "helpers.h"

#if defined(CONV_STRIDE_X)

#if CONV_STRIDE_X == 1
#define convolution1x3 convolution1x3_stride_1
#elif CONV_STRIDE_X == 2
#define convolution1x3 convolution1x3_stride_2
#elif CONV_STRIDE_X == 3
#define convolution1x3 convolution1x3_stride_3
#else /* CONV_STRIDE_X */
#error "Stride not supported"
#endif /* CONV_STRIDE_X */

/** Compute a 1D horizontal convolution of size 3 and stride 1 for floating point type.
 *
 * @param[in] left_pixel   Pointer to the left pixel.
 * @param[in] left_coeff   Weight of the left pixel
 * @param[in] middle_coeff Weight of the middle pixel
 * @param[in] right_coeff  Weight of the right pixel
 *
 * @return a float2 containing 2 convoluted values.
 */
inline float2 convolution1x3_stride_1(__global const uchar *left_pixel,
                                      const float           left_coeff,
                                      const float           middle_coeff,
                                      const float           right_coeff)
{
    float4 temp = vload4(0, (__global float *)left_pixel);

    float2 left   = CONVERT(temp.s01, float2);
    float2 middle = CONVERT(temp.s12, float2);
    float2 right  = CONVERT(temp.s23, float2);

    return left * (float2)left_coeff + middle * (float2)middle_coeff + right * (float2)right_coeff;
}

/** Compute a 1D horizontal convolution of size 3 and stride 2 for floating point type.
 *
 * @param[in] left_pixel   Pointer to the left pixel.
 * @param[in] left_coeff   Weight of the left pixel
 * @param[in] middle_coeff Weight of the middle pixel
 * @param[in] right_coeff  Weight of the right pixel
 *
 * @return a float2 containing 2 convoluted values.
 */
inline float2 convolution1x3_stride_2(__global const uchar *left_pixel,
                                      const float           left_coeff,
                                      const float           middle_coeff,
                                      const float           right_coeff)
{
    float4 temp0 = vload4(0, (__global float *)left_pixel);
    float  temp1 = *((__global float *)(left_pixel + 4 * sizeof(float)));

    float2 left   = CONVERT(temp0.s02, float2);
    float2 middle = CONVERT(temp0.s13, float2);
    float2 right  = CONVERT((float2)(temp0.s2, temp1), float2);

    return left * (float2)left_coeff + middle * (float2)middle_coeff + right * (float2)right_coeff;
}

/** Compute a 1D horizontal convolution of size 3 and stride 3 for floating point type.
 *
 * @param[in] left_pixel   Pointer to the left pixel.
 * @param[in] left_coeff   Weight of the left pixel
 * @param[in] middle_coeff Weight of the middle pixel
 * @param[in] right_coeff  Weight of the right pixel
 *
 * @return a float2 containing 2 convoluted values.
 */
inline float2 convolution1x3_stride_3(__global const uchar *left_pixel,
                                      const float           left_coeff,
                                      const float           middle_coeff,
                                      const float           right_coeff)
{
    float4 temp0 = vload4(0, (__global float *)left_pixel);
    float2 temp1 = vload2(0, (__global float *)(left_pixel + 4 * sizeof(float)));

    float2 left   = CONVERT(temp0.s03, float2);
    float2 middle = CONVERT((float2)(temp0.s1, temp1.s0), float2);
    float2 right  = CONVERT((float2)(temp0.s2, temp1.s1), float2);

    return left * (float2)left_coeff + middle * (float2)middle_coeff + right * (float2)right_coeff;
}

/** Apply a 3x3 convolution matrix to a single channel F32 input image and return the result.
 *
 * Convolution matrix layout:
 *
 * [ mat0, mat1, mat2 ]\n
 * [ mat3, mat4, mat5 ]\n
 * [ mat6, mat7, mat8 ]\n
 *
 * @param[in] src  A pointer to source Image structure
 * @param[in] mat0 Coefficient from the convolution matrix
 * @param[in] mat1 Coefficient from the convolution matrix
 * @param[in] mat2 Coefficient from the convolution matrix
 * @param[in] mat3 Coefficient from the convolution matrix
 * @param[in] mat4 Coefficient from the convolution matrix
 * @param[in] mat5 Coefficient from the convolution matrix
 * @param[in] mat6 Coefficient from the convolution matrix
 * @param[in] mat0 Coefficient from the convolution matrix
 * @param[in] mat7 Coefficient from the convolution matrix
 * @param[in] mat8 Coefficient from the convolution matrix
 *
 * @return a float2 containing 2 convoluted values.
 */
inline float2 convolution3x3(
    Image      *src,
    const float mat0, const float mat1, const float mat2,
    const float mat3, const float mat4, const float mat5,
    const float mat6, const float mat7, const float mat8)
{
    float2 pixels;

    pixels = convolution1x3(offset(src, 0, 0), mat0, mat1, mat2);
    pixels += convolution1x3(offset(src, 0, 1), mat3, mat4, mat5);
    pixels += convolution1x3(offset(src, 0, 2), mat6, mat7, mat8);

    return pixels;
}

/** This OpenCL kernel computes the depthwise convolution 3x3
 *
 * @param[in] src_ptr                               Pointer to the source image. Supported data types: F32
 * @param[in] src_stride_x                          Stride of the source image in X dimension (in bytes)
 * @param[in] src_step_x                            src_stride_x * number of elements along X processed per workitem(in bytes)
 * @param[in] src_stride_y                          Stride of the source image in Y dimension (in bytes)
 * @param[in] src_step_y                            src_stride_y * number of elements along Y processed per workitem(in bytes)
 * @param[in] src_offset_first_element_in_bytes     The offset of the first element in the source image
 * @param[in] src_stride_z                          Stride of the source tensor in Z dimension (in bytes)
 * @param[in] src_step_z                            src_stride_z * number of elements along Y processed per workitem(in bytes)
 * @param[in] dst_ptr                               Pointer to the destination tensor. Supported data types: F32
 * @param[in] dst_stride_x                          Stride of the destination tensor in X dimension (in bytes)
 * @param[in] dst_step_x                            dst_stride_x * number of elements along X processed per workitem(in bytes)
 * @param[in] dst_stride_y                          Stride of the destination tensor in Y dimension (in bytes)
 * @param[in] dst_step_y                            dst_stride_y * number of elements along Y processed per workitem(in bytes)
 * @param[in] dst_stride_z                          Stride of the destination tensor in Z dimension (in bytes)
 * @param[in] dst_step_z                            dst_stride_z * number of elements along Y processed per workitem(in bytes)
 * @param[in] dst_offset_first_element_in_bytes     The offset of the first element in the destination tensor
 * @param[in] weights_ptr                           Pointer to the weights tensor. Supported data types: F32
 * @param[in] weights_stride_x                      Stride of the weights tensor in X dimension (in bytes)
 * @param[in] weights_step_x                        weights_stride_x * number of elements along X processed per workitem(in bytes)
 * @param[in] weights_stride_y                      Stride of the weights tensor in Y dimension (in bytes)
 * @param[in] weights_step_y                        weights_stride_y * number of elements along Y processed per workitem(in bytes)
 * @param[in] weights_stride_z                      Stride of the weights tensor in Z dimension (in bytes)
 * @param[in] weights_step_z                        weights_stride_z * number of elements along Y processed per workitem(in bytes)
 * @param[in] weights_offset_first_element_in_bytes The offset of the first element in the biases vector
 * @param[in] biases_ptr                            (Optional) Pointer to the biases vector. Supported data types: F16/F32
 * @param[in] biases_stride_x                       (Optional) Stride of the biases vector in X dimension (in bytes)
 * @param[in] biases_step_x                         (Optional) biases_stride_x * number of elements along X processed per workitem(in bytes)
 * @param[in] biases_offset_first_element_in_bytes  (Optional) The offset of the first element in the biases vector
 */
__kernel void depthwise_convolution_3x3(
    TENSOR3D_DECLARATION(src),
    TENSOR3D_DECLARATION(dst),
    TENSOR3D_DECLARATION(weights)
#if defined(HAS_BIAS)
    ,
    VECTOR_DECLARATION(biases)
#endif //defined(HAS_BIAS)
)
{
    Image    src     = CONVERT_TENSOR3D_TO_IMAGE_STRUCT(src);
    Image    dst     = CONVERT_TENSOR3D_TO_IMAGE_STRUCT(dst);
    Tensor3D weights = CONVERT_TO_TENSOR3D_STRUCT(weights);
#if defined(HAS_BIAS)
    Vector biases = CONVERT_TO_VECTOR_STRUCT_NO_STEP(biases);
#endif //defined(HAS_BIAS)

    uchar3 offset          = (uchar3)(0, 1, 2) * (uchar3)weights_stride_y;
    float3 weights_values0 = vload3(0, (__global float *)(weights.ptr + offset.s0));
    float3 weights_values1 = vload3(0, (__global float *)(weights.ptr + offset.s1));
    float3 weights_values2 = vload3(0, (__global float *)(weights.ptr + offset.s2));

    float2 pixels = convolution3x3(&src, weights_values0.s0, weights_values0.s1, weights_values0.s2,
                                   weights_values1.s0, weights_values1.s1, weights_values1.s2,
                                   weights_values2.s0, weights_values2.s1, weights_values2.s2);
#if defined(HAS_BIAS)
    pixels += (float2)(*((__global float *)(biases.ptr + get_global_id(2) * biases_stride_x)));
#endif //defined(HAS_BIAS)

    vstore2(pixels, 0, (__global float *)dst.ptr);
}
#endif //defined(CONV_STRIDE_X)

#define CONVOLUTION1x3_BIFROST2X1_STRIDE1(acc, src0, weights_row0) \
    ({                                                             \
        acc.s0 = fma(src0.s0, weights_row0.s0, acc.s0);            \
        acc.s0 = fma(src0.s1, weights_row0.s1, acc.s0);            \
        acc.s0 = fma(src0.s2, weights_row0.s2, acc.s0);            \
        acc.s1 = fma(src0.s1, weights_row0.s0, acc.s1);            \
        acc.s1 = fma(src0.s2, weights_row0.s1, acc.s1);            \
        acc.s1 = fma(src0.s3, weights_row0.s2, acc.s1);            \
    })

#define CONVOLUTION1x3_BIFROST2X1_STRIDE2(acc, src0, src1, weights_row0) \
    ({                                                                   \
        acc.s0 = fma(src0.s0, weights_row0.s0, acc.s0);                  \
        acc.s0 = fma(src0.s1, weights_row0.s1, acc.s0);                  \
        acc.s0 = fma(src0.s2, weights_row0.s2, acc.s0);                  \
        acc.s1 = fma(src0.s2, weights_row0.s0, acc.s1);                  \
        acc.s1 = fma(src0.s3, weights_row0.s1, acc.s1);                  \
        acc.s1 = fma(src1.s0, weights_row0.s2, acc.s1);                  \
    })

/** This OpenCL kernel is optimized for Bifrost architectures and computes the depthwise convolution 3x3 when both
 * stride_x and stride_y are equal to 1
 *
 * @param[in] src_ptr                               Pointer to the source image. Supported data types: F32
 * @param[in] src_stride_x                          Stride of the source image in X dimension (in bytes)
 * @param[in] src_step_x                            src_stride_x * number of elements along X processed per workitem(in bytes)
 * @param[in] src_stride_y                          Stride of the source image in Y dimension (in bytes)
 * @param[in] src_step_y                            src_stride_y * number of elements along Y processed per workitem(in bytes)
 * @param[in] src_offset_first_element_in_bytes     The offset of the first element in the source image
 * @param[in] src_stride_z                          Stride of the source tensor in Z dimension (in bytes)
 * @param[in] src_step_z                            src_stride_z * number of elements along Y processed per workitem(in bytes)
 * @param[in] dst_ptr                               Pointer to the destination tensor. Supported data types: F32
 * @param[in] dst_stride_x                          Stride of the destination tensor in X dimension (in bytes)
 * @param[in] dst_step_x                            dst_stride_x * number of elements along X processed per workitem(in bytes)
 * @param[in] dst_stride_y                          Stride of the destination tensor in Y dimension (in bytes)
 * @param[in] dst_step_y                            dst_stride_y * number of elements along Y processed per workitem(in bytes)
 * @param[in] dst_stride_z                          Stride of the destination tensor in Z dimension (in bytes)
 * @param[in] dst_step_z                            dst_stride_z * number of elements along Y processed per workitem(in bytes)
 * @param[in] dst_offset_first_element_in_bytes     The offset of the first element in the destination tensor
 * @param[in] weights_ptr                           Pointer to the weights tensor. Supported data types: F32
 * @param[in] weights_stride_x                      Stride of the weights tensor in X dimension (in bytes)
 * @param[in] weights_step_x                        weights_stride_x * number of elements along X processed per workitem(in bytes)
 * @param[in] weights_stride_y                      Stride of the weights tensor in Y dimension (in bytes)
 * @param[in] weights_step_y                        weights_stride_y * number of elements along Y processed per workitem(in bytes)
 * @param[in] weights_stride_z                      Stride of the weights tensor in Z dimension (in bytes)
 * @param[in] weights_step_z                        weights_stride_z * number of elements along Y processed per workitem(in bytes)
 * @param[in] weights_offset_first_element_in_bytes The offset of the first element in the biases vector
 * @param[in] biases_ptr                            (Optional) Pointer to the biases vector. Supported data types: F32
 * @param[in] biases_stride_x                       (Optional) Stride of the biases vector in X dimension (in bytes)
 * @param[in] biases_step_x                         (Optional) biases_stride_x * number of elements along X processed per workitem(in bytes)
 * @param[in] biases_offset_first_element_in_bytes  (Optional) The offset of the first element in the biases vector
 */
__kernel void depthwise_convolution_3x3_stridex1_stridey1_bifrost(
    TENSOR3D_DECLARATION(src),
    TENSOR3D_DECLARATION(dst),
    TENSOR3D_DECLARATION(weights)
#if defined(HAS_BIAS)
    ,
    VECTOR_DECLARATION(biases)
#endif //defined(HAS_BIAS)
)
{
    Image    src     = CONVERT_TENSOR3D_TO_IMAGE_STRUCT(src);
    Image    dst     = CONVERT_TENSOR3D_TO_IMAGE_STRUCT(dst);
    Tensor3D weights = CONVERT_TO_TENSOR3D_STRUCT(weights);

    float2 pixels0 = 0.0f;
    float2 pixels1 = 0.0f;
    float2 pixels2 = 0.0f;
    float2 pixels3 = 0.0f;

    __global uchar *weights_addr = (__global uchar *)weights.ptr;
    __global uchar *src_addr     = (__global uchar *)offset(&src, 0, 0);

    // Load the weights
    float3 weights_row0 = vload3(0, (__global float *)(weights_addr + 0 * weights_stride_y));
    float3 weights_row1 = vload3(0, (__global float *)(weights_addr + 1 * weights_stride_y));
    float3 weights_row2 = vload3(0, (__global float *)(weights_addr + 2 * weights_stride_y));

    // Note: Since each work-item computes 4x2 elements, we need to load 4 rows from the input tensor
    float4 src00 = vload4(0, (__global float *)(src_addr + 0 * src_stride_y)); // Row0
    float4 src10 = vload4(0, (__global float *)(src_addr + 1 * src_stride_y)); // Row1
    float4 src20 = vload4(0, (__global float *)(src_addr + 2 * src_stride_y)); // Row2
    float4 src30 = vload4(0, (__global float *)(src_addr + 3 * src_stride_y)); // Row3
    float4 src40 = vload4(0, (__global float *)(src_addr + 4 * src_stride_y)); // Row3
    float4 src50 = vload4(0, (__global float *)(src_addr + 5 * src_stride_y)); // Row3

    CONVOLUTION1x3_BIFROST2X1_STRIDE1(pixels0, src00, weights_row0);
    CONVOLUTION1x3_BIFROST2X1_STRIDE1(pixels0, src10, weights_row1);
    CONVOLUTION1x3_BIFROST2X1_STRIDE1(pixels0, src20, weights_row2);
    CONVOLUTION1x3_BIFROST2X1_STRIDE1(pixels1, src10, weights_row0);
    CONVOLUTION1x3_BIFROST2X1_STRIDE1(pixels1, src20, weights_row1);
    CONVOLUTION1x3_BIFROST2X1_STRIDE1(pixels1, src30, weights_row2);
    CONVOLUTION1x3_BIFROST2X1_STRIDE1(pixels2, src20, weights_row0);
    CONVOLUTION1x3_BIFROST2X1_STRIDE1(pixels2, src30, weights_row1);
    CONVOLUTION1x3_BIFROST2X1_STRIDE1(pixels2, src40, weights_row2);
    CONVOLUTION1x3_BIFROST2X1_STRIDE1(pixels3, src30, weights_row0);
    CONVOLUTION1x3_BIFROST2X1_STRIDE1(pixels3, src40, weights_row1);
    CONVOLUTION1x3_BIFROST2X1_STRIDE1(pixels3, src50, weights_row2);

#ifdef HAS_BIAS
    Vector biases = CONVERT_TO_VECTOR_STRUCT_NO_STEP(biases);

    float bias = *((__global float *)(vector_offset(&biases, get_global_id(2))));

    pixels0 += (float2)bias;
    pixels1 += (float2)bias;
    pixels2 += (float2)bias;
    pixels3 += (float2)bias;
#endif /* defined(HAS_BIAS) */

    vstore2(pixels0, 0, (__global float *)(dst.ptr + 0 * dst_stride_y));
    vstore2(pixels1, 0, (__global float *)(dst.ptr + 1 * dst_stride_y));
    vstore2(pixels2, 0, (__global float *)(dst.ptr + 2 * dst_stride_y));
    vstore2(pixels3, 0, (__global float *)(dst.ptr + 3 * dst_stride_y));
}

/** This OpenCL kernel is optimized for Bifrost architectures and computes the depthwise convolution 3x3 when both
 * stride_x and stride_y are equal to 2
 *
 * @param[in] src_ptr                               Pointer to the source image. Supported data types: F32
 * @param[in] src_stride_x                          Stride of the source image in X dimension (in bytes)
 * @param[in] src_step_x                            src_stride_x * number of elements along X processed per workitem(in bytes)
 * @param[in] src_stride_y                          Stride of the source image in Y dimension (in bytes)
 * @param[in] src_step_y                            src_stride_y * number of elements along Y processed per workitem(in bytes)
 * @param[in] src_offset_first_element_in_bytes     The offset of the first element in the source image
 * @param[in] src_stride_z                          Stride of the source tensor in Z dimension (in bytes)
 * @param[in] src_step_z                            src_stride_z * number of elements along Y processed per workitem(in bytes)
 * @param[in] dst_ptr                               Pointer to the destination tensor. Supported data types: F32
 * @param[in] dst_stride_x                          Stride of the destination tensor in X dimension (in bytes)
 * @param[in] dst_step_x                            dst_stride_x * number of elements along X processed per workitem(in bytes)
 * @param[in] dst_stride_y                          Stride of the destination tensor in Y dimension (in bytes)
 * @param[in] dst_step_y                            dst_stride_y * number of elements along Y processed per workitem(in bytes)
 * @param[in] dst_stride_z                          Stride of the destination tensor in Z dimension (in bytes)
 * @param[in] dst_step_z                            dst_stride_z * number of elements along Y processed per workitem(in bytes)
 * @param[in] dst_offset_first_element_in_bytes     The offset of the first element in the destination tensor
 * @param[in] weights_ptr                           Pointer to the weights tensor. Supported data types: F32
 * @param[in] weights_stride_x                      Stride of the weights tensor in X dimension (in bytes)
 * @param[in] weights_step_x                        weights_stride_x * number of elements along X processed per workitem(in bytes)
 * @param[in] weights_stride_y                      Stride of the weights tensor in Y dimension (in bytes)
 * @param[in] weights_step_y                        weights_stride_y * number of elements along Y processed per workitem(in bytes)
 * @param[in] weights_stride_z                      Stride of the weights tensor in Z dimension (in bytes)
 * @param[in] weights_step_z                        weights_stride_z * number of elements along Y processed per workitem(in bytes)
 * @param[in] weights_offset_first_element_in_bytes The offset of the first element in the biases vector
 * @param[in] biases_ptr                            (Optional) Pointer to the biases vector. Supported data types: F32
 * @param[in] biases_stride_x                       (Optional) Stride of the biases vector in X dimension (in bytes)
 * @param[in] biases_step_x                         (Optional) biases_stride_x * number of elements along X processed per workitem(in bytes)
 * @param[in] biases_offset_first_element_in_bytes  (Optional) The offset of the first element in the biases vector
 */
__kernel void depthwise_convolution_3x3_stridex2_stridey2_bifrost(
    TENSOR3D_DECLARATION(src),
    TENSOR3D_DECLARATION(dst),
    TENSOR3D_DECLARATION(weights)
#if defined(HAS_BIAS)
    ,
    VECTOR_DECLARATION(biases)
#endif //defined(HAS_BIAS)
)
{
    Image    src     = CONVERT_TENSOR3D_TO_IMAGE_STRUCT(src);
    Image    dst     = CONVERT_TENSOR3D_TO_IMAGE_STRUCT(dst);
    Tensor3D weights = CONVERT_TO_TENSOR3D_STRUCT(weights);

    float2 pixels0 = 0.0f;
    float2 pixels1 = 0.0f;

    __global uchar *weights_addr = (__global uchar *)weights.ptr;
    __global uchar *src_addr     = (__global uchar *)offset(&src, 0, 0);

    // Load the weights
    float3 weights_row0 = vload3(0, (__global float *)(weights_addr + 0 * weights_stride_y));
    float3 weights_row1 = vload3(0, (__global float *)(weights_addr + 1 * weights_stride_y));
    float3 weights_row2 = vload3(0, (__global float *)(weights_addr + 2 * weights_stride_y));

    // Note: Since each work-item computes 4x2 elements, we need to load 5 rows from the input tensor
    float4 src00 = vload4(0, (__global float *)(src_addr + 0 * src_stride_y)); // Row0
    float2 src01 = vload2(2, (__global float *)(src_addr + 0 * src_stride_y)); // Row0
    float4 src10 = vload4(0, (__global float *)(src_addr + 1 * src_stride_y)); // Row1
    float2 src11 = vload2(2, (__global float *)(src_addr + 1 * src_stride_y)); // Row1
    float4 src20 = vload4(0, (__global float *)(src_addr + 2 * src_stride_y)); // Row2
    float2 src21 = vload2(2, (__global float *)(src_addr + 2 * src_stride_y)); // Row2
    float4 src30 = vload4(0, (__global float *)(src_addr + 3 * src_stride_y)); // Row3
    float2 src31 = vload2(2, (__global float *)(src_addr + 3 * src_stride_y)); // Row3
    float4 src40 = vload4(0, (__global float *)(src_addr + 4 * src_stride_y)); // Row4
    float2 src41 = vload2(2, (__global float *)(src_addr + 4 * src_stride_y)); // Row4

    CONVOLUTION1x3_BIFROST2X1_STRIDE2(pixels0, src00, src01, weights_row0);
    CONVOLUTION1x3_BIFROST2X1_STRIDE2(pixels0, src10, src11, weights_row1);
    CONVOLUTION1x3_BIFROST2X1_STRIDE2(pixels0, src20, src21, weights_row2);
    CONVOLUTION1x3_BIFROST2X1_STRIDE2(pixels1, src20, src21, weights_row0);
    CONVOLUTION1x3_BIFROST2X1_STRIDE2(pixels1, src30, src31, weights_row1);
    CONVOLUTION1x3_BIFROST2X1_STRIDE2(pixels1, src40, src41, weights_row2);

#ifdef HAS_BIAS
    Vector biases = CONVERT_TO_VECTOR_STRUCT_NO_STEP(biases);

    float bias = *((__global float *)(vector_offset(&biases, get_global_id(2))));

    pixels0 += (float2)bias;
    pixels1 += (float2)bias;
#endif /* defined(HAS_BIAS) */

    vstore2(pixels0, 0, (__global float *)(dst.ptr + 0 * dst_stride_y));
    vstore2(pixels1, 0, (__global float *)(dst.ptr + 1 * dst_stride_y));
}

#if defined(SRC_WIDTH) && defined(DATA_TYPE)
/** This kernel reshapes each of the tensor's low three dimensions to single rows.
 *
 * @note Datatype and source width should be given as a preprocessor argument using -DDATA_TYPE=type and -DSRC_WIDTH=width. e.g. -DSRC_WIDTH=128
 *
 * @param[in]  src_ptr                              Pointer to the source tensor. Supported data types: F16/F32
 * @param[in]  src_stride_x                         Stride of the source tensor in X dimension (in bytes)
 * @param[in]  src_step_x                           src_stride_x * number of elements along X processed per workitem(in bytes)
 * @param[in]  src_stride_y                         Stride of the source tensor in Y dimension (in bytes)
 * @param[in]  src_step_y                           src_stride_y * number of elements along Y processed per workitem(in bytes)
 * @param[in]  src_stride_z                         Stride of the source tensor in Z dimension (in bytes)
 * @param[in]  src_step_z                           src_stride_z * number of elements along Y processed per workitem(in bytes)
 * @param[in]  src_offset_first_element_in_bytes    The offset of the first element in the source tensor
 * @param[out] dst_ptr                              Pointer to the destination tensor. Same as @p src_ptr
 * @param[in]  dst_stride_x                         Stride of the destination tensor in X dimension (in bytes)
 * @param[in]  dst_step_x                           dst_stride_x * number of elements along X processed per workitem(in bytes)
 * @param[in]  dst_stride_y                         Stride of the destination tensor in Y dimension (in bytes)
 * @param[in]  dst_step_y                           dst_stride_y * number of elements along Y processed per workitem(in bytes)
 * @param[in]  dst_offset_first_element_in_bytes    The offset of the first element in the destination tensor
 * @param[in]  biases_ptr                           (Optional) Pointer to the biases vector. Supported data types: F16/F32
 * @param[in]  biases_stride_x                      (Optional) Stride of the biases vector in X dimension (in bytes)
 * @param[in]  biases_step_x                        (Optional) biases_stride_x * number of elements along X processed per workitem(in bytes)
 * @param[in]  biases_offset_first_element_in_bytes (Optional) The offset of the first element in the biases vector
 */
__kernel void depthwise_weights_reshape(
    TENSOR3D_DECLARATION(src),
    IMAGE_DECLARATION(dst)
#ifdef HAS_BIAS
    ,
    VECTOR_DECLARATION(biases)
#endif /* HAS_BIAS */
)
{
    Tensor3D src = CONVERT_TO_TENSOR3D_STRUCT(src);
#ifdef HAS_BIAS
    Vector biases = CONVERT_TO_VECTOR_STRUCT_NO_STEP(biases);
#endif /* HAS_BIAS */

    __global DATA_TYPE *input_ptr = (__global DATA_TYPE *)src.ptr;
    __global uchar *output_ptr    = dst_ptr + dst_offset_first_element_in_bytes + get_global_id(1) * SRC_WIDTH * dst_stride_x + get_global_id(2) * dst_stride_y;

    for(int i = 0; i < SRC_WIDTH; ++i, ++input_ptr)
    {
        *((__global DATA_TYPE *)(output_ptr + i * dst_stride_x)) = *input_ptr;
    }

#if defined(HAS_BIAS)
    if(get_global_id(1) == 0)
    {
        *((__global DATA_TYPE *)(output_ptr + SRC_WIDTH * get_global_size(1) * dst_stride_x)) = *((__global float *)(biases.ptr + get_global_id(2) * biases_stride_x));
    }
#endif // defined(HAS_BIAS)
}
#endif //defined(SRC_WIDTH) && defined(DATA_TYPE)

#if defined(STRIDE_X) && defined(STRIDE_Y) && defined(PAD_LEFT) && defined(PAD_TOP) && defined(PAD_RIGHT) && defined(PAD_BOTTOM) && defined(KERNEL_WIDTH) && defined(KERNEL_HEIGHT) && defined(SRC_WIDTH) && defined(SRC_HEIGHT) && defined(DATA_TYPE) && defined(PAD_VALUE)
/** This kernel performs a reshaping of the input tensor to a tensor used to perform depthwise convolution using vector to matrix multiplication.
 *
 * @note The data type must be passed at compile time using -DDATA_TYPE: e.g. -DDATA_TYPE=float
 * @note The convolution information must be passed at compile time using -DSTRIDE_X, -DSTRIDE_Y, -DPAD_LEFT, -DPAD_TOP, -DPAD_RIGHT, -DPAD_BOTTOM, -DKERNEL_WIDHT, -DKERNEL_HEIGHT, -DSRC_WIDTH, -DSRC_HEIGHT
 *
 * @param[in]  src_ptr                           Pointer to the source tensor. Supported data types: QS8/QS16/F16/F32
 * @param[in]  src_stride_x                      Stride of the source tensor in X dimension (in bytes)
 * @param[in]  src_step_x                        src_stride_x * number of elements along X processed per workitem(in bytes)
 * @param[in]  src_stride_y                      Stride of the source tensor in Y dimension (in bytes)
 * @param[in]  src_step_y                        src_stride_y * number of elements along Y processed per workitem(in bytes)
 * @param[in]  src_stride_z                      Stride of the source tensor in Z dimension (in bytes)
 * @param[in]  src_step_z                        src_stride_z * number of elements along Z processed per workitem(in bytes)
 * @param[in]  src_offset_first_element_in_bytes The offset of the first element in the source tensor
 * @param[out] dst_ptr                           Pointer to the destination tensor. Supported data types: same as @p src_ptr
 * @param[in]  dst_stride_x                      Stride of the destination tensor in X dimension (in bytes)
 * @param[in]  dst_step_x                        dst_stride_x * number of elements along X processed per workitem(in bytes)
 * @param[in]  dst_stride_y                      Stride of the destination tensor in Y dimension (in bytes)
 * @param[in]  dst_step_y                        dst_stride_y * number of elements along Y processed per workitem(in bytes)
 * @param[in]  dst_stride_z                      Stride of the destination tensor in Z dimension (in bytes)
 * @param[in]  dst_step_z                        dst_stride_z * number of elements along Z processed per workitem(in bytes)
 * @param[in]  dst_offset_first_element_in_bytes The offset of the first element in the destination tensor
 */
__kernel void depthwise_im2col(TENSOR3D_DECLARATION(src), TENSOR3D_DECLARATION(dst))
{
    Tensor3D dst = CONVERT_TO_TENSOR3D_STRUCT(dst);

    const int src_pixel_linear = get_global_id(1) * STRIDE_X;
    const int full_length      = SRC_WIDTH + PAD_LEFT + PAD_RIGHT;
    const int max_initial_x    = STRIDE_X * (((full_length - KERNEL_WIDTH) / STRIDE_X) + 1);

    const int src_x = -PAD_LEFT + src_pixel_linear % max_initial_x;
    const int src_y = -PAD_TOP + src_pixel_linear / max_initial_x * STRIDE_Y;
    const int src_z = get_global_id(2);

    __global uchar *input_ptr      = src_ptr + src_offset_first_element_in_bytes + src_z * src_stride_z;
    __global DATA_TYPE *output_ptr = ((__global DATA_TYPE *)(dst.ptr));

    for(int y = src_y; y < src_y + KERNEL_HEIGHT; ++y)
    {
        for(int x = src_x; x < src_x + KERNEL_WIDTH; ++x, ++output_ptr)
        {
            if(x < 0 || x >= SRC_WIDTH || y < 0 || y >= SRC_HEIGHT)
            {
                *output_ptr = PAD_VALUE;
            }
            else
            {
                *output_ptr = *((__global DATA_TYPE *)(input_ptr + x * src_stride_x + y * src_stride_y));
            }
        }
    }
#if defined(HAS_BIAS)
    *output_ptr = (DATA_TYPE)(1);
#endif // defined(HAS_BIAS)
}

#endif //defined(STRIDE_X) && defined(STRIDE_Y) && defined(PAD_LEFT) && defined(PAD_TOP) && defined(PAD_RIGHT) && defined(PAD_BOTTOM) && defined(KERNEL_WIDTH) && defined(KERNEL_HEIGHT) && defined(SRC_WIDTH) && defined(DATA_TYPE) && defined(PAD_VALUE)

#if defined(CONV_WIDTH) && defined(CONV_HEIGHT) && defined(DATA_TYPE)

/** This kernel performs a reshaping of the output of the depthwise generic convolution.
 *
 * @note The data type must be passed at compile time using -DDATA_TYPE: e.g. -DDATA_TYPE=float
 * @note The convolution information must be passed at compile time using -DCONV_WIDTH, -DCONV_HEIGHT, e.g -DCONV_WIDTH=32, -DCONV_HEIGHT=42
 *
 * @param[in]  src_ptr                           Pointer to the source tensor. Supported data types: QS8/QS16/F16/F32
 * @param[in]  src_stride_x                      Stride of the source tensor in X dimension (in bytes)
 * @param[in]  src_step_x                        src_stride_x * number of elements along X processed per workitem(in bytes)
 * @param[in]  src_offset_first_element_in_bytes The offset of the first element in the source tensor
 * @param[out] dst_ptr                           Pointer to the destination tensor. Supported data types: same as @p src_ptr
 * @param[in]  dst_stride_x                      Stride of the destination tensor in X dimension (in bytes)
 * @param[in]  dst_step_x                        dst_stride_x * number of elements along X processed per workitem(in bytes)
 * @param[in]  dst_stride_y                      Stride of the destination tensor in Y dimension (in bytes)
 * @param[in]  dst_step_y                        dst_stride_y * number of elements along Y processed per workitem(in bytes)
 * @param[in]  dst_stride_z                      Stride of the destination tensor in Z dimension (in bytes)
 * @param[in]  dst_step_z                        dst_stride_z * number of elements along Z processed per workitem(in bytes)
 * @param[in]  dst_offset_first_element_in_bytes The offset of the first element in the destination tensor
 */
__kernel void depthwise_vector_to_tensor(
    VECTOR_DECLARATION(src),
    TENSOR3D_DECLARATION(dst))
{
    Vector src = CONVERT_TO_VECTOR_STRUCT(src);

    const int patch_size = CONV_WIDTH * CONV_HEIGHT;
    const int id0        = get_global_id(0);
    const int z          = id0 / patch_size;
    const int index2D    = id0 - z * patch_size;

    __global uchar *out_ptr          = dst_ptr + dst_offset_first_element_in_bytes + index2D % CONV_WIDTH * dst_stride_x + index2D / CONV_WIDTH * dst_stride_y + z * dst_stride_z;
    *((__global DATA_TYPE *)out_ptr) = *((__global DATA_TYPE *)src.ptr);
}

#endif //defined(CONV_WIDTH) && defined(CONV_HEIGHT) && defined(DATA_TYPE)

#if defined(ARM_COMPUTE_OPENCL_FP16_ENABLED)
#if defined(CONV_STRIDE_X)
#if CONV_STRIDE_X == 1
#define convolution1x3_f16 convolution1x3_stride_1_f16
#elif CONV_STRIDE_X == 2
#define convolution1x3_f16 convolution1x3_stride_2_f16
#elif CONV_STRIDE_X == 3
#define convolution1x3_f16 convolution1x3_stride_3_f16
#else /* CONV_STRIDE_X */
#error "Stride not supported"
#endif /* CONV_STRIDE_X */

/** Compute a 1D horizontal convolution of size 3 and stride 1 for 16bit floating point type.
 *
 * @param[in] left_pixel   Pointer to the left pixel.
 * @param[in] left_coeff   Weight of the left pixel
 * @param[in] middle_coeff Weight of the middle pixel
 * @param[in] right_coeff  Weight of the right pixel
 *
 * @return a half4 containing 4 convoluted values.
 */
inline half4 convolution1x3_stride_1_f16(__global const uchar *left_pixel,
                                         const half            left_coeff,
                                         const half            middle_coeff,
                                         const half            right_coeff)
{
    half8 temp = vload8(0, (__global half *)left_pixel);

    half4 left   = CONVERT(temp.s0123, half4);
    half4 middle = CONVERT(temp.s1234, half4);
    half4 right  = CONVERT(temp.s2345, half4);

    return left * (half4)left_coeff + middle * (half4)middle_coeff + right * (half4)right_coeff;
}

/** Compute a 1D horizontal convolution of size 3 and stride 2 for 16bit floating point type.
 *
 * @param[in] left_pixel   Pointer to the left pixel.
 * @param[in] left_coeff   Weight of the left pixel
 * @param[in] middle_coeff Weight of the middle pixel
 * @param[in] right_coeff  Weight of the right pixel
 *
 * @return a half4 containing 4 convoluted values.
 */
inline half4 convolution1x3_stride_2_f16(__global const uchar *left_pixel,
                                         const half            left_coeff,
                                         const half            middle_coeff,
                                         const half            right_coeff)
{
    half8 temp0 = vload8(0, (__global half *)left_pixel);
    half temp1  = *((__global half *)(left_pixel + 8 * sizeof(half)));

    half4 left   = CONVERT(temp0.s0246, half4);
    half4 middle = CONVERT(temp0.s1357, half4);
    half4 right  = CONVERT((half4)(temp0.s246, temp1), half4);

    return left * (half4)left_coeff + middle * (half4)middle_coeff + right * (half4)right_coeff;
}

/** Compute a 1D horizontal convolution of size 3 and stride 3 for 16bit floating point type.
 *
 * @param[in] left_pixel   Pointer to the left pixel.
 * @param[in] left_coeff   Weight of the left pixel
 * @param[in] middle_coeff Weight of the middle pixel
 * @param[in] right_coeff  Weight of the right pixel
 *
 * @return a half4 containing 4 convoluted values.
 */
inline half4 convolution1x3_stride_3_f16(__global const uchar *left_pixel,
                                         const half            left_coeff,
                                         const half            middle_coeff,
                                         const half            right_coeff)
{
    half16 temp0 = vload16(0, (__global half *)left_pixel);

    half4 left   = CONVERT(temp0.s0369, half4);
    half4 middle = CONVERT(temp0.s147A, half4);
    half4 right  = CONVERT(temp0.s258B, half4);

    return left * (half4)left_coeff + middle * (half4)middle_coeff + right * (half4)right_coeff;
}

/** Apply a 3x3 convolution matrix to a single channel F16 input image and return the result.
 *
 * Convolution matrix layout:
 *
 * [ mat0, mat1, mat2 ]\n
 * [ mat3, mat4, mat5 ]\n
 * [ mat6, mat7, mat8 ]\n
 *
 * @param[in] src  A pointer to source Image structure
 * @param[in] mat0 Coefficient from the convolution matrix
 * @param[in] mat1 Coefficient from the convolution matrix
 * @param[in] mat2 Coefficient from the convolution matrix
 * @param[in] mat3 Coefficient from the convolution matrix
 * @param[in] mat4 Coefficient from the convolution matrix
 * @param[in] mat5 Coefficient from the convolution matrix
 * @param[in] mat6 Coefficient from the convolution matrix
 * @param[in] mat0 Coefficient from the convolution matrix
 * @param[in] mat7 Coefficient from the convolution matrix
 * @param[in] mat8 Coefficient from the convolution matrix
 *
 * @return a half4 containing 4 convoluted values.
 */
inline half4 convolution3x3_f16(
    Image     *src,
    const half mat0, const half mat1, const half mat2,
    const half mat3, const half mat4, const half mat5,
    const half mat6, const half mat7, const half mat8)
{
    half4 pixels;

    pixels = convolution1x3_f16(offset(src, 0, 0), mat0, mat1, mat2);
    pixels += convolution1x3_f16(offset(src, 0, 1), mat3, mat4, mat5);
    pixels += convolution1x3_f16(offset(src, 0, 2), mat6, mat7, mat8);

    return pixels;
}

/** This OpenCL kernel computes the depthwise convolution 3x3
 *
 * @param[in] src_ptr                               Pointer to the source image. Supported data types: F16
 * @param[in] src_stride_x                          Stride of the source image in X dimension (in bytes)
 * @param[in] src_step_x                            src_stride_x * number of elements along X processed per workitem(in bytes)
 * @param[in] src_stride_y                          Stride of the source image in Y dimension (in bytes)
 * @param[in] src_step_y                            src_stride_y * number of elements along Y processed per workitem(in bytes)
 * @param[in] src_offset_first_element_in_bytes     The offset of the first element in the source image
 * @param[in] src_stride_z                          Stride of the source tensor in Z dimension (in bytes)
 * @param[in] src_step_z                            src_stride_z * number of elements along Y processed per workitem(in bytes)
 * @param[in] dst_ptr                               Pointer to the destination tensor. Supported data types: F32
 * @param[in] dst_stride_x                          Stride of the destination tensor in X dimension (in bytes)
 * @param[in] dst_step_x                            dst_stride_x * number of elements along X processed per workitem(in bytes)
 * @param[in] dst_stride_y                          Stride of the destination tensor in Y dimension (in bytes)
 * @param[in] dst_step_y                            dst_stride_y * number of elements along Y processed per workitem(in bytes)
 * @param[in] dst_stride_z                          Stride of the destination tensor in Z dimension (in bytes)
 * @param[in] dst_step_z                            dst_stride_z * number of elements along Y processed per workitem(in bytes)
 * @param[in] dst_offset_first_element_in_bytes     The offset of the first element in the destination tensor
 * @param[in] weights_ptr                           Pointer to the weights tensor. Supported data types: F32
 * @param[in] weights_stride_x                      Stride of the weights tensor in X dimension (in bytes)
 * @param[in] weights_step_x                        weights_stride_x * number of elements along X processed per workitem(in bytes)
 * @param[in] weights_stride_y                      Stride of the weights tensor in Y dimension (in bytes)
 * @param[in] weights_step_y                        weights_stride_y * number of elements along Y processed per workitem(in bytes)
 * @param[in] weights_stride_z                      Stride of the weights tensor in Z dimension (in bytes)
 * @param[in] weights_step_z                        weights_stride_z * number of elements along Y processed per workitem(in bytes)
 * @param[in] weights_offset_first_element_in_bytes The offset of the first element in the biases vector
 * @param[in] biases_ptr                            (Optional) Pointer to the biases vector. Supported data types: F16/F32
 * @param[in] biases_stride_x                       (Optional) Stride of the biases vector in X dimension (in bytes)
 * @param[in] biases_step_x                         (Optional) biases_stride_x * number of elements along X processed per workitem(in bytes)
 * @param[in] biases_offset_first_element_in_bytes  (Optional) The offset of the first element in the biases vector
 */
__kernel void depthwise_convolution_3x3_f16(
    TENSOR3D_DECLARATION(src),
    TENSOR3D_DECLARATION(dst),
    TENSOR3D_DECLARATION(weights)
#if defined(HAS_BIAS)
    ,
    VECTOR_DECLARATION(biases)
#endif //defined(HAS_BIAS)
)
{
    Image    src     = CONVERT_TENSOR3D_TO_IMAGE_STRUCT(src);
    Image    dst     = CONVERT_TENSOR3D_TO_IMAGE_STRUCT(dst);
    Tensor3D weights = CONVERT_TO_TENSOR3D_STRUCT(weights);
#if defined(HAS_BIAS)
    Vector biases = CONVERT_TO_VECTOR_STRUCT_NO_STEP(biases);
#endif //defined(HAS_BIAS)

    uchar3 offset         = (uchar3)(0, 1, 2) * (uchar3)weights_stride_y;
    half3 weights_values0 = vload3(0, (__global half *)(weights.ptr + offset.s0));
    half3 weights_values1 = vload3(0, (__global half *)(weights.ptr + offset.s1));
    half3 weights_values2 = vload3(0, (__global half *)(weights.ptr + offset.s2));

    half4 pixels = convolution3x3_f16(&src, weights_values0.s0, weights_values0.s1, weights_values0.s2,
                                      weights_values1.s0, weights_values1.s1, weights_values1.s2,
                                      weights_values2.s0, weights_values2.s1, weights_values2.s2);
#if defined(HAS_BIAS)
    pixels += (half4)(*((__global half *)(biases.ptr + get_global_id(2) * biases_stride_x)));
#endif //defined(HAS_BIAS)

    vstore4(pixels, 0, (__global half *)dst.ptr);
}
#endif // defined(CONV_STRIDE_X)
#endif // defined(ARM_COMPUTE_OPENCL_FP16_ENABLED)
