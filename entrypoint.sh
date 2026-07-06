#!/usr/bin/env bash
set -uo pipefail

WS=/workspace
export HF_HUB_ENABLE_HF_TRANSFER=1
# First-run provisioning (idempotent; safe on every boot)
/opt/setup.sh || echo "[entrypoint] setup failed, see $WS/setup.log"

# VS Code in browser on 8888
PASSWORD="${VSCODE_PASSWORD:-}" code-server \
    --bind-addr 0.0.0.0:8888 \
    $( [[ -n "${VSCODE_PASSWORD:-}" ]] && echo "--auth password" || echo "--auth none" ) \
    "$WS" >"$WS/code-server.log" 2>&1 &

# Auto-start ComfyUI with SageAttention (restart manually: cd /workspace && ./run_gpu.sh)
if [[ -x $WS/run_gpu.sh ]]; then
    if command -v nvidia-smi >/dev/null && nvidia-smi >/dev/null 2>&1; then
        "$WS/run_gpu.sh" >"$WS/comfyui.log" 2>&1 &
    else
        echo "[entrypoint] no GPU detected, starting CPU mode"
        "$WS/run_cpu.sh" >"$WS/comfyui.log" 2>&1 &
    fi
fi

# Keep container alive
sleep infinity
