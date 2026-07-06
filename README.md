# ComfyUI Pod — CUDA 12.8 / PyTorch 2.9 / SageAttention / FlashAttention 2.8.3 / TensorRT

## Build
```bash
docker build -t comfyui-pod:cu128 .
```

## Run (RunPod template)
- Image: `comfyui-pod:cu128`
- Volume mount: `/workspace` (network volume)
- Expose ports: `8188` (ComfyUI HTTP), `8888` (VS Code HTTP)
- Env vars:
  - `HF_TOKEN` — HuggingFace token (LoRA downloads)
  - `CAI` — CivitAI API key (checkpoint download)
  - `VSCODE_PASSWORD` — optional; unset = no auth on code-server

## First boot
`entrypoint.sh` → `setup.sh` (idempotent, gated by `/workspace/.setup_complete`):
1. Python 3.11 venv at `/workspace/venv`
2. torch 2.9.0+cu128, torchvision, torchaudio, triton 3.5
3. flash-attn 2.8.3 pre-built wheel (cu12 / torch2.9 / cp311)
4. SageAttention wheel built via PEP 517 (`python -m build`) with
   `TORCH_CUDA_ARCH_LIST=8.0;8.6;8.9;9.0;10.0;12.0` (Ampere→Blackwell,
   B100/B200 = 10.0, RTX 50-series = 12.0); wheel cached in `/workspace/wheels`
5. tensorrt-cu12 + ComfyUI_TensorRT custom node
6. ComfyUI (tag v0.27.0) + ComfyUI-Manager
7. `run_gpu.sh` / `run_cpu.sh` / `download_models.sh` copied to `/workspace`
8. LoRAs → `ComfyUI/models/loras`, CivitAI checkpoint → `ComfyUI/models/checkpoints`

ComfyUI auto-starts with `--use-sage-attention`. Logs: `/workspace/comfyui.log`, `/workspace/setup.log`.

## Manual restart
```bash
cd /workspace
./run_gpu.sh
```

## Notes
- Everything lives on `/workspace`; the image is stateless. New pod on same volume skips setup.
- Force re-provision: `rm /workspace/.setup_complete`
- TensorRT engines are built per-GPU via the TensorRT nodes (Manager → ComfyUI_TensorRT workflows).
- Blackwell (SM 10.0/12.0) requires CUDA 12.8 nvcc — provided by the base image.
