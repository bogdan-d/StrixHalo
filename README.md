# StrixHalo LLM Server

Local LLM inference server optimized for AMD Ryzen AI MAX+ 395 (Strix Halo) with ROCm GPU acceleration. Runs Qwen3 models via llama.cpp in Docker with full GPU offloading.

## Hardware

| Component | Details |
|-----------|---------|
| CPU/GPU | AMD Ryzen AI MAX+ 395 w/ Radeon 8060S (gfx1151, RDNA 3.5) |
| Memory | 128 GB unified LPDDR5X |
| GPU Compute | ROCm 6.4.1 via HIP backend |

## Host System Setup

These steps only need to be done once per machine. Everything else runs in Docker.

### 1. Kernel

Kernel **6.16.9+** is required for Strix Halo UMA memory support. This system runs `6.17.0-14-generic`.

### 2. User Groups

The user must be in the `render` and `video` groups to access GPU devices:

```bash
sudo usermod -aG render $USER
sudo usermod -aG video $USER
# Log out and back in for changes to take effect
```

Verify:
```bash
id | grep -oP '(render|video)'
```

### 3. BIOS Settings (Required)

Strix Halo uses **unified memory** — the GPU and CPU share the same physical RAM. The BIOS **UMA Frame Buffer Size** setting controls how much RAM is carved out exclusively for the GPU at boot time. Whatever is carved out is **not visible to the OS**.

This is the most important setting for LLM inference. A large BIOS carveout wastes memory because the GPU can dynamically access system RAM via GTT regardless.

**BIOS path** (varies by vendor):
> Advanced → AMD CBS → NBIO → GFX Configuration → UMA Frame Buffer Size

| UMA Frame Buffer Size | OS Visible RAM | GPU VRAM (dedicated) | GPU GTT (dynamic) | Notes |
|-----------------------|----------------|----------------------|--------------------|-------|
| **Auto / 512 MB** | ~127 GB | 512 MB | Up to TTM limit | **Recommended** — maximizes usable memory |
| 4 GB | ~124 GB | 4 GB | Up to TTM limit | Good compromise |
| 16 GB | ~112 GB | 16 GB | Up to TTM limit | Unnecessary for compute |
| 96 GB (current) | ~32 GB | 96 GB | ~117 GB | **Too aggressive** — starves the OS |

With UMA set to **Auto/512 MB**, the GPU gets a small dedicated framebuffer for display, and the `ttm.pages_limit` kernel parameter controls how much *additional* system RAM the GPU can dynamically claim for compute (model weights, KV cache, etc.).

**Other recommended BIOS settings:**

| Setting | Recommended | Notes |
|---------|-------------|-------|
| IOMMU | Off | ~6% memory bandwidth improvement for LLM inference |
| TDP / Power Mode | 85W+ | Higher TDP = faster inference |

### 4. Kernel Boot Parameters (GPU Dynamic Memory)

After reducing the BIOS UMA carveout, the `ttm.pages_limit` kernel parameter controls how much system RAM the GPU can **dynamically** allocate for compute workloads (model weights, KV cache).

**Current configuration** in `/etc/default/grub`:
```
GRUB_CMDLINE_LINUX_DEFAULT="quiet splash ttm.pages_limit=32000000 ttm.page_pool_size=32000000"
```

This allows the GPU to dynamically claim up to **~122 GB** of system RAM on demand.

**Formula:** `pages = (target_GB × 1024 × 1024) / 4.096`

| RAM Installed | UMA BIOS Setting | TTM Target | pages_limit |
|---------------|------------------|------------|-------------|
| 128 GB | Auto / 512 MB | 120 GB | 30,720,000 |
| 64 GB | Auto / 512 MB | 58 GB | 14,848,000 |

After editing GRUB:
```bash
sudo update-grub
sudo reboot
```

