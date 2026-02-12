# Dockerfile - llama.cpp with ROCm/HIP backend for StrixHalo LLM Server
#
# Optimized for AMD Ryzen AI Max+ 395 integrated GPU (Radeon 8060S / gfx1151)
# Uses ROCm HIP for GPU compute acceleration
# Includes tool/function calling support via Jinja templates
#
# Build:  docker compose build llm-server
# Run:    docker compose up -d llm-server
# Logs:   docker logs llm-rocm

FROM rocm/dev-ubuntu-24.04:6.4.1

LABEL maintainer="StrixHalo"
LABEL description="llama.cpp with ROCm/HIP for AMD Strix Halo (gfx1151)"

ENV DEBIAN_FRONTEND=noninteractive

# gfx1151 (RDNA 3.5) needs fallback to gfx1100 kernels in ROCm 6.4.1
ENV HSA_OVERRIDE_GFX_VERSION=11.0.0

# Install build dependencies, ROCm math libraries, and curl for health checks
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    cmake \
    git \
    curl \
    libcurl4-openssl-dev \
    hipblas-dev \
    rocblas-dev \
    hipblaslt-dev \
    rocwmma-dev \
    && rm -rf /var/lib/apt/lists/*

# Clone llama.cpp
WORKDIR /opt
RUN git clone https://github.com/ggerganov/llama.cpp.git

# Build with ROCm HIP backend
# - ROCWMMA flash attention: better long-context performance
# - NATIVE: enables Zen 5 AVX-512 for CPU-side operations
# - Unroll threshold: prevents 40% prompt processing regression on RDNA 3.5
WORKDIR /opt/llama.cpp
RUN cmake -S . -B build \
      -DGGML_HIP=ON \
      -DGGML_HIP_ROCWMMA_FATTN=ON \
      -DGGML_NATIVE=ON \
      -DCMAKE_BUILD_TYPE=Release \
      -DAMDGPU_TARGETS="gfx1100" \
      -DCMAKE_HIP_FLAGS="-mllvm --amdgpu-unroll-threshold-local=600" \
    && cmake --build build --config Release -- -j $(nproc)

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=120s --retries=3 \
    CMD curl -f http://localhost:${LLAMA_ARG_PORT:-8091}/health || exit 1

EXPOSE 8091

# All configuration via LLAMA_ARG_* environment variables in docker-compose.yml
ENTRYPOINT ["/opt/llama.cpp/build/bin/llama-server"]
