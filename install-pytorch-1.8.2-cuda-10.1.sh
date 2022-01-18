#!/bin/bash -i
# Install an isolated CUDA/cuDNN stack

# Retrieve the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Configuration
export CFG_CUDA_VERSION=10.1
export CFG_PYTORCH_TAG=v1.8.2
export CFG_TORCHVISION_TAG=v0.9.2-rc2
export CFG_TORCHVISION_VERSION=0.9.2
export CFG_OPENCV_PYTHON_TAG=60
export CFG_CONDA_PYTHON=3.9

# Run the main installation script
"$SCRIPT_DIR/install-pytorch.sh"
# EOF
