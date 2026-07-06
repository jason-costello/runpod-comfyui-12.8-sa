#!/usr/bin/env bash
# First-run provisioning. Idempotent; everything lands on /workspace (network volume).
set -euo pipefail

WS=/workspace
VENV=$WS/venv
COMFY=$WS/ComfyUI
MARKER=$WS/.setup_complete
LOG=$WS/setup.log

exec > >(tee -a "$LOG") 2>&1

if [[ -f $MARKER ]]; then
    echo "[setup] already provisioned ($(cat "$MARKER")), skipping"
    exit 0
fi

echo "[setup] === first run: $(date -u) ==="

# ---------- Python 3.11 venv ----------
if [[ ! -d $VENV ]]; then
    python3.11 -m venv "$VENV"
fi
source "$VENV/bin/activate"
pip install -U pip wheel setuptools packaging build

# ---------- PyTorch 2.9 + CUDA 12.8 + Triton 3.5 ----------
pip install torch==${TORCH_VERSION} torchvision torchaudio \
    --index-url https://download.pytorch.org/whl/cu128
pip install "triton==${TRITON_VERSION}"

# ---------- FlashAttention 2.8.3 (pre-built wheel) ----------
PY_TAG=cp311
FA_WHL="flash_attn-${FLASH_ATTN_VERSION}+cu12torch2.9cxx11abiTRUE-${PY_TAG}-${PY_TAG}-linux_x86_64.whl"
FA_URL="https://github.com/Dao-AILab/flash-attention/releases/download/v${FLASH_ATTN_VERSION}/${FA_WHL}"
if ! pip install "$FA_URL"; then
    echo "[setup] pre-built flash-attn wheel not found at $FA_URL, falling back to abiFALSE"
    pip install "https://github.com/Dao-AILab/flash-attention/releases/download/v${FLASH_ATTN_VERSION}/flash_attn-${FLASH_ATTN_VERSION}+cu12torch2.9cxx11abiFALSE-${PY_TAG}-${PY_TAG}-linux_x86_64.whl" \
        || MAX_JOBS=4 pip install flash-attn==${FLASH_ATTN_VERSION} --no-build-isolation
fi

# ---------- SageAttention (build wheel via PEP 517, all modern archs incl. Blackwell) ----------
if ! ls $WS/wheels/sageattention-*.whl >/dev/null 2>&1; then
    mkdir -p $WS/wheels
    git clone --depth 1 https://github.com/thu-ml/SageAttention.git $WS/src/SageAttention
    pushd $WS/src/SageAttention
    export TORCH_CUDA_ARCH_LIST="${TORCH_CUDA_ARCH_LIST}"
    export EXT_PARALLEL=4 NVCC_APPEND_FLAGS="--threads 8" MAX_JOBS=$(nproc)
    python -m build --wheel --no-isolation --outdir $WS/wheels
    popd
fi
pip install $WS/wheels/sageattention-*.whl

# ---------- TensorRT ----------
pip install tensorrt-cu12 onnx onnxruntime-gpu

# ---------- ComfyUI ----------
if [[ ! -d $COMFY ]]; then
    git clone https://github.com/comfyanonymous/ComfyUI.git "$COMFY"
    git -C "$COMFY" checkout "${COMFYUI_TAG}" || echo "[setup] tag ${COMFYUI_TAG} not found, staying on default branch"
fi
pip install -r "$COMFY/requirements.txt"

# ---------- ComfyUI-Manager ----------
if [[ ! -d $COMFY/custom_nodes/ComfyUI-Manager ]]; then
    git clone https://github.com/ltdrdata/ComfyUI-Manager.git "$COMFY/custom_nodes/ComfyUI-Manager"
fi
pip install -r "$COMFY/custom_nodes/ComfyUI-Manager/requirements.txt" || true

# ---------- ComfyUI TensorRT node (makes TensorRT usable in workflows) ----------
if [[ ! -d $COMFY/custom_nodes/ComfyUI_TensorRT ]]; then
    git clone https://github.com/comfyanonymous/ComfyUI_TensorRT.git "$COMFY/custom_nodes/ComfyUI_TensorRT"
fi
pip install -r "$COMFY/custom_nodes/ComfyUI_TensorRT/requirements.txt" || true

# ---------- Run scripts ----------
cp /opt/templates/run_gpu.sh /opt/templates/run_cpu.sh /opt/templates/download_models.sh $WS/
chmod +x $WS/run_gpu.sh $WS/run_cpu.sh $WS/download_models.sh

# ---------- Models ----------
$WS/download_models.sh || echo "[setup] model download had errors, re-run /workspace/download_models.sh"

date -u > "$MARKER"
echo "[setup] === done ==="
