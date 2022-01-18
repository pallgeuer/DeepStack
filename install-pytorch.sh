#!/bin/bash -i
# Install PyTorch into a conda environment
# Alternatively if you're looking into having a Docker build of PyTorch:
#   https://github.com/veritas9872/PyTorch-Universal-Docker-Template  [OLD NAME]
#   https://github.com/veritas9872/Cresset                            [NEW NAME]

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
CFG_CONDA_CREATE="${CFG_CONDA_CREATE:-true}"  # Set this to anything other than "true" to not attempt environment creation (environment must already exist and be appropriately configured)

# Python version to use for the created conda environment (see https://github.com/pytorch/vision#installation for compatibility)
# Example: CFG_CONDA_PYTHON=3.9

# Enter the root directory
cd "$CFG_ROOT_DIR"

# Clean up configuration variables
CFG_ROOT_DIR="$(pwd)"
CFG_CUDA_LOCATION="${CFG_CUDA_LOCATION%/}"
CUDA_INSTALL_DIR="$CFG_CUDA_LOCATION/$CFG_CUDA_NAME"
[[ "$CFG_CONDA_CREATE" != "true" ]] && CFG_CONDA_CREATE="false"

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
echo "CFG_CONDA_CREATE = $CFG_CONDA_CREATE"
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
#!/bin/bash -ix
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
sudo apt install fftw3 fftw3-dev
sudo apt install libnuma-dev
sudo apt install openmpi-bin libopenmpi-dev
sudo apt install protobuf-compiler libprotobuf-dev
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
		set -x
		cd "$MAIN_PYTORCH_DIR"
		git clone --recursive -j"$(nproc)" https://github.com/pytorch/pytorch pytorch
		cd "$PYTORCH_GIT_DIR"
		git checkout "$CFG_PYTORCH_TAG"
		git checkout --recurse-submodules "$CFG_PYTORCH_TAG"
		git submodule sync
		git submodule update --init --recursive
		git submodule status
		[[ -f "$PYTORCH_GIT_DIR/caffe2/utils/threadpool/pthreadpool-cpp.cc" ]] && sed -i 's/TORCH_WARN("Leaking Caffe2 thread-pool after fork.");/;/g' "$PYTORCH_GIT_DIR/caffe2/utils/threadpool/pthreadpool-cpp.cc"
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
UNINSTALLER_COMMANDS="Commands to undo stage 2:"$'\n'"set +ux"
[[ "$CFG_CONDA_CREATE" == "true" ]] && UNINSTALLER_COMMANDS+=$'\n'"conda deactivate"$'\n'"conda env remove -n '$CFG_CONDA_ENV'"
UNINSTALLER_COMMANDS+=$'\n'"conda clean --all"$'\n'"set -ux"
add_uninstall_cmds "# $UNINSTALLER_COMMANDS"
echo "$UNINSTALLER_COMMANDS"
echo

# Create conda environment
echo "Creating conda environment..."
if [[ "$CFG_CONDA_CREATE" != "true" ]] || find "$(conda info --base)"/envs -mindepth 1 -maxdepth 1 -type d -printf "%f\n" | grep -Fq "$CFG_CONDA_ENV"; then
	echo "Using already-configured conda environment $CFG_CONDA_ENV without installing any further packages"
	CREATED_CONDA_ENV=
else
	echo "If you want an existing conda environment to be used instead, then create and configure the environment and pass its name as CFG_CONDA_ENV and set CFG_CONDA_CREATE=false"
	set +u
	conda create -n "$CFG_CONDA_ENV" python="$CFG_CONDA_PYTHON"
	set -u
	CREATED_CONDA_ENV=true
fi
echo

# Configure conda activation scripts
CONDA_ENV_DIR="$(readlink -e "$(dirname "$CONDA_EXE")/../envs/$CFG_CONDA_ENV")"
if [[ ! -d "$CONDA_ENV_DIR" ]]; then
	echo "Not a directory: $CONDA_ENV_DIR"
	exit 1
