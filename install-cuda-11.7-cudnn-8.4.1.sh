#!/bin/bash
# Install an isolated CUDA/cuDNN stack

# Retrieve the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Configuration
export CFG_MAX_GCC_VERSION=11
export CFG_CUDA_VERSION=11.7
export CFG_CUDA_URL='https://developer.download.nvidia.com/compute/cuda/11.7.1/local_installers/cuda_11.7.1_515.65.01_linux.run'
export CFG_CUDA_SAMPLES_TAG=v11.6
export CFG_CUDNN_VERSION=8.4.1
export CFG_CUDNN_URL='https://developer.nvidia.com/compute/cudnn/secure/8.4.1/local_installers/11.6/cudnn-linux-x86_64-8.4.1.50_cuda11.6-archive.tar.xz'

# Run the main installation script
"$SCRIPT_DIR/install-cuda.sh"
# EOF
