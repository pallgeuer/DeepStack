#!/bin/bash -i
# Install an isolated CUDA/cuDNN stack

# Retrieve the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Configuration
export CFG_MAX_GCC_VERSION=8
export CFG_CUDA_VERSION=10.2
export CFG_CUDA_URL='https://developer.download.nvidia.com/compute/cuda/10.2/Prod/local_installers/cuda_10.2.89_440.33.01_linux.run'
export CFG_CUDA_PATCH_URLS='https://developer.download.nvidia.com/compute/cuda/10.2/Prod/patches/1/cuda_10.2.1_linux.run https://developer.download.nvidia.com/compute/cuda/10.2/Prod/patches/2/cuda_10.2.2_linux.run'
export CFG_CUDNN_VERSION=7.6.5
export CFG_CUDNN_URL='https://developer.nvidia.com/compute/machine-learning/cudnn/secure/7.6.5.32/Production/10.2_20191118/cudnn-10.2-linux-x64-v7.6.5.32.tgz'

# Run the main installation script
"$SCRIPT_DIR/install-cuda.sh"
# EOF
