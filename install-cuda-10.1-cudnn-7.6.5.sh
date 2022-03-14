#!/bin/bash
# Install an isolated CUDA/cuDNN stack

# Retrieve the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Configuration
export CFG_MAX_GCC_VERSION=8
export CFG_CUDA_VERSION=10.1
export CFG_CUDA_URL='http://developer.download.nvidia.com/compute/cuda/10.1/Prod/local_installers/cuda_10.1.243_418.87.00_linux.run'
export CFG_CUDNN_VERSION=7.6.5
export CFG_CUDNN_URL='https://developer.nvidia.com/compute/machine-learning/cudnn/secure/7.6.5.32/Production/10.1_20191031/cudnn-10.1-linux-x64-v7.6.5.32.tgz'

# Run the main installation script
"$SCRIPT_DIR/install-cuda.sh"
# EOF
