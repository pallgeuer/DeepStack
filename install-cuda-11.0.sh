#!/bin/bash -i
# Install an isolated CUDA/cuDNN stack

# Retrieve the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Configuration
export CFG_MAX_GCC_VERSION=9
export CFG_CUDA_VERSION=11.0
export CFG_CUDA_URL='https://developer.download.nvidia.com/compute/cuda/11.0.3/local_installers/cuda_11.0.3_450.51.06_linux.run'
export CFG_CUDNN_VERSION=8.0.5
export CFG_CUDNN_URL='https://developer.nvidia.com/compute/machine-learning/cudnn/secure/8.0.5/11.0_20201106/cudnn-11.0-linux-x64-v8.0.5.39.tgz'

# Run the main installation script
"$SCRIPT_DIR/install-cuda.sh"
# EOF
