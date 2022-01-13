#!/bin/bash -i
# Install PyTorch into a conda environment

# Use bash strict mode
set -euo pipefail

# Retrieve the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

#
# Configuration
#

# Whether to skip installation steps that are not strictly necessary in order to save time
CFG_QUICK="${CFG_QUICK:-}"

# Root directory to use for downloading and compiling libraries and storing files in the process of installation
CFG_ROOT_DIR="${CFG_ROOT_DIR:-$SCRIPT_DIR}"

# Version, name and parent directory path of the CUDA installation to use
# Example: CFG_CUDA_VERSION=10.2
CFG_CUDA_NAME="${CFG_CUDA_NAME:-cuda-$CFG_CUDA_VERSION}"
CFG_CUDA_LOCATION="${CFG_CUDA_LOCATION:-/usr/local}"

# PyTorch git tag, version and name to install (tag should be one of these: https://github.com/pytorch/pytorch/tags)
# Example: CFG_PYTORCH_TAG=v1.10.1
CFG_PYTORCH_VERSION="${CFG_PYTORCH_VERSION:-${CFG_PYTORCH_TAG#v}}"
CFG_PYTORCH_NAME="${CFG_PYTORCH_NAME:-pytorch-$CFG_PYTORCH_VERSION}"

# Torchvision git tag and version (see https://github.com/pytorch/vision#installation for compatibility, tag should be one of these: https://github.com/pytorch/vision/tags)
# Example: CFG_TORCHVISION_TAG=v0.11.2
CFG_TORCHVISION_VERSION="${CFG_TORCHVISION_VERSION:-${CFG_TORCHVISION_TAG#v}}"

# OpenCV git tag and version (tag should be one of these: https://github.com/opencv/opencv/tags)
# Example: CFG_OPENCV_TAG=4.5.4
CFG_OPENCV_VERSION="${CFG_OPENCV_VERSION:-$CFG_OPENCV_TAG}"

# Name to use for the created conda environment
CFG_CONDA_ENV="${CFG_CONDA_ENV:-$CFG_CUDA_NAME-$CFG_PYTORCH_NAME}"

# Python version to use for the created conda environment (see https://github.com/pytorch/vision#installation for compatibility)
# Example: CFG_CONDA_PYTHON=3.9

# Enter the root directory
cd "$CFG_ROOT_DIR"

# Clean up configuration variables
CFG_ROOT_DIR="$(pwd)"
CFG_CUDA_LOCATION="${CFG_CUDA_LOCATION%/}"

# Display the configuration
echo
echo "CFG_QUICK = $CFG_QUICK"
echo "CFG_ROOT_DIR = $CFG_ROOT_DIR"
echo "CFG_CUDA_VERSION = $CFG_CUDA_VERSION"
echo "CFG_CUDA_NAME = $CFG_CUDA_NAME"
echo "CFG_CUDA_LOCATION = $CFG_CUDA_LOCATION"
echo "CFG_PYTORCH_TAG = $CFG_PYTORCH_TAG"
echo "CFG_PYTORCH_VERSION = $CFG_PYTORCH_VERSION"
echo "CFG_PYTORCH_NAME = $CFG_PYTORCH_NAME"
echo "CFG_TORCHVISION_TAG = $CFG_TORCHVISION_TAG"
echo "CFG_TORCHVISION_VERSION = $CFG_TORCHVISION_VERSION"
echo "CFG_OPENCV_TAG = $CFG_OPENCV_TAG"
echo "CFG_OPENCV_VERSION = $CFG_OPENCV_VERSION"
echo "CFG_CONDA_ENV = $CFG_CONDA_ENV"
echo "CFG_CONDA_PYTHON = $CFG_CONDA_PYTHON"
echo
read -n 1 -p "Continue [ENTER] "
echo

#
# Installation
#

# Signal that the script is starting
echo "Starting PyTorch installation..."
echo

# Initialise uninstaller script
UNINSTALLERS_DIR="$CFG_ROOT_DIR/Uninstallers"
UNINSTALLER_SCRIPT="$UNINSTALLERS_DIR/uninstall-$CFG_CONDA_ENV.sh"
echo "Creating uninstaller script: $UNINSTALLER_SCRIPT"
[[ ! -d "$UNINSTALLERS_DIR" ]] && mkdir "$UNINSTALLERS_DIR"
read -r -d '' UNINSTALLER_HEADER << EOM || true
#!/bin/bash -x
# Uninstall $CFG_CONDA_ENV

# Use bash strict mode
set -euo pipefail
EOM
read -r -d '' UNINSTALLER_CONTENTS << EOM || true
# Remove this uninstaller script
rm -rf '$UNINSTALLER_SCRIPT'
rmdir --ignore-fail-on-non-empty '$UNINSTALLERS_DIR' || true
# EOF
EOM
UNINSTALLER_CONTENTS=$'\n'"$UNINSTALLER_CONTENTS"
echo "$UNINSTALLER_HEADER"$'\n'"$UNINSTALLER_CONTENTS" > "$UNINSTALLER_SCRIPT"
chmod +x "$UNINSTALLER_SCRIPT"
function add_uninstall_cmds()
{
	UNINSTALLER_CONTENTS=$'\n'"$1"$'\n'"$UNINSTALLER_CONTENTS"
	echo "$UNINSTALLER_HEADER"$'\n'"$UNINSTALLER_CONTENTS" > "$UNINSTALLER_SCRIPT"
}
echo

