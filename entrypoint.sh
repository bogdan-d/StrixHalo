#!/bin/bash
# entrypoint.sh - StrixHalo LLM Server launcher
#
# Launches llama-server with Vulkan GPU acceleration for AMD Strix Halo.
# Configured via environment variables in docker-compose.yml.
#
# Environment variables:
#   MODEL_PATH      - Path to GGUF model file (required)
#   MODEL_ALIAS     - Model name for API responses
#   GPU_LAYERS      - Layers to offload to GPU (999 = all)
#   CTX_SIZE        - Context window size in tokens
#   PARALLEL        - Number of parallel request slots
#   BATCH_SIZE      - Logical batch size
#   UBATCH_SIZE     - Physical batch size
#   FLASH_ATTENTION - Enable flash attention (true/false)
#   CONT_BATCHING   - Enable continuous batching (true/false)
#   KV_CACHE_TYPE   - KV cache quantization (q8_0, q4_0, f16, etc.)
#   MLOCK           - Lock model in RAM (true/false)
#   API_KEY         - Optional API key for authentication

set -e

# Build command
CMD="/opt/llama.cpp/build/bin/llama-server"
CMD="$CMD -m ${MODEL_PATH}"
CMD="$CMD --host ${HOST:-0.0.0.0}"
CMD="$CMD --port ${PORT:-8091}"
CMD="$CMD --ctx-size ${CTX_SIZE:-131072}"

# GPU layers
if [ "${GPU_LAYERS:-0}" != "0" ]; then
    CMD="$CMD --n-gpu-layers ${GPU_LAYERS}"
fi

# Parallel request slots (always set to override auto-detection)
CMD="$CMD --parallel ${PARALLEL:-1}"

# Batch sizes for throughput
if [ -n "${BATCH_SIZE}" ]; then
    CMD="$CMD --batch-size ${BATCH_SIZE}"
fi

if [ -n "${UBATCH_SIZE}" ]; then
    CMD="$CMD --ubatch-size ${UBATCH_SIZE}"
fi

# Flash attention
if [ "${FLASH_ATTENTION:-false}" = "true" ]; then
    CMD="$CMD --flash-attn on"
fi

# Continuous batching
if [ "${CONT_BATCHING:-false}" = "true" ]; then
    CMD="$CMD --cont-batching"
fi

# KV Cache quantization (reduces memory, can improve speed)
if [ -n "${KV_CACHE_TYPE}" ]; then
    CMD="$CMD --cache-type-k ${KV_CACHE_TYPE} --cache-type-v ${KV_CACHE_TYPE}"
fi

# mlock (keep model in RAM)
if [ "${MLOCK:-false}" = "true" ]; then
    CMD="$CMD --mlock"
fi

# Model alias
if [ -n "${MODEL_ALIAS}" ]; then
    CMD="$CMD --alias ${MODEL_ALIAS}"
fi

# API key (optional)
if [ -n "${API_KEY}" ]; then
    CMD="$CMD --api-key ${API_KEY}"
fi

# Metrics endpoint
CMD="$CMD --metrics"

# Additional arguments passed to container
if [ $# -gt 0 ]; then
    CMD="$CMD $@"
fi

echo "============================================"
echo "  StrixHalo LLM Server (Vulkan)"
echo "============================================"
echo "Model: ${MODEL_PATH}"
echo "Context: ${CTX_SIZE:-131072} tokens"
echo "Parallel slots: ${PARALLEL:-1}"
echo "KV cache type: ${KV_CACHE_TYPE:-f16}"
echo "Flash attention: ${FLASH_ATTENTION:-false}"
echo "============================================"
echo ""
echo "Starting server..."
echo "Command: $CMD"
echo ""

exec $CMD
