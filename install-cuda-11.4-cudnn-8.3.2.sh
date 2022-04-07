#!/bin/bash
# Install an isolated CUDA/cuDNN stack

# Retrieve the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Configuration
export CFG_MAX_GCC_VERSION=11
export CFG_CUDA_VERSION=11.4
export CFG_CUDA_URL='https://developer.download.nvidia.com/compute/cuda/11.4.4/local_installers/cuda_11.4.4_470.82.01_linux.run'
export CFG_CUDA_SAMPLES_TAG=v11.4.1
export CFG_CUDNN_VERSION=8.3.2
export CFG_CUDNN_URL='https://developer.nvidia.com/compute/cudnn/secure/8.3.2/local_installers/11.5/cudnn-linux-x86_64-8.3.2.44_cuda11.5-archive.tar.xz'

# Run the main installation script
"$SCRIPT_DIR/install-cuda.sh"
# EOF