# Install system dependencies
echo "Installing various system dependencies..."
# TODO: sudo apt install BLAH
echo

#
# Stage 1
#

# Variables
MAIN_CUDA_DIR="$CFG_ROOT_DIR/CUDA"
LOCAL_CUDA_DIR="$MAIN_CUDA_DIR/$CFG_CUDA_NAME"
MAIN_PYTORCH_DIR="$LOCAL_CUDA_DIR/$CFG_PYTORCH_NAME"
PYTORCH_GIT_DIR="$MAIN_PYTORCH_DIR/pytorch"
TORCHVISION_GIT_DIR="$MAIN_PYTORCH_DIR/torchvision"
OPENCV_GIT_DIR="$MAIN_PYTORCH_DIR/opencv"
OPENCV_CONTRIB_GIT_DIR="$MAIN_PYTORCH_DIR/opencv_contrib"

# Stage 1 uninstall
read -r -d '' UNINSTALLER_COMMANDS << EOM || true
Commands to undo stage 1:
rm -rf '$MAIN_PYTORCH_DIR'
EOM
add_uninstall_cmds "# $UNINSTALLER_COMMANDS"
echo "$UNINSTALLER_COMMANDS"
echo

# Ensure the main PyTorch directory exists
[[ ! -d "$MAIN_PYTORCH_DIR" ]] && mkdir "$MAIN_PYTORCH_DIR"

# Clone the PyTorch repository
echo "Cloning PyTorch $CFG_PYTORCH_VERSION..."
if [[ ! -d "$PYTORCH_GIT_DIR" ]]; then
	(
		cd "$MAIN_PYTORCH_DIR"
		git clone --recursive -j"$(nproc)" https://github.com/pytorch/pytorch pytorch
		cd "$PYTORCH_GIT_DIR"
		git checkout --recurse-submodules "$CFG_PYTORCH_TAG"
		git submodule sync
		git submodule update --init --recursive
		git submodule status
		# TODO: Fix bad things about the PyTorch repo
	)
fi
echo

# Clone the torchvision repository
echo "Cloning Torchvision $CFG_TORCHVISION_VERSION..."
if [[ ! -d "$TORCHVISION_GIT_DIR" ]]; then
	(
		cd "$MAIN_PYTORCH_DIR"
		git clone https://github.com/pytorch/vision.git torchvision
		cd "$TORCHVISION_GIT_DIR"
		git checkout "$CFG_TORCHVISION_TAG"
	)
fi
echo

# Clone the OpenCV repositories
echo "Cloning OpenCV $CFG_OPENCV_VERSION..."
if [[ ! -d "$OPENCV_GIT_DIR" ]]; then
	(
		cd "$MAIN_PYTORCH_DIR"
		git clone https://github.com/opencv/opencv opencv
		git clone https://github.com/opencv/opencv_contrib opencv_contrib
		cd "$OPENCV_GIT_DIR"
		git checkout "$CFG_OPENCV_TAG"
		cd "$OPENCV_CONTRIB_GIT_DIR"
		git checkout "$CFG_OPENCV_TAG"
	)
fi
echo

#
# Stage 2
#

# Stage 2 uninstall
read -r -d '' UNINSTALLER_COMMANDS << EOM || true
Commands to undo stage 3:
conda env remove -n '$CFG_CONDA_ENV'
conda clean --all
EOM
add_uninstall_cmds "# $UNINSTALLER_COMMANDS"
echo "$UNINSTALLER_COMMANDS"
echo

# Create conda environment
echo "Creating conda environment..."
set +u
find "$(conda info --base)"/envs -mindepth 1 -maxdepth 1 -type d -printf "%f\n" | grep -Fq "$CFG_CONDA_ENV" || conda create -n "$CFG_CONDA_ENV" python="$CFG_CONDA_PYTHON"
echo "Activating $CFG_CONDA_ENV conda environment..."
conda activate "$CFG_CONDA_ENV"
set -u
echo

# TODO: Program that the GCC version specification is a MAX only if the GCC version that would otherwise be chosen is higher!!!! Then go through and specify the max GCC version for all the CUDA install scripts

# TODO: Do NOT make the environment anaconda-based to avoid bloat...
# TODO: Set up the conda environment with all the packages it will need for all the remaining stages
# TODO: Recall that you shouldn't install libprotobuf prior to OpenCV compilation in case you need to install that at all

#
# Stage 3
#

# TODO: Make and install OpenCV (no need to be independent, think RPATH)

#
# Stage 4
#

# TODO: Make and install PyTorch (build protobuf)

#
# Stage 5
#

# TODO: Make and install Torchvision (verify that this doesn't end up using a system protobuf version)










exit 1  # TODO: TEMP

# Stage 1 uninstall
echo "Commands to undo stage 1:"
echo "conda env remove -n $CFG_CONDA_ENV"
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