**Verify after reboot:**
```bash
# TTM page limit
cat /sys/module/ttm/parameters/pages_limit

# OS visible memory (should be ~127 GB with Auto UMA)
free -h

# GPU VRAM reported (dedicated carveout only)
cat /sys/class/drm/card*/device/mem_info_vram_total

# GPU GTT (dynamic, from system RAM)
cat /sys/class/drm/card*/device/mem_info_gtt_total
```

### 5. GPU Device Files

These should be present automatically with the `amdgpu` kernel driver:

```bash
ls -la /dev/kfd /dev/dri/renderD128
```

No host ROCm installation is needed — the kernel driver is sufficient. All ROCm user-space tools run inside Docker.

## Quick Start

```bash
# Build and start the LLM server
docker compose up -d llm-server

# Test inference
curl http://localhost:8091/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model": "qwen3-coder-next", "messages": [{"role": "user", "content": "Hello"}]}'
```

## Model Configuration

Models are switched via the `.env` file (not docker-compose.yml):

```bash
# .env
MODEL_FILE=Qwen3-Coder-Next-Q8_0-00001-of-00003.gguf
MODEL_ALIAS=qwen3-coder-next
```

Place GGUF model files in the `models/` directory. After changing `.env`:
```bash
docker compose down llm-server && docker compose up -d llm-server
```

## Server Configuration

All llama-server settings are configured via **native `LLAMA_ARG_*` environment variables** in `docker-compose.yml`. No entrypoint script needed — llama-server reads these directly.

### Key Settings

| Environment Variable | Default | Description |
|---------------------|---------|-------------|
| `LLAMA_ARG_MODEL` | (from .env) | Path to GGUF model file |
| `LLAMA_ARG_ALIAS` | (from .env) | Model name for API responses |
| `LLAMA_ARG_CTX_SIZE` | 524288 | Total context window (split across slots) |
| `LLAMA_ARG_N_PARALLEL` | 2 | Number of parallel request slots |
| `LLAMA_ARG_N_GPU_LAYERS` | 999 | Layers offloaded to GPU (999 = all) |
| `LLAMA_ARG_FLASH_ATTN` | on | Flash attention |
| `LLAMA_ARG_CACHE_TYPE_K` | q8_0 | KV cache quantization for keys |
| `LLAMA_ARG_CACHE_TYPE_V` | q8_0 | KV cache quantization for values |
| `LLAMA_ARG_MMAP` | false | Disabled — fixes slow ROCm loading on UMA |
| `LLAMA_ARG_JINJA` | true | Jinja templates for tool/function calling |
| `LLAMA_ARG_BATCH` | 2048 | Logical batch size |
| `LLAMA_ARG_UBATCH` | 512 | Physical batch size |
| `LLAMA_ARG_TOP_K` | 40 | Top-k sampling |
| `LLAMA_ARG_ENDPOINT_METRICS` | true | Prometheus metrics endpoint |

Sampling parameters without native env vars are passed as CLI args via the `command:` directive:
```yaml
command: ["--temp", "1.0", "--top-p", "0.95", "--min-p", "0.01"]
```

See `llama-server --help` for all available `LLAMA_ARG_*` variables.

### ROCm Environment Variables

These are not llama-server options but are required for Strix Halo GPU acceleration:

| Variable | Value | Purpose |
|----------|-------|---------|
| `HSA_OVERRIDE_GFX_VERSION` | 11.0.0 | gfx1151 → gfx1100 kernel fallback |
| `GGML_CUDA_ENABLE_UNIFIED_MEMORY` | 1 | Zero-copy via hipMallocManaged() on UMA |
| `HSA_XNACK` | 1 | GPU page fault handling for unified memory |
| `ROCBLAS_USE_HIPBLASLT` | 1 | Faster GEMM operations (prompt processing) |
| `GPU_MAX_HW_QUEUES` | 2 | Reduce GPU queue contention for inference |

### Build Optimizations

The Dockerfile includes these compile-time optimizations:

