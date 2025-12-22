# Dockerfile - llama.cpp with Vulkan backend for StrixHalo LLM Server
#
# Optimized for AMD Ryzen AI Max+ 395 integrated GPU (Radeon 8060S)
# Uses Mesa RADV Vulkan driver for GPU acceleration
#
# Build:  docker compose build
# Run:    docker compose up -d
# Logs:   docker logs llm-vulkan
#
# Performance (after warmup):
#   - Prompt: ~400-480 tok/s
#   - Generation: ~35-40 tok/s
#
# Note: First request is slower due to Vulkan shader compilation

FROM ubuntu:24.04

LABEL maintainer="QuickAI"
LABEL description="llama.cpp with Vulkan for AMD Strix Halo integrated GPUs"

ENV DEBIAN_FRONTEND=noninteractive

# Install build dependencies and Vulkan SDK (Ubuntu 24.04 has newer Vulkan)
RUN apt-get update && apt-get install -y \
    build-essential \
    cmake \
    git \
    curl \
    libcurl4-openssl-dev \
    ccache \
    libvulkan-dev \
    vulkan-tools \
    mesa-vulkan-drivers \
    glslang-tools \
    glslc \
    vulkan-validationlayers \
    && rm -rf /var/lib/apt/lists/*

# Clone llama.cpp
WORKDIR /opt
RUN git clone https://github.com/ggerganov/llama.cpp.git

# Build with Vulkan support
WORKDIR /opt/llama.cpp
RUN cmake -S . -B build -DGGML_VULKAN=ON -DCMAKE_BUILD_TYPE=Release \
    && cmake --build build --config Release -- -j $(nproc)

# Default environment
ENV MODEL_PATH=/models/model.gguf
ENV GPU_LAYERS=999
ENV CTX_SIZE=131072
ENV HOST=0.0.0.0
ENV PORT=8091
ENV PARALLEL=1
ENV FLASH_ATTENTION=true
ENV CONT_BATCHING=true
ENV BATCH_SIZE=2048
ENV UBATCH_SIZE=512
ENV KV_CACHE_TYPE=q8_0
ENV MLOCK=false

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=120s --retries=3 \
    CMD curl -f http://localhost:${PORT}/health || exit 1

EXPOSE ${PORT}

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
