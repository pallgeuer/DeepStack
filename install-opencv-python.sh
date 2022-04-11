#!/bin/bash -i
# Install OpenCV python into a conda environment
# CAUTION: Only the OpenCV python bindings will be installed, and the installation will be unusable for linking to via C++ because there are no headers/cmake installed! Use the installation method of OpenCV via the install PyTorch script if you want headers/cmake to be installed!

# Use bash strict mode
set -euo pipefail
unset HISTFILE

# Retrieve the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

#
# Configuration
#

# Whether to stop after a particular stage
CFG_STAGE="${CFG_STAGE:-0}"

# Whether to have faith and auto-answer all prompts
CFG_AUTO_ANSWER="${CFG_AUTO_ANSWER:-1}"

# Root directory to use for downloading and compiling libraries and storing files in the process of installation
CFG_ROOT_DIR="${CFG_ROOT_DIR:-$SCRIPT_DIR}"

# Version, name and parent directory path of the CUDA installation to use
# Example: CFG_CUDA_VERSION=10.2
CFG_CUDA_NAME="${CFG_CUDA_NAME:-cuda-$CFG_CUDA_VERSION}"
CFG_CUDA_LOCATION="${CFG_CUDA_LOCATION:-/usr/local}"

# OpenCV python git tag (tag should be one of these: https://github.com/opencv/opencv-python/tags, click on the tag to see the corresponding OpenCV version)
# Example: CFG_OPENCV_PYTHON_TAG=60
CFG_OPENCV_PYTHON_TAGV="${CFG_OPENCV_PYTHON_TAGV:-$CFG_OPENCV_PYTHON_TAG}"
CFG_OPENCV_CONTRIB="${CFG_OPENCV_CONTRIB:-1}"
CFG_OPENCV_HEADLESS="${CFG_OPENCV_HEADLESS:-0}"

# OpenCV cmake options
CFG_OPENCV_STRICT="${CFG_OPENCV_STRICT:-1}"
CFG_OPENCV_CMAKE="${CFG_OPENCV_CMAKE:-}"

# Name to use for the created conda environment
CFG_CONDA_ENV="${CFG_CONDA_ENV:-opencv-$CFG_OPENCV_PYTHON_TAGV-$CFG_CUDA_NAME}"
CFG_CONDA_CREATE="${CFG_CONDA_CREATE:-1}"  # Set this to anything other than "true" to not attempt environment creation (environment must already exist and be appropriately configured)

# Python version to use for the created conda environment (check compatibility based on python tags: https://pypi.org/project/opencv-python)
# Example: CFG_CONDA_PYTHON=3.9

# Enter the root directory
cd "$CFG_ROOT_DIR"

# Clean up configuration variables
[[ "$CFG_STAGE" -le 0 ]] 2>/dev/null && CFG_STAGE=0
if [[ "$CFG_AUTO_ANSWER" == "1" ]]; then
	CFG_AUTO_YES=-y
else
	CFG_AUTO_ANSWER="0"
	CFG_AUTO_YES=
fi
CFG_ROOT_DIR="$(pwd)"
CFG_CUDA_LOCATION="${CFG_CUDA_LOCATION%/}"
CUDA_INSTALL_DIR="$CFG_CUDA_LOCATION/$CFG_CUDA_NAME"
[[ "$CFG_CONDA_CREATE" != "1" ]] && CFG_CONDA_CREATE="0"
[[ "$CFG_OPENCV_CONTRIB" != "1" ]] && CFG_OPENCV_CONTRIB="0"
[[ "$CFG_OPENCV_HEADLESS" != "0" ]] && CFG_OPENCV_HEADLESS="1"
[[ "$CFG_OPENCV_STRICT" != "1" ]] && CFG_OPENCV_STRICT="0"