| Flag | Purpose |
|------|---------|
| `-DGGML_HIP=ON` | ROCm/HIP GPU backend |
| `-DGGML_HIP_ROCWMMA_FATTN=ON` | rocWMMA flash attention for long context |
| `-DGGML_NATIVE=ON` | Zen 5 AVX-512 for CPU-side operations |
| `-DAMDGPU_TARGETS="gfx1100"` | Target GPU architecture |
| `-mllvm --amdgpu-unroll-threshold-local=600` | Prevents 40% prompt processing regression on RDNA 3.5 |

### Performance (Qwen3-Coder-Next 80B MoE Q8_0)

| Metric | Value |
|--------|-------|
| Model loading | ~50 seconds |
| Prompt processing | ~273 tokens/sec |
| Token generation | ~24 tokens/sec |
| Memory usage | ~95 GB / 120 GB limit |
| Context | 2 slots × 262K tokens |

## ROCm GPU Test Container

A separate lightweight container for testing GPU access without the LLM server:

```bash
# Start the test container
docker compose --profile test up -d rocm-test

# Run verification (tests rocminfo, rocm-smi, clinfo, hipconfig)
docker compose exec rocm-test /opt/rocm-test/verify-rocm.sh

# Test with different HSA overrides
docker compose exec -e HSA_OVERRIDE_GFX_VERSION=11.5.1 rocm-test rocminfo | head -40
```

## ROCm / gfx1151 Notes

The Radeon 8060S is **gfx1151 (RDNA 3.5)**, which is new hardware. Key compatibility details:

- **`HSA_OVERRIDE_GFX_VERSION=11.0.0`** is required — without it, ROCm 6.4.1 fails with `HSA_STATUS_ERROR_OUT_OF_RESOURCES`. This makes the GPU use gfx1100 (Navi 31) compute kernels, which are compatible.
- **`HSA_OVERRIDE_GFX_VERSION=11.5.1`** (native) also works for `rocminfo`/`rocm-smi`, but some libraries may lack native gfx1151 kernels.
- The override is set in both the Dockerfile and docker-compose.yml for redundancy.
- Future ROCm versions (7.x+) may add native gfx1151 support, at which point the override can be removed.

## Docker Compose Services

| Service | Image | Purpose |
|---------|-------|---------|
| `llm-server` | `.docker/LLM-ROCm.Dockerfile` | llama.cpp server with ROCm/HIP backend |
| `rocm-test` | `.docker/ROCm.Dockerfile` | GPU diagnostics and verification (profile: test) |

Both services require these Docker settings for ROCm:
- **`devices: /dev/kfd, /dev/dri`** — GPU kernel device passthrough
- **`group_add: 44, 992`** — video and render group GIDs
- **`ipc: host`** — HSA runtime needs shared memory
- **`security_opt: seccomp=unconfined`** — ROCm HSA needs relaxed seccomp

## Memory Budget for 1M Token Context

KV cache dominates memory at large contexts. All Qwen3 models use head_dim=128.

**KV cache formula:** `2 x layers x kv_heads x 128 x context x bytes_per_value`

| Model | Layers | KV Heads | KV Cache (q4_0, 1M) | + Weights (Q4_K_M) | Total |
|-------|--------|----------|----------------------|--------------------|-------|
| Qwen3-8B | 36 | 8 | 38.6 GB | 5.0 GB | ~44 GB |
| Qwen3-14B | 40 | 8 | 42.9 GB | 9.0 GB | ~52 GB |
| Qwen3-30B-A3B (MoE) | 48 | 4 | 25.7 GB | 18.6 GB | ~44 GB |
| Qwen3-32B | 64 | 8 | 68.7 GB | 19.8 GB | ~89 GB |

| RAM Config | BIOS UMA | Usable GPU Memory | Largest Model @ 1M (q4_0 KV) |
|------------|----------|-------------------|-------------------------------|
| 128 GB | Auto | ~120 GB (via TTM) | Qwen3-32B (Q8_0) |
| 128 GB | 96 GB | 96 GB dedicated + GTT | Same, but OS starved to ~32 GB |
| 64 GB | Auto | ~58 GB (via TTM) | Qwen3-14B (IQ4_XS) or Qwen3-30B-A3B (Q5_K_M) |

