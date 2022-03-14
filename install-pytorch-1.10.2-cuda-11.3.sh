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
export CFG_CONDA_PYTHON=3.9

# Run the main installation script
"$SCRIPT_DIR/install-pytorch.sh"
# EOF