fi
if [[ -n "$CREATED_CONDA_ENV" ]]; then
echo "Configuring conda environment activation scripts..."
mkdir -p "$CONDA_ENV_DIR/etc/conda/activate.d"
mkdir -p "$CONDA_ENV_DIR/etc/conda/deactivate.d"
cat << 'EOM' > "$CONDA_ENV_DIR/etc/conda/activate.d/pythonpath.sh"
#!/bin/sh
# The environment name is available under $CONDA_DEFAULT_ENV
if [ -n "$PYTHONPATH" ]; then
	export SUPPRESSED_PYTHONPATH="$PYTHONPATH"
	unset PYTHONPATH
fi
# EOF
EOM
cat << 'EOM' > "$CONDA_ENV_DIR/etc/conda/deactivate.d/pythonpath.sh"
#!/bin/sh
# The environment name is available under $CONDA_DEFAULT_ENV
if [ -n "$SUPPRESSED_PYTHONPATH" ]; then
	export PYTHONPATH="$SUPPRESSED_PYTHONPATH"
	unset SUPPRESSED_PYTHONPATH
fi
# EOF
EOM
cat << EOM > "$CONDA_ENV_DIR/etc/conda/activate.d/env_vars.sh"
#!/bin/sh
source '$CUDA_INSTALL_DIR/add_path.sh'
# EOF
EOM
cat << EOM > "$CONDA_ENV_DIR/etc/conda/deactivate.d/env_vars.sh"
#!/bin/sh
source '$CUDA_INSTALL_DIR/remove_path.sh'
# EOF
EOM
chmod +x "$CONDA_ENV_DIR/etc/conda/activate.d/pythonpath.sh" "$CONDA_ENV_DIR/etc/conda/deactivate.d/pythonpath.sh" "$CONDA_ENV_DIR/etc/conda/activate.d/env_vars.sh" "$CONDA_ENV_DIR/etc/conda/deactivate.d/env_vars.sh"
echo
fi

# Activate the conda environment
echo "Activating $CFG_CONDA_ENV conda environment..."
set +u
conda activate "$CFG_CONDA_ENV"
set -u
echo

# Install conda packages
if [[ -n "$CREATED_CONDA_ENV" ]]; then
	echo "Installing conda packages..."
	set +u
	conda config --env --append channels conda-forge
	conda config --env --append channels pytorch
	conda config --env --set channel_priority strict
	conda install ceres-solver cmake ffmpeg freetype gflags glog gstreamer gst-plugins-base gst-plugins-good harfbuzz hdf5 jpeg libdc1394 libiconv libpng libtiff libva libwebp mkl mkl-include numpy openjpeg pkgconfig setuptools six snappy tbb tbb-devel tbb4py tifffile  # For OpenCV
	conda install astunparse cffi cmake future mkl mkl-include ninja numpy pillow pkgconfig pybind11 pyyaml requests setuptools six typing typing_extensions libjpeg-turbo libpng magma-cuda"$(cut -d. -f'1 2' <<< "$CFG_CUDA_VERSION" | tr -d .)"  # For PyTorch
	conda install decorator appdirs mako numpy six  # For pip packages
	conda install --force-reinstall $(conda list -q --no-pip | egrep -v -e '^#' -e '^_' | cut -d' ' -f1 | egrep -v '^(python)$' | tr '\n' ' ')  # Workaround for conda dependency mismanagement...
	CERES_EIGEN_VERSION="$(grep -oP '(?<=set\(CERES_EIGEN_VERSION)\s+[0-9.]+\s*(?=\))' "$CONDA_ENV_DIR/lib/cmake/Ceres/CeresConfig.cmake")"
	CERES_EIGEN_VERSION="${CERES_EIGEN_VERSION// /}"
	if [[ -n "$CERES_EIGEN_VERSION" ]]; then
		conda config --env --set channel_priority flexible
		conda install eigen="$CERES_EIGEN_VERSION"
	else
		echo "Failed to parse Eigen version required by Ceres"
		exit 1
	fi
	conda clean --all
	set -u
	[[ -f "$CONDA_ENV_DIR/etc/conda/activate.d/libblas_mkl_activate.sh" ]] && chmod +x "$CONDA_ENV_DIR/etc/conda/activate.d/libblas_mkl_activate.sh"
	[[ -f "$CONDA_ENV_DIR/etc/conda/deactivate.d/libblas_mkl_deactivate.sh" ]] && chmod +x "$CONDA_ENV_DIR/etc/conda/deactivate.d/libblas_mkl_deactivate.sh"
	echo
	echo "Installing pip packages..."
	pip install --no-deps --no-cache-dir pycuda pytools
	echo
	echo "Performing pip check..."
	pip check
	echo
