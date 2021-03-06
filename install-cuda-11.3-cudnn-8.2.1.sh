#!/bin/bash
# Install an isolated CUDA/cuDNN stack

# Retrieve the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Configuration
export CFG_MAX_GCC_VERSION=10
export CFG_CUDA_VERSION=11.3
export CFG_CUDA_URL='https://developer.download.nvidia.com/compute/cuda/11.3.1/local_installers/cuda_11.3.1_465.19.01_linux.run'
export CFG_CUDNN_VERSION=8.2.1
export CFG_CUDNN_URL='https://developer.nvidia.com/compute/machine-learning/cudnn/secure/8.2.1.32/11.3_06072021/cudnn-11.3-linux-x64-v8.2.1.32.tgz'

# Run the main installation script
"$SCRIPT_DIR/install-cuda.sh"
# EOF
