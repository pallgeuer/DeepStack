#!/bin/bash -i
# Install OpenCV python into a conda environment
# CAUTION: Only the OpenCV python bindings will be installed, and the installation will be unusable for linking to via C++ because there are no headers/cmake installed! Use the installation method of OpenCV via the install PyTorch script if you want headers/cmake to be installed!

# Ensure script is being run and not sourced
if [[ "${BASH_SOURCE[0]}" != "$0" ]]; then
	echo "Please run the ${BASH_SOURCE[0]} script instead of sourcing it!"
	return 1
fi

# Use bash strict mode
set -euo pipefail
unset HISTFILE

# Retrieve the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Retrieve the calling command line
PARENT_CMDLINE="$(ps -o args= "$PPID" | head -c -1 | tr '\n' ' ')"
SUPPLIED_CFGS=
while IFS= read -r ENV_KEY_VALUE; do
	SUPPLIED_CFGS+=$'\n'"#   $ENV_KEY_VALUE"
done < <(env | egrep '^CFG_' | sort)

#
# Configuration
#

# Whether to stop after a particular stage
CFG_STAGE="${CFG_STAGE:-0}"

# Whether to have faith and auto-answer all prompts
CFG_AUTO_ANSWER="${CFG_AUTO_ANSWER:-1}"

# Whether to allow/execute commands that require sudo
CFG_ALLOW_SUDO="${CFG_ALLOW_SUDO:-1}"

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
CFG_OPENCV_STRICT="${CFG_OPENCV_STRICT:-0}"
CFG_OPENCV_CMAKE="${CFG_OPENCV_CMAKE:-}"

# Name to use for the created conda environment
CFG_CONDA_ENV="${CFG_CONDA_ENV:-opencv-$CFG_OPENCV_PYTHON_TAGV-$CFG_CUDA_NAME}"
CFG_CONDA_CREATE="${CFG_CONDA_CREATE:-1}"  # Set this to anything other than 1 to not attempt environment creation (environment must already exist and be appropriately configured)
CFG_CONDA_LOAD="${CFG_CONDA_LOAD:-}"  # If the path to a conda yml/txt file is specified, create an environment based on this file instead of manually installing packages
CFG_CONDA_SAVE="${CFG_CONDA_SAVE:-0}"  # Set this to 1 in order to save the base conda environment specifications to yml/txt files in the 'conda' subdirectory

# Python version to use for the created conda environment (check compatibility based on python tags: https://pypi.org/project/opencv-python)
# Example: CFG_CONDA_PYTHON=3.9

# Whether to clean (post-installation) the local working directory (0 = Do not clean, 1 = Clean build products, 2 = Clean everything) and conda cache (conda clean command, also affects uninstaller)
CFG_CLEAN_WORKDIR="${CFG_CLEAN_WORKDIR:-2}"
CFG_CLEAN_CONDA="${CFG_CLEAN_CONDA:-1}"

# Enter the root directory
cd "$CFG_ROOT_DIR"

# Clean up configuration variables
[[ "$CFG_STAGE" -eq 0 ]] || [[ "$CFG_STAGE" -lt -1 ]] && CFG_STAGE=0
if [[ "$CFG_AUTO_ANSWER" == "1" ]]; then
	CFG_AUTO_YES=-y
else
	CFG_AUTO_ANSWER="0"
	CFG_AUTO_YES=
