using Benchmark
#
# On my laptop:
# | Row | Function         | Average   | Relative | Replications |
# |-----|------------------|-----------|----------|--------------|
# | 1   | "pooling_julia"  | 0.096299  | 1.0461   | 100          |
# | 2   | "pooling_native" | 0.0920551 | 1.0      | 100          |

function pooling(input::Array, output::Array, mask::Array, kernel, pad, stride)
  width, height, channels, num = size(input)
  pooled_width  = int(ceil(float(width +2*pad[1]-kernel[1]) / stride[1]))+1
  pooled_height = int(ceil(float(height+2*pad[2]-kernel[2]) / stride[2]))+1

  for n = 1:num
    for c = 1:channels
      for ph = 1:pooled_height
        for pw = 1:pooled_width
          hstart = max(1, (ph-1)*stride[2] - pad[2] + 1)
          wstart = max(1, (pw-1)*stride[1] - pad[1] + 1)
          hend = min(hstart + kernel[2] - 1, height)
          wend = min(wstart + kernel[1] - 1, width)

          maxval = -Inf
          maxw = 0
          maxh = 0
          for w = wstart:wend
            for h = hstart:hend
              @inbounds val = input[w,h,c,n]
              if val > maxval
                maxval = val
                maxw = w
                maxh = h
              end
            end
          end
          @inbounds output[pw,ph,c,n] = maxval
          @inbounds mask[pw,ph,c,n] = (maxh-1) * width + maxw-1
        end
      end
    end
  end
end

library = dlopen("./libpooling.so")
func_handle = dlsym(library, :max_pooling_impl_double)
function pooling_native(input::Array, output::Array, mask::Array, kernel, pad, stride)
  width, height, channels, num = size(input)
  pooled_width  = int(ceil(float(width +2*pad[1]-kernel[1]) / stride[1]))+1
  pooled_height = int(ceil(float(height+2*pad[2]-kernel[2]) / stride[2]))+1

  ccall(func_handle, Void, (Ptr{Float64}, Ptr{Float64}, Ptr{Csize_t}, Cint, Cint, Cint, Cint,
        Cint, Cint, # pooled_width, pooled_height
        Cint, Cint, Cint, Cint, Cint, Cint, # kernel, pad, stride
      ), input, output, mask, width, height, channels, num, pooled_width, pooled_height,
      kernel[1], kernel[2], pad[1], pad[2], stride[1], stride[2])
end

input = rand(28, 28, 50, 128)
kernel = (5, 5)
pad = (2, 2)
stride = (2, 2)
width, height, channels, num = size(input)
pooled_width  = int(ceil(float(width +2*pad[1]-kernel[1]) / stride[1]))+1
pooled_height = int(ceil(float(height+2*pad[2]-kernel[2]) / stride[2]))+1

output1 = zeros(pooled_width, pooled_height, channels, num)
output2 = zeros(pooled_width, pooled_height, channels, num)

mask1 = zeros(Csize_t, size(output1))
mask2 = zeros(Csize_t, size(output2))

pooling_julia() = pooling(input, output1, mask1, kernel, pad, stride)
pooling_native() = pooling_native(input, output2, mask2, kernel, pad, stride)

# make sure results are correct
pooling_julia()
pooling_native()
@assert all(abs(output1-output2) .< 1e-10)
@assert mask1 == mask2

# compare performance
df = compare([pooling_julia, pooling_native], 100)
println("$df")
