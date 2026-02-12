#!/usr/bin/env python3
"""test-gpu.py — PyTorch ROCm GPU detection and simple compute test.

Requires a ROCm-enabled PyTorch install (not included in the base
rocm/dev image). Install with:
    pip3 install torch --index-url https://download.pytorch.org/whl/rocm6.4

Usage:
    docker compose exec rocm-test python3 /opt/rocm-test/test-gpu.py
"""
import sys


def main():
    try:
        import torch
    except ImportError:
        print("PyTorch is not installed.")
        print("Install with:  pip3 install torch --index-url https://download.pytorch.org/whl/rocm6.4")
        return 1

    print(f"PyTorch version : {torch.__version__}")
    print(f"CUDA available  : {torch.cuda.is_available()}")  # ROCm uses CUDA API
    print(f"HIP version     : {getattr(torch.version, 'hip', 'N/A')}")
    print(f"Device count    : {torch.cuda.device_count()}")

    if not torch.cuda.is_available():
        print("\nNo GPU detected by PyTorch. Check ROCm setup.")
        return 1

    device = torch.device("cuda:0")
    print(f"Device name     : {torch.cuda.get_device_name(0)}")
    print(f"Device memory   : {torch.cuda.get_device_properties(0).total_mem / 1e9:.1f} GB")

    # Simple matrix multiplication test
    print("\nRunning matrix multiplication test (2048x2048)...")
    a = torch.randn(2048, 2048, device=device)
    b = torch.randn(2048, 2048, device=device)

    # Warm up
    _ = torch.mm(a, b)
    torch.cuda.synchronize()

    # Timed run
    import time
    start = time.perf_counter()
    iterations = 100
    for _ in range(iterations):
        _ = torch.mm(a, b)
    torch.cuda.synchronize()
    elapsed = time.perf_counter() - start

    gflops = (2 * 2048**3 * iterations) / elapsed / 1e9
    print(f"  {iterations} iterations in {elapsed:.3f}s")
    print(f"  {gflops:.1f} GFLOPS (FP32)")
    print("\nGPU compute test PASSED.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