# Display the configuration
echo
echo "CFG_STAGE = $CFG_STAGE"
echo "CFG_AUTO_ANSWER = $CFG_AUTO_ANSWER"
echo "CFG_ROOT_DIR = $CFG_ROOT_DIR"
echo "CFG_CUDA_VERSION = $CFG_CUDA_VERSION"
echo "CFG_CUDA_NAME = $CFG_CUDA_NAME"
echo "CFG_CUDA_LOCATION = $CFG_CUDA_LOCATION"
echo "CFG_OPENCV_PYTHON_TAG = $CFG_OPENCV_PYTHON_TAG"
echo "CFG_OPENCV_CONTRIB = $CFG_OPENCV_CONTRIB"
echo "CFG_OPENCV_HEADLESS = $CFG_OPENCV_HEADLESS"
echo "CFG_OPENCV_STRICT = $CFG_OPENCV_STRICT"
echo "CFG_OPENCV_CMAKE = $CFG_OPENCV_CMAKE"
echo "CFG_CONDA_CREATE = $CFG_CONDA_CREATE"
echo "CFG_CONDA_ENV = $CFG_CONDA_ENV"
echo "CFG_CONDA_PYTHON = $CFG_CONDA_PYTHON"
echo
if [[ "$CFG_AUTO_ANSWER" == "0" ]]; then
	read -n 1 -p "Continue [ENTER] "
	echo
fi

#
# Installation
#

# Signal that the script is starting
echo "Starting OpenCV python installation..."
echo

# Initialise uninstaller script
UNINSTALLERS_DIR="$CFG_ROOT_DIR/Uninstallers"
UNINSTALLER_SCRIPT="$UNINSTALLERS_DIR/uninstall-$CFG_CONDA_ENV-opencv-python.sh"
echo "Creating uninstaller script: $UNINSTALLER_SCRIPT"
[[ ! -d "$UNINSTALLERS_DIR" ]] && mkdir "$UNINSTALLERS_DIR"
read -r -d '' UNINSTALLER_HEADER << EOM || true
#!/bin/bash -i
# Uninstall $CFG_CONDA_ENV

# Use bash strict mode
set -xeuo pipefail
unset HISTFILE
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
sudo apt install $CFG_AUTO_YES libnuma-dev
sudo apt install $CFG_AUTO_YES libva-dev libtbb-dev
sudo apt install $CFG_AUTO_YES v4l-utils libv4l-dev
sudo apt install $CFG_AUTO_YES openmpi-bin libopenmpi-dev
sudo apt install $CFG_AUTO_YES libglu1-mesa libglu1-mesa-dev freeglut3-dev libglfw3 libglfw3-dev libgl1-mesa-glx
sudo apt install $CFG_AUTO_YES qt5-default
echo

#
# Stage 1
#

# Variables
ENVS_DIR="$CFG_ROOT_DIR/envs"
ENV_DIR="$ENVS_DIR/$CFG_CONDA_ENV"
OPENCV_PYTHON_GIT_DIR="$ENV_DIR/opencv-python"

# Stage 1 uninstall
read -r -d '' UNINSTALLER_COMMANDS << EOM || true
Commands to undo stage 1:
rm -rf "$OPENCV_PYTHON_GIT_DIR"
rmdir --ignore-fail-on-non-empty '$ENV_DIR' || true
rmdir --ignore-fail-on-non-empty '$ENVS_DIR' || true
EOM
add_uninstall_cmds "# $UNINSTALLER_COMMANDS"
echo "$UNINSTALLER_COMMANDS"
echo

# Ensure the envs directory and subdirectory exists
[[ ! -d "$ENVS_DIR" ]] && mkdir "$ENVS_DIR"
[[ ! -d "$ENV_DIR" ]] && mkdir "$ENV_DIR"

# Clone the OpenCV repositories
echo "Cloning OpenCV python build tag $CFG_OPENCV_PYTHON_TAG..."
if [[ ! -d "$OPENCV_PYTHON_GIT_DIR" ]]; then
	(
		set -x
		cd "$ENV_DIR"
		git clone --recursive -j"$(nproc)" https://github.com/opencv/opencv-python.git opencv-python
		cd "$OPENCV_PYTHON_GIT_DIR"
		git checkout "$CFG_OPENCV_PYTHON_TAG"
		git checkout --recurse-submodules "$CFG_OPENCV_PYTHON_TAG"
		git submodule sync
		git submodule update --init --recursive
		git submodule status
	)
