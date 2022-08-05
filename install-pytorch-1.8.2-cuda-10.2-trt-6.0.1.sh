#!/bin/bash
# Install PyTorch into a conda environment

# Retrieve the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Configuration
export CFG_CUDA_VERSION=10.2
export CFG_PYTORCH_TAG=v1.8.2
export CFG_TORCHVISION_TAG=v0.9.2
export CFG_TORCHAUDIO_TAG=v0.8.2
export CFG_TORCHTEXT_TAG=v0.9.2
export CFG_OPENCV_TAG=4.5.5
export CFG_TENSORRT_VERSION=6.0.1
export CFG_TENSORRT_URL='https://developer.nvidia.com/compute/machine-learning/tensorrt/secure/6.0/GA_6.0.1.5/tars/TensorRT-6.0.1.5.Ubuntu-18.04.x86_64-gnu.cuda-10.1.cudnn7.6.tar.gz'
export CFG_TENSORRT_ONNX_TAG=6.0-full-dims
export CFG_CONDA_PYTHON=3.7

# Run the main installation script
"$SCRIPT_DIR/install-pytorch.sh"
# EOF