fi
[[ "$CFG_ALLOW_SUDO" != "1" ]] && CFG_ALLOW_SUDO="0"
CFG_ROOT_DIR="$(pwd)"
CFG_CUDA_LOCATION="${CFG_CUDA_LOCATION%/}"
CUDA_INSTALL_DIR="$CFG_CUDA_LOCATION/$CFG_CUDA_NAME"
[[ "$CFG_CONDA_CREATE" != "1" ]] && CFG_CONDA_CREATE="0"
[[ "$CFG_CONDA_SAVE" != "0" ]] && CFG_CONDA_SAVE="1"
[[ "$CFG_OPENCV_CONTRIB" != "1" ]] && CFG_OPENCV_CONTRIB="0"
[[ "$CFG_OPENCV_HEADLESS" != "0" ]] && CFG_OPENCV_HEADLESS="1"
[[ "$CFG_OPENCV_STRICT" != "1" ]] && CFG_OPENCV_STRICT="0"
[[ "$CFG_CLEAN_WORKDIR" != "2" ]] && [[ "$CFG_CLEAN_WORKDIR" != "1" ]] && CFG_CLEAN_WORKDIR="0"
[[ "$CFG_CLEAN_CONDA" != "1" ]] && CFG_CLEAN_CONDA="0"

# Display the configuration
echo
echo "CFG_STAGE = $CFG_STAGE"
echo "CFG_AUTO_ANSWER = $CFG_AUTO_ANSWER"
echo "CFG_ALLOW_SUDO = $CFG_ALLOW_SUDO"
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
echo "CFG_CONDA_LOAD = $CFG_CONDA_LOAD"
echo "CFG_CONDA_SAVE = $CFG_CONDA_SAVE"
echo "CFG_CONDA_ENV = $CFG_CONDA_ENV"
echo "CFG_CONDA_PYTHON = $CFG_CONDA_PYTHON"
echo "CFG_CLEAN_WORKDIR = $CFG_CLEAN_WORKDIR"
echo "CFG_CLEAN_CONDA = $CFG_CLEAN_CONDA"
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

# Install system dependencies
echo "Installing various system dependencies..."
if [[ "$CFG_ALLOW_SUDO" == "1" ]]; then
	sudo apt install $CFG_AUTO_YES libnuma-dev
	sudo apt install $CFG_AUTO_YES libva-dev libtbb-dev
	sudo apt install $CFG_AUTO_YES v4l-utils libv4l-dev
	sudo apt install $CFG_AUTO_YES openmpi-bin libopenmpi-dev
	sudo apt install $CFG_AUTO_YES libglu1-mesa libglu1-mesa-dev freeglut3-dev libglfw3 libglfw3-dev libgl1-mesa-glx
	sudo apt install $CFG_AUTO_YES qtbase5-dev qtchooser qt5-qmake qtbase5-dev-tools
fi
echo

# Stop if stage limit reached
[[ "$CFG_STAGE" -eq -1 ]] && exit 0

# Initialise uninstaller script
UNINSTALLERS_DIR="$CFG_ROOT_DIR/Uninstallers"
UNINSTALLER_SCRIPT="$UNINSTALLERS_DIR/uninstall-$CFG_CONDA_ENV-opencv-python.sh"
echo "Creating uninstaller script: $UNINSTALLER_SCRIPT"
[[ ! -d "$UNINSTALLERS_DIR" ]] && mkdir "$UNINSTALLERS_DIR"
read -r -d '' UNINSTALLER_HEADER << EOM || true
#!/bin/bash -i
# Uninstall $CFG_CONDA_ENV
# Automatically generated using: $PARENT_CMDLINE$SUPPLIED_CFGS

# Use bash strict mode
set -xeuo pipefail
unset HISTFILE

# Process environment variables
KEEP_STAGE="\${KEEP_STAGE:-0}"
[[ "\$KEEP_STAGE" -le 0 ]] 2>/dev/null && KEEP_STAGE=0
EOM
read -r -d '' UNINSTALLER_CONTENTS << EOM || true
# Remove this uninstaller script
rm -rf '$UNINSTALLER_SCRIPT'
rmdir --ignore-fail-on-non-empty '$UNINSTALLERS_DIR' 2>/dev/null || true
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

#
# Stage 1
#

# Variables
ENVS_DIR="$CFG_ROOT_DIR/envs"
ENV_DIR="$ENVS_DIR/$CFG_CONDA_ENV"
OPENCV_PYTHON_GIT_DIR="$ENV_DIR/opencv-python"
OPENCV_PYTHON_COMPILED="$ENV_DIR/opencv-python-compiled"
OPENCV_GIT_DIR="$OPENCV_PYTHON_GIT_DIR/opencv"

