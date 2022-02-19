#!/bin/bash -i
# Install PyTorch into a conda environment

# Retrieve the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Configuration
export CFG_CUDA_VERSION=11.1
export CFG_PYTORCH_TAG=v1.9.1
export CFG_TORCHVISION_TAG=v0.10.1
export CFG_OPENCV_TAG=4.5.5
export CFG_TENSORRT_VERSION=7.2.3
export CFG_TENSORRT_URL='https://developer.nvidia.com/compute/machine-learning/tensorrt/secure/7.2.3/tars/TensorRT-7.2.3.4.Ubuntu-18.04.x86_64-gnu.cuda-11.1.cudnn8.1.tar.gz'
export CFG_CONDA_PYTHON=3.9

# Run the main installation script
"$SCRIPT_DIR/install-pytorch.sh"
# EOF
