#!/bin/bash
# Install OpenCV python into a conda environment

# Retrieve the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Configuration
export CFG_CUDA_VERSION=11.6
export CFG_OPENCV_PYTHON_TAG=8f2049e  # Slightly ahead of 64 in order to include some compilation fixes
export CFG_OPENCV_PYTHON_TAGV=64  # Corresponds to 4.5.5
export CFG_CONDA_PYTHON=3.10

# Run the main installation script
"$SCRIPT_DIR/install-opencv-python.sh"
# EOF