# Stage 1 uninstall
read -r -d '' UNINSTALLER_COMMANDS << EOM || true
Commands to undo stage 1:
[[ "\$KEEP_STAGE" -ge 1 ]] && exit 0
rm -rf "$OPENCV_PYTHON_GIT_DIR"
rmdir --ignore-fail-on-non-empty '$ENV_DIR' 2>/dev/null || true
rmdir --ignore-fail-on-non-empty '$ENVS_DIR' 2>/dev/null || true
EOM
add_uninstall_cmds "# $UNINSTALLER_COMMANDS"
echo "$UNINSTALLER_COMMANDS"
echo

# Ensure the envs directory and subdirectory exists
[[ ! -d "$ENVS_DIR" ]] && mkdir "$ENVS_DIR"
[[ ! -d "$ENV_DIR" ]] && mkdir "$ENV_DIR"

# Clone the OpenCV repositories
echo "Cloning OpenCV python build tag $CFG_OPENCV_PYTHON_TAG..."
if [[ ! -f "$OPENCV_PYTHON_COMPILED" ]] && [[ ! -d "$OPENCV_PYTHON_GIT_DIR" ]]; then
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
		[[ -f "$OPENCV_PYTHON_GIT_DIR/pyproject.toml" ]] && sed -i 's/"setuptools", "wheel", "scikit-build", "cmake"/"setuptools==59.2.0", "wheel==0.37.0", "cmake>=3.1", "scikit-build>=0.13.2"/g' "$OPENCV_PYTHON_GIT_DIR/pyproject.toml"
		[[ -f "$OPENCV_PYTHON_GIT_DIR/setup.py" ]] && sed -i 's/ cmake_install_dir=cmake_install_reldir,/ _cmake_install_dir=cmake_install_reldir,/g' "$OPENCV_PYTHON_GIT_DIR/setup.py"
		[[ -f "$OPENCV_GIT_DIR/modules/dnn/CMakeLists.txt" ]] && patch -s -u -f -F 0 -N -r - --no-backup-if-mismatch "$OPENCV_GIT_DIR/modules/dnn/CMakeLists.txt" >/dev/null << 'EOM' || true
@@ -159,2 +159,5 @@
 ocv_module_include_directories(${include_dirs})
+get_target_property(libprotobuf_interface_include_dirs libprotobuf INTERFACE_SYSTEM_INCLUDE_DIRECTORIES)
+string(REGEX REPLACE "\\$<BUILD_INTERFACE:([^>]*)>" "\\1" libprotobuf_interface_include_dirs ${libprotobuf_interface_include_dirs})
+include_directories(BEFORE SYSTEM ${libprotobuf_interface_include_dirs})
 if(CMAKE_CXX_COMPILER_ID STREQUAL "GNU")
EOM
	)
fi
echo

# Stop if stage limit reached
[[ "$CFG_STAGE" -eq 1 ]] && exit 0

#
# Stage 2
#

