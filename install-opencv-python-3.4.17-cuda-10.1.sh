#!/bin/bash -i
# Install OpenCV python into a conda environment

# Retrieve the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Configuration
export CFG_CUDA_VERSION=10.1
export CFG_OPENCV_PYTHON_TAG=61
export CFG_OPENCV_STRICT=0
export CFG_CONDA_PYTHON=3.9

# Run the main installation script
"$SCRIPT_DIR/install-opencv-python.sh"
# EOF
