#!/usr/bin/env bash
# Env-driven model downloads. Idempotent.
#
# HF_LORAS   comma or newline separated. Each item is either:
#              - full URL:  https://huggingface.co/owner/repo/resolve/main/file.safetensors
#              - shorthand: owner/repo/file.safetensors
# HF_TOKEN   HuggingFace token (needed for private/gated repos)
#
# MODEL_URL  checkpoint/diffusion model URL (HF or CivitAI). Defaults to Chroma.
# MODEL_DIR  subdir under ComfyUI/models (default: diffusion_models for Chroma,
#            checkpoints if overridden and not set)
# CAI        CivitAI API key (appended as token for civitai.com URLs)
set -uo pipefail

COMFY=/workspace/ComfyUI
DEFAULT_MODEL_URL="https://huggingface.co/lodestones/Chroma/resolve/main/chroma-unlocked-v37.safetensors"
MODEL_URL="${MODEL_URL:-$DEFAULT_MODEL_URL}"
MODEL_DIR="${MODEL_DIR:-$([[ $MODEL_URL == $DEFAULT_MODEL_URL ]] && echo diffusion_models || echo checkpoints)}"

fail=0

dl() { # url dest [auth_header]
    local url=$1 dest=$2 hdr=${3:-}
    [[ -s $dest ]] && { echo "[models] exists: $(basename "$dest")"; return 0; }
    echo "[models] downloading $(basename "$dest")"
    if curl -fL --retry 3 ${hdr:+-H "$hdr"} -o "$dest.part" "$url"; then
        mv "$dest.part" "$dest"
    else
        rm -f "$dest.part"; echo "[models] FAILED: $url"; fail=1
    fi
}

# ---------- LoRAs ----------
mkdir -p "$COMFY/models/loras"
if [[ -n "${HF_LORAS:-}" ]]; then
    while IFS= read -r item; do
        item=$(echo "$item" | xargs)   # trim
        [[ -z $item ]] && continue
        if [[ $item == http* ]]; then
            url=$item
        else
            owner_repo=$(echo "$item" | cut -d/ -f1,2)
            file=$(echo "$item" | cut -d/ -f3-)
            url="https://huggingface.co/${owner_repo}/resolve/main/${file}"
        fi
        fname=$(basename "${url%%\?*}")
        dl "$url" "$COMFY/models/loras/$fname" "${HF_TOKEN:+Authorization: Bearer $HF_TOKEN}"
    done < <(echo "$HF_LORAS" | tr ',' '\n')
else
    echo "[models] HF_LORAS not set, skipping LoRAs"
fi

# ---------- Model (default: Chroma) ----------
mkdir -p "$COMFY/models/$MODEL_DIR"
if [[ $MODEL_URL == *civitai.com* ]]; then
    sep=$([[ $MODEL_URL == *\?* ]] && echo "&" || echo "?")
    dl "${MODEL_URL}${sep}token=${CAI:?CAI not set for CivitAI URL}" \
       "$COMFY/models/$MODEL_DIR/civitai_$(echo "$MODEL_URL" | grep -oE '[0-9]+' | head -1).safetensors"
else
    fname=$(basename "${MODEL_URL%%\?*}")
    dl "$MODEL_URL" "$COMFY/models/$MODEL_DIR/$fname" "${HF_TOKEN:+Authorization: Bearer $HF_TOKEN}"
fi

exit $fail