# Stage 2 uninstall
UNINSTALLER_COMMANDS="Commands to undo stage 2:"$'\n''[[ "$KEEP_STAGE" -ge 2 ]] && exit 0'$'\n'"set +ux"
[[ "$CFG_CONDA_CREATE" == "1" ]] && UNINSTALLER_COMMANDS+=$'\n'"conda deactivate"$'\n'"conda env remove -n '$CFG_CONDA_ENV'"
[[ "$CFG_CLEAN_CONDA" == "1" ]] && UNINSTALLER_COMMANDS+=$'\n'"conda clean -y --all"
UNINSTALLER_COMMANDS+=$'\n'"set -ux"
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
	if [[ -n "$CFG_CONDA_LOAD" ]]; then
		conda create $CFG_AUTO_YES -n "$CFG_CONDA_ENV" --no-default-packages
	else
		conda create $CFG_AUTO_YES -n "$CFG_CONDA_ENV" python="$CFG_CONDA_PYTHON"
	fi
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
	conda config --env --set channel_priority flexible
	if [[ -n "$CFG_CONDA_LOAD" ]]; then
		if [[ "$CFG_CONDA_LOAD" == *.txt ]]; then
			conda install $CFG_AUTO_YES -n "$CFG_CONDA_ENV" --file "$CFG_CONDA_LOAD"
		else
			conda env update -n "$CFG_CONDA_ENV" --file "$CFG_CONDA_LOAD"
		fi
	else
		conda install $CFG_AUTO_YES cython
		CERES_VERSION=
		if [[ -f "$OPENCV_GIT_DIR/modules/python/package/setup.py" ]]; then
			OPENCV_VERSION_PARSED="$(grep -oP -m1 "(?<=os\.environ\.get\('OPENCV_VERSION', ')\d+\.\d+\.\d+(?=\w*'\))" < "$OPENCV_GIT_DIR/modules/python/package/setup.py" | head -n1)"
			if [[ -n "$OPENCV_VERSION_PARSED" ]]; then
				REFA="$OPENCV_VERSION_PARSED"$'\n'"3.4.17"
				REFB="$OPENCV_VERSION_PARSED"$'\n'"4.5.5"
				if [[ "$(sort -V <<< "$REFA")" == "$REFA" || ("$(sort -V <<< "$REFB")" == "$REFB" && "${OPENCV_VERSION_PARSED%%.*}" -ge 4) ]]; then
					CERES_VERSION="<=2.1.0"
				fi
			fi
		fi
		conda install $CFG_AUTO_YES ceres-solver$CERES_VERSION cmake ffmpeg freetype gflags glog gstreamer gst-plugins-base gst-plugins-good harfbuzz hdf5 jpeg libdc1394 libiconv libpng libtiff libva libwebp mkl mkl-include ninja numpy openjpeg pkgconfig six snappy tbb tbb-devel tbb4py tifffile
		conda install $CFG_AUTO_YES --force-reinstall $(conda list -q --no-pip | egrep -v -e '^#' -e '^_' | cut -d' ' -f1 | egrep -v '^(python|(open)?blas(-devel)?|)$' | tr '\n' ' ')  # Workaround for conda dependency mismanagement...
		conda install $CFG_AUTO_YES -c conda-forge libstdcxx-ng libgcc-ng libgfortran-ng libgfortran5
		conda install $CFG_AUTO_YES setuptools==58.0.4
		CERES_EIGEN_VERSION="$(grep -oP '(?<=set\(CERES_EIGEN_VERSION)\s+[0-9.]+\s*(?=\))' "$CONDA_ENV_DIR/lib/cmake/Ceres/CeresConfig.cmake")"
		CERES_EIGEN_VERSION="${CERES_EIGEN_VERSION// /}"
		if [[ -n "$CERES_EIGEN_VERSION" ]]; then
			conda install $CFG_AUTO_YES eigen="$CERES_EIGEN_VERSION"
		else
			echo "Failed to parse Eigen version required by Ceres"
			exit 1
		fi
	fi
	set -u
	[[ -f "$CONDA_ENV_DIR/etc/conda/activate.d/libblas_mkl_activate.sh" ]] && chmod +x "$CONDA_ENV_DIR/etc/conda/activate.d/libblas_mkl_activate.sh"
	[[ -f "$CONDA_ENV_DIR/etc/conda/deactivate.d/libblas_mkl_deactivate.sh" ]] && chmod +x "$CONDA_ENV_DIR/etc/conda/deactivate.d/libblas_mkl_deactivate.sh"
	echo
	echo "Performing pip check..."
	echo -en "\033[0;33m"
	pip check || true
	echo -en "\033[0m"
	echo
fi

# Clean conda cache
if [[ "$CFG_CLEAN_CONDA" == "1" ]]; then
	echo "Cleaning conda cache..."
	set +u
	conda clean $CFG_AUTO_YES --all
	set -u
	echo
fi

