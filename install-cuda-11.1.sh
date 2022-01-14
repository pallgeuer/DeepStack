#!/bin/bash -i
# Install an isolated CUDA/cuDNN stack

# Retrieve the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Configuration
export CFG_MAX_GCC_VERSION=10
export CFG_CUDA_VERSION=11.1
export CFG_CUDA_URL='https://developer.download.nvidia.com/compute/cuda/11.1.1/local_installers/cuda_11.1.1_455.32.00_linux.run'
export CFG_CUDNN_VERSION=8.1.1
export CFG_CUDNN_URL='https://developer.nvidia.com/compute/machine-learning/cudnn/secure/8.1.1.33/11.2_20210301/cudnn-11.2-linux-x64-v8.1.1.33.tgz'

# Run the main installation script
"$SCRIPT_DIR/install-cuda.sh"
# EOF
