#!/usr/bin/env bash
set -euo pipefail
source /workspace/venv/bin/activate
cd /workspace/ComfyUI
exec python main.py \
    --listen 0.0.0.0 --port 8188 \
    --cpu \
    "$@"