## File Structure

```
StrixHalo/
├── .docker/
│   ├── LLM-ROCm.Dockerfile   # llama.cpp + ROCm/HIP build
│   └── ROCm.Dockerfile        # ROCm test/diagnostics container
├── rocm-test/
│   ├── verify-rocm.sh         # GPU verification script
│   └── test-gpu.py            # PyTorch GPU compute test
├── models/                    # GGUF model files (git-ignored)
├── docker-compose.yml         # Service definitions + all llama-server config
├── .env                       # Model selection (MODEL_FILE, MODEL_ALIAS)
└── README.md
```

## Troubleshooting

### GPU not detected in container
```bash
# Check host devices
ls -la /dev/kfd /dev/dri/renderD128

# Check user groups
id | grep -oP '(render|video)'

# Check kernel driver
lsmod | grep amdgpu

# Quick Docker GPU test
docker run --rm --device=/dev/kfd --device=/dev/dri \
  --group-add 992 --group-add 44 --ipc=host \
  --security-opt seccomp=unconfined \
  -e HSA_OVERRIDE_GFX_VERSION=11.0.0 \
  rocm/dev-ubuntu-24.04:6.4.1 rocm-smi
```

### HSA_STATUS_ERROR_OUT_OF_RESOURCES
Set `HSA_OVERRIDE_GFX_VERSION=11.0.0`. Without it, ROCm 6.4.1 cannot initialize gfx1151.

### Model loading extremely slow (hours instead of seconds)
Ensure `LLAMA_ARG_MMAP=false` is set. The default mmap behavior is [catastrophically slow on ROCm UMA APUs](https://github.com/ggml-org/llama.cpp/issues/15018) past ~64GB — hipMemcpy copies mmap'd pages through a staging buffer page-by-page.

### Out of GPU memory / OS out of memory
- **Check BIOS UMA setting** — if set too high (e.g., 96 GB), the OS is starved. Set to Auto/512 MB and let TTM handle dynamic allocation.
- Reduce context: `LLAMA_ARG_CTX_SIZE=32768`
- Use q4_0 KV cache: `LLAMA_ARG_CACHE_TYPE_K=q4_0` / `LLAMA_ARG_CACHE_TYPE_V=q4_0`
- Use a smaller quantization (IQ4_XS, Q4_K_M)

### hipBLASLt fallback warning
```
rocBLAS warning: hipBlasLT failed, falling back to tensile.
```
This is benign. hipBLASLt doesn't have pre-tuned solutions for every GEMM size used by MoE models. It falls back to Tensile (rocBLAS standard) for those operations. Performance is not affected.

### Checking GPU memory allocation
```bash
# Inside a ROCm container
rocm-smi --showmeminfo all

# From host — check TTM config
cat /sys/module/ttm/parameters/pages_limit
```

## Endpoints

| Endpoint | Description |
|----------|-------------|
| `GET /health` | Health check |
| `GET /v1/models` | List loaded models |
| `POST /v1/chat/completions` | Chat completions (OpenAI-compatible) |
| `POST /v1/completions` | Text completions |
| `GET /metrics` | Prometheus metrics |

## References

- [llama.cpp](https://github.com/ggerganov/llama.cpp)
- [llama.cpp Issue #15018 — Slow ROCm loading on UMA APUs](https://github.com/ggml-org/llama.cpp/issues/15018)
- [Jeff Geerling — Increasing VRAM on AMD AI APUs](https://www.jeffgeerling.com/blog/2025/increasing-vram-allocation-on-amd-ai-apus-under-linux/)
- [Framework Strix Halo LLM Setup Guide](https://github.com/Gygeek/Framework-strix-halo-llm-setup)
- [ROCm Issue #5444 — Strix Halo VRAM visibility](https://github.com/ROCm/ROCm/issues/5444)
- [Unsloth Qwen3 GGUF Models](https://huggingface.co/collections/unsloth/qwen3)
