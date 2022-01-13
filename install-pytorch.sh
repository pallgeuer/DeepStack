#!/bin/bash -i
# Install PyTorch into a conda environment

# Use bash strict mode
set -euo pipefail

#
# Configuration
#

# Whether to skip installation steps that are not strictly necessary in order to save time
CFG_QUICK=

# Root directory to use for downloading and compiling libraries and storing files in the process of installation
CFG_ROOT_DIR=~/Programs/DeepLearning

# Name and python version to use for the created conda environment
CFG_CONDA_ENV=cuda101
CFG_CONDA_PYTHON=3.9

#
# Installation
#

# Signal that the script is starting
echo "Starting PyTorch installation..."
echo

# Enter the root directory
cd "$CFG_ROOT_DIR"

# Clean up configuration variables
CFG_ROOT_DIR="$(pwd)"

# Install system dependencies
echo "Installing various system dependencies..."
# TODO: sudo apt install BLAH
echo

#
# Stage 1
#

# Stage 1 uninstall
echo "Commands to undo stage 1:"
echo "conda env remove -n $CFG_CONDA_ENV"
echo

# Create conda environment
echo "Creating conda environment..."
set +u
find "$(conda info --base)"/envs -mindepth 1 -maxdepth 1 -type d -printf "%f\n" | grep -Fq "$CFG_CONDA_ENV" || conda create -n "$CFG_CONDA_ENV" python="$CFG_CONDA_PYTHON" anaconda
echo "Activating $CFG_CONDA_ENV conda environment..."
conda activate "$CFG_CONDA_ENV"
set -u
echo

# TODO: Need to manually perform PYTHONPATH suppression on the conda environment!
# TODO: Activating and deactivating the environment should also select the appropriate CUDA installation
# TODO: CONTINUE

#
# Finish
#

# Signal that the script completely finished
echo "Finished PyTorch installation"
echo

# EOF
