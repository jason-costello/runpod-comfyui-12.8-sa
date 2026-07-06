# ComfyUI RunPod image: CUDA 12.8 + PyTorch 2.9 + FlashAttention 2.8.3 + SageAttention + TensorRT + code-server
FROM nvidia/cuda:12.8.1-cudnn-devel-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive \
    PIP_NO_CACHE_DIR=1 \
    PYTHONUNBUFFERED=1

RUN apt-get update && apt-get install -y --no-install-recommends \
        software-properties-common build-essential ninja-build cmake \
        wget curl git git-lfs ca-certificates openssh-server \
        libgl1 libglib2.0-0 ffmpeg aria2 jq && \
    add-apt-repository ppa:deadsnakes/ppa && apt-get update && \
    apt-get install -y --no-install-recommends \
        python3.11 python3.11-dev python3.11-venv python3.11-distutils && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

RUN wget -q https://bootstrap.pypa.io/get-pip.py && \
    python3.11 get-pip.py && rm get-pip.py && \
    update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.11 1

# code-server (VS Code in browser)
RUN curl -fsSL https://code-server.dev/install.sh | sh

# Version pins
ENV TORCH_VERSION=2.9.0 \
    TRITON_VERSION=3.5.0 \
    FLASH_ATTN_VERSION=2.8.3 \
    COMFYUI_TAG=v0.27.0 \
    # Blackwell: RTX 50-series (12.0), B100/B200 (10.0). Add Ada/Hopper/Ampere for portability.
    TORCH_CUDA_ARCH_LIST="8.0;8.6;8.9;9.0;10.0;12.0" \
    CUDA_HOME=/usr/local/cuda

COPY setup.sh /opt/setup.sh
COPY entrypoint.sh /opt/entrypoint.sh
COPY run_gpu.sh /opt/templates/run_gpu.sh
COPY run_cpu.sh /opt/templates/run_cpu.sh
COPY download_models.sh /opt/templates/download_models.sh
RUN chmod +x /opt/setup.sh /opt/entrypoint.sh /opt/templates/*.sh

RUN mkdir -p /workspace
WORKDIR /workspace

EXPOSE 8188 8888

ENTRYPOINT ["/opt/entrypoint.sh"]
