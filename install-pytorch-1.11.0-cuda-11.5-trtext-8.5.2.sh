#!/bin/bash
# Install PyTorch into a conda environment

# Retrieve the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Configuration
export CFG_CUDA_VERSION=11.5
export CFG_PYTORCH_TAG=v1.11.0
export CFG_TORCHVISION_TAG=v0.12.0
export CFG_TORCHAUDIO_TAG=e92a17c35fdff6b0622b0791b43e665c5d05c4b4  # One commit after v0.11.0
export CFG_TORCHAUDIO_VERSION=v0.11.0+e92a17c
export CFG_TORCHTEXT_TAG=v0.12.0
export CFG_OPENCV_TAG=4.5.4
export CFG_TENSORRT_VERSION=8.5.2
export CFG_TENSORRT_URL='https://developer.nvidia.com/downloads/compute/machine-learning/tensorrt/secure/8.5.2/tars/TensorRT-8.5.2.2.Linux.x86_64-gnu.cuda-11.8.cudnn8.6.tar.gz'
export CFG_TENSORRT_ONNX_TAG=fdeeaca87ad2eef316aafb016e1822502f383eea  # Current head of origin/8.5-GA branch, as the release/8.5-GA tag is only for TensorRT 8.5.1 and not TensorRT 8.5.2.2+ (should have onnx==1.12.0)
export CFG_TENSORRT_ONNX_VERSION='==1.12.0'
export CFG_TENSORRT_PYTORCH=0
export CFG_CONDA_PYTHON=3.9

# Run the main installation script
"$SCRIPT_DIR/install-pytorch.sh"
# EOF