# Reactivate the conda environment
echo "Reactivating $CFG_CONDA_ENV conda environment..."
set +u
conda deactivate
conda activate "$CFG_CONDA_ENV"
set -u
echo

# Save the environment specifications to file
if [[ "$CFG_CONDA_SAVE" != "0" ]]; then
	PYTHON_SPEC="$(python -c 'import sys; print("py%d%d%d" % (sys.version_info.major, sys.version_info.minor, sys.version_info.micro))')"
	DATE_SPEC="$(date '+%Y%m%d')"
	CONDA_SPEC_DIR="$CFG_ROOT_DIR/conda"
	CONDA_SPEC_YML="$CONDA_SPEC_DIR/conda-opencv-python-$PYTHON_SPEC-$DATE_SPEC.yml"
	CONDA_SPEC_TXT="$CONDA_SPEC_DIR/conda-opencv-python-$PYTHON_SPEC-$DATE_SPEC-explicit.txt"
	set +u
	echo "Saving conda env to: $CONDA_SPEC_YML"
	conda env export | grep -v "^prefix:" > "$CONDA_SPEC_YML"
	echo "Saving conda env to: $CONDA_SPEC_TXT"
	conda list --explicit > "$CONDA_SPEC_TXT"
	set -u
	echo
fi

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
[[ "\$KEEP_STAGE" -ge 3 ]] && exit 0
set +ux
if conda activate '$CFG_CONDA_ENV'; then INSTALLED_OPENCVS="\$(pip list | grep -e "^opencv-" | cut -d' ' -f1 | tr $'\n' ' ' || true)"; [[ -n "\$INSTALLED_OPENCVS" ]] && pip uninstall -y \$INSTALLED_OPENCVS || true; fi
set -ux
rm -rf '$OPENCV_PYTHON_GIT_DIR'/{_skbuild,*.whl,*.egg-info,opencv/.cache} '$OPENCV_PYTHON_STUB_DIR'
EOM
add_uninstall_cmds "# $UNINSTALLER_COMMANDS"
echo "$UNINSTALLER_COMMANDS"
echo

