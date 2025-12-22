#!/bin/bash
# download-model.sh - Download Qwen3-Coder-30B model for StrixHalo LLM Server
#
# Model:   Qwen3-Coder-30B-A3B-Instruct-1M (Q8_K_XL quantization)
# Size:    ~34GB download, ~85GB RAM required with q8_0 KV cache
# Quality: Higher quality, recommended for best output
# Source:  https://huggingface.co/unsloth/Qwen3-Coder-30B-A3B-Instruct-1M-GGUF
#
# Usage:
#   ./download-model.sh
#
# After download:
#   docker compose up -d
#
# For smaller model (~18GB), use download-model-q4.sh instead.
#
# Compatible with Qwen Code CLI: https://github.com/QwenLM/qwen-code

set -e

MODEL_URL="https://huggingface.co/unsloth/Qwen3-Coder-30B-A3B-Instruct-1M-GGUF/resolve/main/Qwen3-Coder-30B-A3B-Instruct-1M-UD-Q8_K_XL.gguf"
MODEL_NAME="Qwen3-Coder-30B-A3B-Instruct-1M-UD-Q8_K_XL.gguf"
MODELS_DIR="$(dirname "$0")/models"

echo "============================================"
echo "  StrixHalo Model Downloader"
echo "============================================"
echo ""
echo "Model: Qwen3-Coder-30B-A3B-Instruct-1M"
echo "Size:  ~34 GB"
echo ""

# Create models directory
mkdir -p "$MODELS_DIR"

# Check if model already exists
if [ -f "$MODELS_DIR/$MODEL_NAME" ]; then
    echo "Model already exists at: $MODELS_DIR/$MODEL_NAME"
    read -p "Re-download? (y/N): " confirm
    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        echo "Skipping download."
        exit 0
    fi
fi

echo "Downloading to: $MODELS_DIR/$MODEL_NAME"
echo ""

# Download with curl (supports resume)
if command -v curl &> /dev/null; then
    curl -L -C - --progress-bar -o "$MODELS_DIR/$MODEL_NAME" "$MODEL_URL"
elif command -v wget &> /dev/null; then
    wget -c --show-progress -O "$MODELS_DIR/$MODEL_NAME" "$MODEL_URL"
else
    echo "Error: curl or wget required"
    exit 1
fi

echo ""
echo "Download complete!"
echo "Model saved to: $MODELS_DIR/$MODEL_NAME"
echo ""
echo "Start the server with: docker compose up -d"
