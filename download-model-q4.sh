#!/bin/bash
# download-model-q4.sh - Download Qwen3-Coder-30B model (Q4) for StrixHalo LLM Server
#
# Model:   Qwen3-Coder-30B-A3B-Instruct-1M (Q4_K_XL quantization)
# Size:    ~18GB download, ~50GB RAM required with q4_0 KV cache
# Quality: Good quality, smaller and faster than Q8
# Source:  https://huggingface.co/unsloth/Qwen3-Coder-30B-A3B-Instruct-1M-GGUF
#
# Usage:
#   ./download-model-q4.sh
#
# After download, update docker-compose.yml:
#   MODEL_PATH=/models/Qwen3-Coder-30B-A3B-Instruct-1M-UD-Q4_K_XL.gguf
#
# Then start:
#   docker compose up -d
#
# For higher quality model (~34GB), use download-model.sh instead.
#
# Compatible with Qwen Code CLI: https://github.com/QwenLM/qwen-code

set -e

MODEL_URL="https://huggingface.co/unsloth/Qwen3-Coder-30B-A3B-Instruct-1M-GGUF/resolve/main/Qwen3-Coder-30B-A3B-Instruct-1M-UD-Q4_K_XL.gguf"
MODEL_NAME="Qwen3-Coder-30B-A3B-Instruct-1M-UD-Q4_K_XL.gguf"
MODELS_DIR="$(dirname "$0")/models"

echo "============================================"
echo "  StrixHalo Model Downloader (Q4)"
echo "============================================"
echo ""
echo "Model: Qwen3-Coder-30B-A3B-Instruct-1M (Q4_K_XL)"
echo "Size:  ~18 GB"
echo "Note:  Smaller/faster than Q8, slightly lower quality"
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
echo "To use this model, update docker-compose.yml:"
echo "  MODEL_PATH=/models/$MODEL_NAME"
echo ""
echo "Start the server with: docker compose up -d"
