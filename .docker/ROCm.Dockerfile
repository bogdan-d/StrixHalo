# ROCm GPU Test Container for AMD Strix Halo (Radeon 8060S / gfx1151)
#
# Tests ROCm compute stack via Docker GPU passthrough.
# The host only needs the amdgpu kernel driver — all user-space tools
# are provided by this image.
#
# Build:  docker compose build rocm-test
# Run:    docker compose up -d rocm-test
# Test:   docker compose exec rocm-test /opt/rocm-test/verify-rocm.sh

FROM rocm/dev-ubuntu-24.04:6.4.1

LABEL maintainer="StrixHalo"
LABEL description="ROCm GPU test container for AMD Radeon 8060S (gfx1151)"

ENV DEBIAN_FRONTEND=noninteractive

# gfx1151 (RDNA 3.5) may lack native kernels in some libraries;
# fall back to gfx1100 (Navi 31) kernels which are compatible.
ENV HSA_OVERRIDE_GFX_VERSION=11.0.0

# Install additional diagnostic and test tools
RUN apt-get update && apt-get install -y --no-install-recommends \
    clinfo \
    python3 \
    python3-pip \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /opt/rocm-test
