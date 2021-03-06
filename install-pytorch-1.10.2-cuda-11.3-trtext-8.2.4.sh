#!/bin/bash
# Install PyTorch into a conda environment

# Retrieve the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Configuration
export CFG_CUDA_VERSION=11.3
export CFG_PYTORCH_TAG=v1.10.2
export CFG_TORCHVISION_TAG=v0.11.3
export CFG_TORCHAUDIO_TAG=v0.10.2
export CFG_TORCHTEXT_TAG=v0.11.2
export CFG_OPENCV_TAG=4.5.5
export CFG_TENSORRT_VERSION=8.2.4
export CFG_TENSORRT_URL='https://developer.nvidia.com/compute/machine-learning/tensorrt/secure/8.2.4/tars/TensorRT-8.2.4.2.Linux.x86_64-gnu.cuda-11.4.cudnn8.2.tar.gz'
export CFG_TENSORRT_ONNX_TAG=22.02
export CFG_TENSORRT_PYTORCH=0  # Note: PyTorch <=1.10.2 does not support direct compilation with TensorRT 8, and TensorRT 7 does not support Python 3.9+/CUDA 11.2+
export CFG_CONDA_PYTHON=3.9

# Run the main installation script
"$SCRIPT_DIR/install-pytorch.sh"
# EOF
