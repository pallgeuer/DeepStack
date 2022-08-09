#!/bin/bash
# Install PyTorch into a conda environment

# Retrieve the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Configuration
export CFG_CUDA_VERSION=11.6
export CFG_PYTORCH_TAG=v1.12.1
export CFG_TORCHVISION_TAG=v0.13.1
export CFG_TORCHAUDIO_TAG=v0.12.1
export CFG_TORCHTEXT_TAG=v0.13.1
export CFG_OPENCV_TAG=4.5.5
export CFG_TENSORRT_VERSION=8.4.2
export CFG_TENSORRT_URL='https://developer.nvidia.com/compute/machine-learning/tensorrt/secure/8.4.2/tars/TensorRT-8.4.2.4.Linux.x86_64-gnu.cuda-11.6.cudnn8.4.tar.gz'
export CFG_TENSORRT_ONNX_TAG=c3cfcbc8248c6bd007e6630af2085df5e4834b42  # One commit after release/8.4-GA
export CFG_TENSORRT_PYTORCH=0
export CFG_CONDA_PYTHON=3.10

# Run the main installation script
"$SCRIPT_DIR/install-pytorch.sh"
# EOF