fi
echo

# Stop if stage limit reached
[[ "$CFG_STAGE" -eq 1 ]] && exit 0

#
# Stage 2
#

# Stage 2 uninstall
UNINSTALLER_COMMANDS="Commands to undo stage 2:"$'\n'"set +ux"
[[ "$CFG_CONDA_CREATE" == "1" ]] && UNINSTALLER_COMMANDS+=$'\n'"conda deactivate"$'\n'"conda env remove -n '$CFG_CONDA_ENV'"
UNINSTALLER_COMMANDS+=$'\n'"conda clean -y --all"$'\n'"set -ux"
add_uninstall_cmds "# $UNINSTALLER_COMMANDS"
echo "$UNINSTALLER_COMMANDS"
echo

# Create conda environment
echo "Creating conda environment..."
if [[ "$CFG_CONDA_CREATE" != "1" ]] || find "$(conda info --base)"/envs -mindepth 1 -maxdepth 1 -type d -printf "%f\n" | grep -Fq "$CFG_CONDA_ENV"; then
	echo "Using already-configured conda environment $CFG_CONDA_ENV without installing any further packages"
	CREATED_CONDA_ENV=
else
	echo "If you want an existing conda environment to be used instead, then create and configure the environment and pass its name as CFG_CONDA_ENV and set CFG_CONDA_CREATE=0"
	set +u
	conda create $CFG_AUTO_YES -n "$CFG_CONDA_ENV" python="$CFG_CONDA_PYTHON"
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
	conda config --env --set channel_priority strict
	conda install $CFG_AUTO_YES cython
	conda install $CFG_AUTO_YES ceres-solver cmake ffmpeg freetype gflags glog gstreamer gst-plugins-base gst-plugins-good harfbuzz hdf5 jpeg libdc1394 libiconv libpng libtiff libva libwebp mkl mkl-include ninja numpy openjpeg pkgconfig setuptools six snappy tbb tbb-devel tbb4py tifffile
	conda install $CFG_AUTO_YES --force-reinstall $(conda list -q --no-pip | egrep -v -e '^#' -e '^_' | cut -d' ' -f1 | egrep -v '^(python)$' | tr '\n' ' ')  # Workaround for conda dependency mismanagement...
	CERES_EIGEN_VERSION="$(grep -oP '(?<=set\(CERES_EIGEN_VERSION)\s+[0-9.]+\s*(?=\))' "$CONDA_ENV_DIR/lib/cmake/Ceres/CeresConfig.cmake")"
	CERES_EIGEN_VERSION="${CERES_EIGEN_VERSION// /}"
	if [[ -n "$CERES_EIGEN_VERSION" ]]; then
		conda config --env --set channel_priority flexible
		conda install $CFG_AUTO_YES eigen="$CERES_EIGEN_VERSION"
	else
		echo "Failed to parse Eigen version required by Ceres"
		exit 1
	fi
	conda clean $CFG_AUTO_YES --all
	set -u
	[[ -f "$CONDA_ENV_DIR/etc/conda/activate.d/libblas_mkl_activate.sh" ]] && chmod +x "$CONDA_ENV_DIR/etc/conda/activate.d/libblas_mkl_activate.sh"
	[[ -f "$CONDA_ENV_DIR/etc/conda/deactivate.d/libblas_mkl_deactivate.sh" ]] && chmod +x "$CONDA_ENV_DIR/etc/conda/deactivate.d/libblas_mkl_deactivate.sh"
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

# Stop if stage limit reached
[[ "$CFG_STAGE" -eq 2 ]] && exit 0

#
# Stage 3
#

# Variables
OPENCV_PYTHON_STUB_DIR="$ENV_DIR/opencv-python-stub"

