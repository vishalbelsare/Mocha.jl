#include <algorithm>
#include <limits>

template <typename T>
void max_pooling_impl(const T *input, T *output, size_t *mask, int width, int height, int channels, int num,
    int pooled_width, int pooled_height, int kernel_w, int kernel_h, int pad_w, int pad_h,
    int stride_w, int stride_h) {

  int input_offset = width*height;
  int output_offset = pooled_width*pooled_height;
  std::fill(output, output + pooled_width*pooled_height*channels*num, -std::numeric_limits<T>::max());

  for (int n = 0; n < num; ++n) {
    for (int c = 0; c < channels; ++c) {
      for (int ph = 0; ph < pooled_height; ++ph) {
        for (int pw = 0; pw < pooled_width; ++pw) {
          int hstart = std::max(ph*stride_h - pad_h, 0);
          int wstart = std::max(pw*stride_w - pad_w, 0);
          int hend   = std::min(hstart + kernel_h, height);
          int wend   = std::min(wstart + kernel_w, width);

          int pool_index = ph * pooled_width + pw;
          for (int h = hstart; h < hend; ++h) {
            for (int w = wstart; w < wend; ++w) {
              int index = h * width + w;
              if (input[index] > output[pool_index]) {
                output[pool_index] = input[index];
                mask[pool_index] = index;
              }
            }
          }
        }
      }

      input += input_offset;
      output += output_offset;
      mask += output_offset;
    }
  }
}

extern "C" {
  void max_pooling_impl_double(const double *input, double *output, size_t *mask,
      int width, int height, int channels, int num, int pooled_width, int pooled_height,
      int kernel_w, int kernel_h, int pad_w, int pad_h, int stride_w, int stride_h) {
    max_pooling_impl(input, output, mask, width, height, channels, num,
        pooled_width, pooled_height, kernel_w, kernel_h, pad_w, pad_h, stride_w, stride_h);
  }
}