fi

# Reactivate the conda environment
echo "Reactivating $CFG_CONDA_ENV conda environment..."
set +u
conda deactivate
conda activate "$CFG_CONDA_ENV"
set -u
echo

#
# Stage 3
#

# Variables
OPENCV_BUILD_DIR="$OPENCV_GIT_DIR/build"

# Stage 3 uninstall
read -r -d '' UNINSTALLER_COMMANDS << EOM || true
Commands to undo stage 3:
if [[ -d '$OPENCV_BUILD_DIR' ]]; then ( cd '$OPENCV_BUILD_DIR'; make uninstall; make clean; ) elif [[ -f '$OPENCV_GIT_DIR/install_manifest.txt' ]]; then echo 'You will need to check the install manifest and uninstall manually: $OPENCV_GIT_DIR/install_manifest.txt'; fi
rm -rf '$OPENCV_BUILD_DIR' '$OPENCV_GIT_DIR/.cache'
EOM
add_uninstall_cmds "# $UNINSTALLER_COMMANDS"
echo "$UNINSTALLER_COMMANDS"
echo

# Build OpenCV
echo "Building OpenCV $CFG_OPENCV_VERSION..."
if [[ ! -f "$CONDA_PREFIX/bin/opencv_version" ]]; then
	(
		[[ ! -d "$OPENCV_BUILD_DIR" ]] && mkdir "$OPENCV_BUILD_DIR"
		rm -rf "$OPENCV_BUILD_DIR"/*
		cd "$OPENCV_BUILD_DIR"
		set +u
		conda activate "$CFG_CONDA_ENV"
		set -u
		export CMAKE_PREFIX_PATH="$CONDA_PREFIX"
		cmake -DCMAKE_INSTALL_PREFIX="$CONDA_PREFIX" -DOPENCV_EXTRA_MODULES_PATH=../../opencv_contrib/modules -DCMAKE_BUILD_TYPE=Release -DCMAKE_CXX_STANDARD=14 -DBUILD_SHARED_LIBS=ON -DENABLE_CONFIG_VERIFICATION=ON -DOPENCV_ENABLE_NONFREE=ON -DENABLE_FAST_MATH=OFF -DBUILD_TESTS=OFF -DBUILD_PERF_TESTS=OFF -DBUILD_EXAMPLES=OFF -DBUILD_DOCS=OFF -DBUILD_opencv_apps=ON -DPYTHON_DEFAULT_EXECUTABLE="$CONDA_PREFIX/bin/python" -DPYTHON3_EXECUTABLE="$CONDA_PREFIX/bin/python" -DBUILD_opencv_python2=OFF -DBUILD_opencv_python3=ON -DBUILD_opencv_java=OFF -DWITH_MATLAB=OFF -DWITH_IMGCODEC_HDR=ON -DWITH_IMGCODEC_SUNRASTER=ON -DWITH_IMGCODEC_PXM=ON -DWITH_IMGCODEC_PFM=ON -DWITH_ADE=ON -DWITH_PNG=ON -DWITH_JPEG=ON -DWITH_TIFF=ON -DWITH_WEBP=ON -DWITH_OPENJPEG=ON -DWITH_JASPER=OFF -DWITH_OPENEXR=ON -DBUILD_OPENEXR=ON -DWITH_TESSERACT=OFF -DWITH_V4L=OFF -DWITH_FFMPEG=ON -DWITH_GSTREAMER=ON -DWITH_1394=ON -DWITH_OPENGL=ON -DOpenGL_GL_PREFERENCE=LEGACY -DWITH_VTK=OFF -DWITH_GTK=OFF -DWITH_QT=ON -DWITH_PTHREADS_PF=ON -DWITH_TBB=ON -DWITH_OPENMP=ON -DWITH_CUDA=ON -DCUDA_GENERATION=Auto -DCUDA_FAST_MATH=OFF -DWITH_CUDNN=ON -DWITH_CUFFT=ON -DWITH_CUBLAS=ON -DWITH_OPENCL=ON -DWITH_OPENCLAMDFFT=OFF -DWITH_OPENCLAMDBLAS=OFF -DWITH_VA=ON -DWITH_VA_INTEL=ON -DWITH_PROTOBUF=ON -DBUILD_PROTOBUF=ON -DPROTOBUF_UPDATE_FILES=OFF -DOPENCV_DNN_CUDA=ON -DOPENCV_DNN_OPENCL=ON -DWITH_EIGEN=ON -DWITH_LAPACK=ON -DWITH_QUIRC=ON ..
		time make -j"$(nproc)"
		echo
		echo "Checking which external libraries the build products dynamically link to..."
		find "$OPENCV_BUILD_DIR" -type f -executable -exec ldd {} \; 2>/dev/null | grep -vF "$OPENCV_BUILD_DIR/" | grep -vF "$CONDA_ENV_DIR/" | grep -vF "$CUDA_INSTALL_DIR/" | sed 's/ (0x[0-9a-fx]\+)//g' | sort | uniq
		echo
		echo "Installing OpenCV into conda environment..."
		make install
		cp "$OPENCV_BUILD_DIR/install_manifest.txt" "$OPENCV_GIT_DIR/install_manifest.txt"
		echo
		echo "Running opencv_version script and showing build information..."
		"$OPENCV_BUILD_DIR/bin/opencv_version"
		python -c "import cv2; print('Found Python OpenCV', cv2.__version__); print(cv2.getBuildInformation())"
		echo "Removing build products..."
		rm -rf "$OPENCV_BUILD_DIR" "$OPENCV_GIT_DIR/.cache"
	)
fi
echo

#
# Stage 4
#

# Variables
PYTORCH_BUILD_DIR="$PYTORCH_GIT_DIR/build"

# Stage 4 uninstall
read -r -d '' UNINSTALLER_COMMANDS << EOM || true
Commands to undo stage 4:
set +ux
conda activate '$CFG_CONDA_ENV' && ( pip uninstall torch || true; cd '$PYTORCH_GIT_DIR' && python setup.py clean || true; )
set -ux
rm -rf '$PYTORCH_BUILD_DIR' '$PYTORCH_GIT_DIR/torch.egg-info'
EOM
add_uninstall_cmds "# $UNINSTALLER_COMMANDS"
echo "$UNINSTALLER_COMMANDS"
echo

# Build PyTorch
echo "Building PyTorch $CFG_PYTORCH_VERSION..."
if find "$CONDA_ENV_DIR/lib" -type d -path "*/lib/python*/site-packages/torch" -exec false {} +; then
	(
		[[ ! -d "$PYTORCH_BUILD_DIR" ]] && mkdir "$PYTORCH_BUILD_DIR"
		rm -rf "$PYTORCH_BUILD_DIR"/*
		cd "$PYTORCH_GIT_DIR"
		set +u
		conda activate "$CFG_CONDA_ENV"
		set -u
		export CMAKE_PREFIX_PATH="$CONDA_PREFIX"
		export BUILD_BINARY=ON BUILD_TEST=OFF BUILD_DOCS=OFF BUILD_SHARED_LIBS=ON BUILD_CUSTOM_PROTOBUF=ON
		export USE_CUDNN=ON USE_FFMPEG=ON USE_GFLAGS=OFF USE_GLOG=OFF USE_OPENCV=ON
		while ! time python setup.py build; do
			response=
			echo
			echo "Known reasons for a required build restart:"
			echo " - PyTorch 1.10 introduced 'fatal error: ATen/core/TensorBody.h: No such file or directory' due to a build target ordering/dependency problem"
			echo
			read -p "Try build again (y/N)? " response 2>&1
			response="${response,,}"
			[[ "$response" != "y" ]] && exit 1
			echo
		done
		echo
		echo "Checking which external libraries the build products dynamically link to..."
		find "$PYTORCH_BUILD_DIR" -type f -executable -exec ldd {} \; 2>/dev/null | grep -vF "$PYTORCH_BUILD_DIR/" | grep -vF "$CONDA_ENV_DIR/" | grep -vF "$CUDA_INSTALL_DIR/" | sed 's/ (0x[0-9a-fx]\+)//g' | sort | uniq
		echo
		echo "Installing PyTorch into conda environment..."
		pip uninstall torch || true
		python setup.py install
		echo
		echo "Checking PyTorch is available in python..."
		cd "$MAIN_PYTORCH_DIR"
		python - << EOM
import torch
print("Number of devices:", torch.cuda.device_count())
print("Current device number:", torch.cuda.current_device())
print("Current device:", torch.cuda.device(torch.cuda.current_device()))
print("Device name:", torch.cuda.get_device_name(torch.cuda.current_device()))
print("CUDA available:", torch.cuda.is_available())
import pprint
pprint.pprint({
	'version': torch.version.__version__,
	'commit': torch.version.git_version,
	'debug': torch.version.debug,
	'compiled_with': {'cuda': torch.version.cuda, 'cudnn': torch.backends.cudnn.version(), 'nccl': torch.cuda.nccl.version()},
	'backends': {'cuDNN': torch.backends.cudnn.is_available(), 'OpenMP': torch.backends.openmp.is_available(), 'MKL': torch.backends.mkl.is_available(), 'MKL-DNN': torch.backends.mkldnn.is_available()}
})
print(torch.rand(5, 3))
EOM
		echo
		echo "Removing build directory..."
		rm -rf "$PYTORCH_BUILD_DIR"
	)
fi
echo

#
# Stage 5
#

# Variables
TORCHVISION_BUILD_DIR="$TORCHVISION_GIT_DIR/build"

# Stage 5 uninstall
read -r -d '' UNINSTALLER_COMMANDS << EOM || true
Commands to undo stage 5:
set +ux
conda activate '$CFG_CONDA_ENV' && ( pip uninstall torchvision || true; cd '$TORCHVISION_GIT_DIR' && python setup.py clean || true; )
set -ux
rm -rf '$TORCHVISION_BUILD_DIR'
EOM
add_uninstall_cmds "# $UNINSTALLER_COMMANDS"
echo "$UNINSTALLER_COMMANDS"
echo

# Build Torchvision
echo "Building Torchvision $CFG_TORCHVISION_VERSION..."
if find "$CONDA_ENV_DIR/lib" -type d -path "*/lib/python*/site-packages/torchvision-*.egg" -exec false {} +; then
	(
		[[ ! -d "$TORCHVISION_BUILD_DIR" ]] && mkdir "$TORCHVISION_BUILD_DIR"
		rm -rf "$TORCHVISION_BUILD_DIR"/*
		cd "$TORCHVISION_GIT_DIR"
		set +u
		conda activate "$CFG_CONDA_ENV"
		set -u
		export CMAKE_PREFIX_PATH="$CONDA_PREFIX"
		export FORCE_CUDA=ON
		while ! time python setup.py build; do
			response=
			echo
			read -p "Try build again (y/N)? " response 2>&1
			response="${response,,}"
			[[ "$response" != "y" ]] && exit 1
			echo
		done
		echo
		echo "Checking which external libraries the build products dynamically link to..."
		find "$TORCHVISION_BUILD_DIR" -type f -executable -exec ldd {} \; 2>/dev/null | grep -vF "$TORCHVISION_BUILD_DIR/" | grep -vF "$CONDA_ENV_DIR/" | grep -vF "$CUDA_INSTALL_DIR/" | sed 's/ (0x[0-9a-fx]\+)//g' | sort | uniq
		echo
		echo "Installing Torchvision into conda environment..."
		pip uninstall torchvision || true
		python setup.py install
		echo
		echo "Removing build directory..."
		rm -rf "$TORCHVISION_BUILD_DIR"
	)
fi
echo

#
# Finish
#

# Signal that the script completely finished
echo "Finished PyTorch installation into conda env $CFG_CONDA_ENV"
echo

# EOF