#!/usr/bin/env bash
# verify-rocm.sh — Quick verification of ROCm GPU access inside the container
#
# Usage: docker compose exec rocm-test /opt/rocm-test/verify-rocm.sh
set -euo pipefail

PASS=0
FAIL=0

section() { printf '\n\033[1;36m=== %s ===\033[0m\n' "$1"; }
ok()      { PASS=$((PASS+1)); printf '  \033[32m[PASS]\033[0m %s\n' "$1"; }
fail()    { FAIL=$((FAIL+1)); printf '  \033[31m[FAIL]\033[0m %s\n' "$1"; }

# ---- Device files ----
section "Device Files"
[ -c /dev/kfd ]            && ok "/dev/kfd present"            || fail "/dev/kfd missing"
[ -c /dev/dri/renderD128 ] && ok "/dev/dri/renderD128 present" || fail "/dev/dri/renderD128 missing"

# ---- rocminfo ----
section "rocminfo"
if command -v rocminfo &>/dev/null; then
    ROCM_OUT=$(rocminfo 2>&1) || true
    if echo "$ROCM_OUT" | grep -q "gfx"; then
        GPU_NAME=$(echo "$ROCM_OUT" | grep -m1 "Marketing Name" | grep -v CPU | sed 's/.*: *//')
        GFX_VER=$(echo "$ROCM_OUT" | grep -m1 "Name:.*gfx" | sed 's/.*: *//')
        ok "GPU agent found: ${GFX_VER:-unknown} — ${GPU_NAME:-unknown}"
    else
        fail "No GPU agent detected (only CPU agents found)"
    fi
    echo "$ROCM_OUT" | grep -E "(Name:|Marketing Name:|Device Type:)" | head -10
else
    fail "rocminfo not installed"
fi

# ---- rocm-smi ----
section "rocm-smi"
if command -v rocm-smi &>/dev/null; then
    rocm-smi 2>&1 && ok "rocm-smi executed" || fail "rocm-smi failed"
else
    fail "rocm-smi not installed"
fi

# ---- clinfo ----
section "clinfo (OpenCL)"
if command -v clinfo &>/dev/null; then
    CL_OUT=$(clinfo --list 2>&1) || true
    if echo "$CL_OUT" | grep -qi "platform\|device"; then
        ok "OpenCL platforms/devices found"
        echo "$CL_OUT"
    else
        fail "No OpenCL platforms detected"
    fi
else
    fail "clinfo not installed"
fi

# ---- hipconfig ----
section "hipconfig"
if command -v hipconfig &>/dev/null; then
    hipconfig --full 2>&1 && ok "hipconfig executed" || fail "hipconfig failed"
elif command -v hipcc &>/dev/null; then
    hipcc --version 2>&1 && ok "hipcc found" || fail "hipcc version check failed"
else
    fail "hipconfig/hipcc not installed"
fi

# ---- HSA override ----
section "Environment"
echo "  HSA_OVERRIDE_GFX_VERSION=${HSA_OVERRIDE_GFX_VERSION:-<not set>}"

# ---- Summary ----
section "Summary"
printf '  Passed: %d  Failed: %d\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ] && printf '  \033[32mAll checks passed!\033[0m\n' \
                   || printf '  \033[33mSome checks failed — see above.\033[0m\n'

exit "$FAIL"