# Stage 3 uninstall
read -r -d '' UNINSTALLER_COMMANDS << EOM || true
Commands to undo stage 3:
set +ux
if conda activate '$CFG_CONDA_ENV'; then INSTALLED_OPENCVS="\$(pip list | grep -e "^opencv-" | cut -d' ' -f1 | tr $'\n' ' ' || true)"; [[ -n "\$INSTALLED_OPENCVS" ]] && pip uninstall -y \$INSTALLED_OPENCVS || true; fi
set -ux
rm -rf '$OPENCV_PYTHON_STUB_DIR' '$OPENCV_PYTHON_GIT_DIR'/*.whl '$OPENCV_PYTHON_GIT_DIR/_skbuild'
EOM
add_uninstall_cmds "# $UNINSTALLER_COMMANDS"
echo "$UNINSTALLER_COMMANDS"
echo

# Build OpenCV
echo "Building OpenCV python build tag $CFG_OPENCV_PYTHON_TAG..."
if find "$OPENCV_PYTHON_GIT_DIR" -maxdepth 1 -type f -name "opencv_*.whl" -exec false {} +; then
	(
		rm -rf "$OPENCV_PYTHON_GIT_DIR"/*.whl
		cd "$OPENCV_PYTHON_GIT_DIR"
		set +u
		conda activate "$CFG_CONDA_ENV"
		set -u
		export CMAKE_PREFIX_PATH="$CONDA_PREFIX"
		export CMAKE_ARGS="-DCMAKE_CXX_STANDARD=14 -DENABLE_CONFIG_VERIFICATION=\"$CFG_OPENCV_STRICT\" -DOPENCV_ENABLE_NONFREE=ON -DENABLE_FAST_MATH=OFF -DWITH_IMGCODEC_HDR=ON -DWITH_IMGCODEC_SUNRASTER=ON -DWITH_IMGCODEC_PXM=ON -DWITH_IMGCODEC_PFM=ON -DWITH_ADE=ON -DWITH_PNG=ON -DWITH_JPEG=ON -DWITH_TIFF=ON -DWITH_WEBP=ON -DWITH_OPENJPEG=ON -DWITH_JASPER=OFF -DWITH_OPENEXR=ON -DBUILD_OPENEXR=ON -DWITH_TESSERACT=OFF -DWITH_V4L=ON -DWITH_FFMPEG=ON -DWITH_GSTREAMER=ON -DWITH_1394=ON -DWITH_OPENGL=ON -DOpenGL_GL_PREFERENCE=LEGACY -DWITH_PTHREADS_PF=ON -DWITH_TBB=ON -DWITH_OPENMP=ON -DWITH_CUDA=ON -DCUDA_GENERATION=Auto -DCUDA_FAST_MATH=OFF -DWITH_CUDNN=ON -DWITH_CUFFT=ON -DWITH_CUBLAS=ON -DWITH_OPENCL=ON -DWITH_OPENCLAMDFFT=OFF -DWITH_OPENCLAMDBLAS=OFF -DWITH_VA=ON -DWITH_VA_INTEL=ON -DWITH_PROTOBUF=ON -DBUILD_PROTOBUF=ON -DPROTOBUF_UPDATE_FILES=OFF -DOPENCV_DNN_CUDA=ON -DOPENCV_DNN_OPENCL=ON -DWITH_EIGEN=ON -DWITH_LAPACK=ON -DWITH_QUIRC=ON"
		[[ "$CFG_OPENCV_HEADLESS" == "0" ]] && CMAKE_ARGS+=" -DWITH_VTK=OFF -DWITH_GTK=OFF -DWITH_QT=ON"
		[[ -n "$CFG_OPENCV_CMAKE" ]] && CMAKE_ARGS+=" $CFG_OPENCV_CMAKE"
		export ENABLE_CONTRIB="$CFG_OPENCV_CONTRIB"
		export ENABLE_HEADLESS="$CFG_OPENCV_HEADLESS"
		export MAKEFLAGS="-j$(nproc)"
		time pip wheel --verbose --use-feature=in-tree-build .
		echo
		echo "Removing build directory..."
		rm -rf "$OPENCV_PYTHON_GIT_DIR/_skbuild"
	)
fi
echo

# Install OpenCV
echo "Installing OpenCV python build tag $CFG_OPENCV_PYTHON_TAG..."
OPENCV_WHEEL="$(find "$OPENCV_PYTHON_GIT_DIR" -maxdepth 1 -type f -name "opencv_*.whl" -print -quit)"
if [[ -z "$OPENCV_WHEEL" ]]; then
	echo "Failed to find output OpenCV wheel"
	exit 1
fi
OPENCV_PACKAGE="$(basename "$OPENCV_WHEEL")"
OPENCV_PACKAGE="${OPENCV_PACKAGE%%-*}"
OPENCV_PACKAGE="${OPENCV_PACKAGE//_/-}"
if ! pip show "$OPENCV_PACKAGE" &>/dev/null; then
	echo "Uninstalling any existing OpenCV from conda environment..."
	INSTALLED_OPENCVS="$(pip list | grep -e "^opencv-" | cut -d' ' -f1 | tr $'\n' ' ' || true)"
	[[ -n "$INSTALLED_OPENCVS" ]] && pip uninstall $CFG_AUTO_YES $INSTALLED_OPENCVS || true
	echo "Installing built OpenCV python wheel..."
	pip install "$OPENCV_WHEEL"
	echo
	echo "Showing installed OpenCV build information..."
	python -c "import cv2; print('Found python OpenCV', cv2.__version__); print(cv2.getBuildInformation())"
fi
echo

# Install OpenCV stub package if required
if [[ "$OPENCV_PACKAGE" != "opencv-python" ]]; then
	OPENCV_VERSION_LONG="$(pip show "$OPENCV_PACKAGE" | grep 'Version: ' | head -n1 | cut -d' ' -f2)"
	if [[ -z "$OPENCV_VERSION_LONG" ]]; then
		echo "Unable to determine installed OpenCV package version"
		exit 1
	fi
	echo "Building OpenCV python stub package for version $OPENCV_VERSION_LONG..."
	[[ ! -d "$OPENCV_PYTHON_STUB_DIR" ]] && mkdir "$OPENCV_PYTHON_STUB_DIR"
	if find "$OPENCV_PYTHON_STUB_DIR" -maxdepth 1 -type f -name "opencv_python-*.whl" -exec false {} +; then
		(
			[[ ! -d "$OPENCV_PYTHON_STUB_DIR/opencv-python" ]] && mkdir "$OPENCV_PYTHON_STUB_DIR/opencv-python"
			cat << EOM > "$OPENCV_PYTHON_STUB_DIR/setup.py"
from setuptools import setup
setup(
	name='opencv-python',
	version='$OPENCV_VERSION_LONG',
	description='Stub package that relies on OpenCV python bindings already being installed by some other means',
	url='https://github.com/skvark/opencv-python',
	author='Philipp Allgeuer',
	license='MIT',
	packages=['opencv-python'],
)
EOM
		cd "$OPENCV_PYTHON_STUB_DIR"
		pip wheel --verbose --use-feature=in-tree-build .
		)
	fi
	echo
	echo "Installing OpenCV python stub package for version $OPENCV_VERSION_LONG..."
	OPENCV_STUB_WHEEL="$(find "$OPENCV_PYTHON_STUB_DIR" -maxdepth 1 -type f -name "opencv_python-*.whl" -print -quit)"
	if [[ -z "$OPENCV_STUB_WHEEL" ]]; then
		echo "Failed to find output OpenCV stub wheel"
		exit 1
	fi
	if ! pip show "opencv-python" &>/dev/null; then
		pip install "$OPENCV_STUB_WHEEL"
	fi
	echo
fi

# Stop if stage limit reached
[[ "$CFG_STAGE" -eq 3 ]] && exit 0

#
# Finish
#

# Signal that the script completely finished
echo "Finished OpenCV python installation into conda env $CFG_CONDA_ENV"
echo

# EOF