# Build OpenCV python
echo "Building OpenCV python build tag $CFG_OPENCV_PYTHON_TAG..."
if [[ ! -f "$OPENCV_PYTHON_COMPILED" ]] && find "$OPENCV_PYTHON_GIT_DIR" -maxdepth 1 -type f -name "opencv_*.whl" -exec false {} +; then
	(
		rm -rf "$OPENCV_PYTHON_GIT_DIR"/*.whl
		cd "$OPENCV_PYTHON_GIT_DIR"
		set +u
		conda activate "$CFG_CONDA_ENV"
		set -u
		export CMAKE_PREFIX_PATH="$CONDA_PREFIX"
		export CMAKE_ARGS="-DCMAKE_CXX_STANDARD=14 -DENABLE_CONFIG_VERIFICATION=\"$CFG_OPENCV_STRICT\" -DOPENCV_ENABLE_NONFREE=ON -DENABLE_FAST_MATH=OFF -DWITH_IMGCODEC_HDR=ON -DWITH_IMGCODEC_SUNRASTER=ON -DWITH_IMGCODEC_PXM=ON -DWITH_IMGCODEC_PFM=ON -DWITH_ADE=ON -DWITH_PNG=ON -DWITH_JPEG=ON -DWITH_TIFF=ON -DWITH_WEBP=ON -DWITH_OPENJPEG=ON -DWITH_JASPER=OFF -DWITH_OPENEXR=ON -DBUILD_OPENEXR=ON -DWITH_TESSERACT=OFF -DWITH_V4L=ON -DWITH_FFMPEG=ON -DWITH_GSTREAMER=ON -DWITH_1394=ON -DWITH_OPENGL=ON -DOpenGL_GL_PREFERENCE=LEGACY -DWITH_PTHREADS_PF=ON -DWITH_TBB=OFF -DWITH_OPENMP=ON -DWITH_CUDA=ON -DCUDA_GENERATION=Auto -DCUDA_FAST_MATH=OFF -DWITH_CUDNN=ON -DWITH_CUFFT=ON -DWITH_CUBLAS=ON -DWITH_OPENCL=ON -DWITH_OPENCLAMDFFT=OFF -DWITH_OPENCLAMDBLAS=OFF -DWITH_VA=ON -DWITH_VA_INTEL=ON -DWITH_PROTOBUF=ON -DBUILD_PROTOBUF=ON -DPROTOBUF_UPDATE_FILES=OFF -DOPENCV_DNN_CUDA=ON -DOPENCV_DNN_OPENCL=ON -DWITH_EIGEN=ON -DWITH_LAPACK=ON -DWITH_QUIRC=ON"
		[[ "$CFG_OPENCV_HEADLESS" == "0" ]] && CMAKE_ARGS+=" -DWITH_VTK=OFF -DWITH_GTK=OFF -DWITH_QT=ON"
		[[ -n "$CFG_OPENCV_CMAKE" ]] && CMAKE_ARGS+=" $CFG_OPENCV_CMAKE"
		export ENABLE_CONTRIB="$CFG_OPENCV_CONTRIB"
		export ENABLE_HEADLESS="$CFG_OPENCV_HEADLESS"
		export MAKEFLAGS="-j$(nproc)"
		time pip wheel --verbose .
	)
fi
echo

# Install OpenCV python
echo "Installing OpenCV python build tag $CFG_OPENCV_PYTHON_TAG..."
if [[ ! -f "$OPENCV_PYTHON_COMPILED" ]]; then
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
	fi
fi
echo

# Clean the OpenCV python build
if [[ "$CFG_CLEAN_WORKDIR" -ge 1 ]]; then
	echo "Cleaning up OpenCV python build..."
	rm -rf "$OPENCV_PYTHON_GIT_DIR"/{_skbuild,*.whl,*.egg-info,opencv/.cache}
	echo
fi

# Install OpenCV python stub package if required
if [[ ! -f "$OPENCV_PYTHON_COMPILED" ]] && [[ "$OPENCV_PACKAGE" != "opencv-python" ]]; then
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
			pip wheel --verbose .
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

# Clean the OpenCV python stub package build
if [[ "$CFG_CLEAN_WORKDIR" -ge 1 ]]; then
	echo "Cleaning up OpenCV python stub package build..."
	rm -rf "$OPENCV_PYTHON_STUB_DIR"/{build,*.whl,*.egg-info}
	echo
fi

# Show OpenCV python build information
echo "Showing installed OpenCV build information..."
python -c "import cv2; print('Found python OpenCV', cv2.__version__); print(cv2.getBuildInformation())"
echo

# Stop if stage limit reached
[[ "$CFG_STAGE" -eq 3 ]] && exit 0

#
# Stage 4
#

# Stage 4 uninstall
read -r -d '' UNINSTALLER_COMMANDS << EOM || true
Commands to undo stage 4:
[[ "\$KEEP_STAGE" -ge 4 ]] && exit 0
rm -rf '$OPENCV_PYTHON_COMPILED'
EOM
add_uninstall_cmds "# $UNINSTALLER_COMMANDS"
echo "$UNINSTALLER_COMMANDS"
echo

# Mark OpenCV python as compiled
[[ ! -f "$OPENCV_PYTHON_COMPILED" ]] && touch "$OPENCV_PYTHON_COMPILED"

# Clean up local working directory
if [[ "$CFG_CLEAN_WORKDIR" -ge 2 ]]; then
	echo "Cleaning local working directory..."
	find "$ENV_DIR" -mindepth 1 -not -name "$(basename "$OPENCV_PYTHON_COMPILED")" -prune -exec rm -rf {} +
	echo
fi

# Stop if stage limit reached
[[ "$CFG_STAGE" -eq 4 ]] && exit 0

#
# Finish
#

# Signal that the script completely finished
echo "Finished OpenCV python installation into conda env $CFG_CONDA_ENV"
echo

# EOF
