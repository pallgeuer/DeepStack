#!/bin/bash -i
# Install PyTorch into a conda environment

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

#
# Configuration
#

# Whether to stop after a particular stage
CFG_STAGE="${CFG_STAGE:-0}"

# Whether to skip installation steps that are not strictly necessary in order to save time
CFG_QUICK="${CFG_QUICK:-}"

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

# PyTorch git tag, version and name to install (tag should be one of these: https://github.com/pytorch/pytorch/tags)
# Example: CFG_PYTORCH_TAG=v1.10.2
CFG_PYTORCH_VERSION="${CFG_PYTORCH_VERSION:-${CFG_PYTORCH_TAG#v}}"
CFG_PYTORCH_NAME="${CFG_PYTORCH_NAME:-pytorch-$CFG_PYTORCH_VERSION}"

# Optional torchvision git tag and version (see https://github.com/pytorch/vision#installation for compatibility, tag should be one of these: https://github.com/pytorch/vision/tags)
CFG_TORCHVISION_TAG="${CFG_TORCHVISION_TAG:-}"  # Example: v0.11.3
CFG_TORCHVISION_VERSION="${CFG_TORCHVISION_VERSION:-${CFG_TORCHVISION_TAG#v}}"

# Optional torchaudio git tag and version (see https://github.com/pytorch/audio#dependencies for compatibility, tag should be one of these: https://github.com/pytorch/audio/tags)
CFG_TORCHAUDIO_TAG="${CFG_TORCHAUDIO_TAG:-}"  # Example: v0.10.2
CFG_TORCHAUDIO_VERSION="${CFG_TORCHAUDIO_VERSION:-${CFG_TORCHAUDIO_TAG#v}}"

# Optional torchtext git tag and version (see https://github.com/pytorch/text#installation for compatibility, tag should be one of these: https://github.com/pytorch/text/tags)
CFG_TORCHTEXT_TAG="${CFG_TORCHTEXT_TAG:-}"  # Example: v0.11.2
CFG_TORCHTEXT_VERSION="${CFG_TORCHTEXT_VERSION:-${CFG_TORCHTEXT_TAG#v}}"

# OpenCV git tag and version (tag should be one of these: https://github.com/opencv/opencv/tags)
# Example: CFG_OPENCV_TAG=4.5.5
CFG_OPENCV_VERSION="${CFG_OPENCV_VERSION:-$CFG_OPENCV_TAG}"
CFG_OPENCV_HEADLESS="${CFG_OPENCV_HEADLESS:-0}"
CFG_OPENCV_CMAKE="${CFG_OPENCV_CMAKE:-}"  # Note: This is not expansion-safe

# TensorRT version and URL to use (https://developer.nvidia.com/nvidia-tensorrt-download -> TensorRT X -> Agree to the terms -> TensorRT X.X.X for Linux x86_64/Ubuntu YY.YY and CUDA Z.Z TAR package -> Fix URL capitalisation if necessary), branch or tag to use for onnx-tensorrt (https://github.com/onnx/onnx-tensorrt/branches/all or https://github.com/onnx/onnx-tensorrt/tags), and whether to explicitly compile TensorRT into PyTorch or just install it into the conda environment
CFG_TENSORRT_VERSION="${CFG_TENSORRT_VERSION:-}"
CFG_TENSORRT_URL="${CFG_TENSORRT_URL:-}"
CFG_TENSORRT_ONNX_TAG="${CFG_TENSORRT_ONNX_TAG:-}"
CFG_TENSORRT_PYTORCH="${CFG_TENSORRT_PYTORCH:-1}"

# Generate default conda environment name
CFG_TENSORRT_URL="${CFG_TENSORRT_URL%/}"
DEFAULT_CFG_CONDA_ENV="$CFG_PYTORCH_NAME-$CFG_CUDA_NAME"
if [[ -n "$CFG_TENSORRT_URL" ]]; then
	[[ "$CFG_TENSORRT_PYTORCH" == "1" ]] && DEFAULT_CFG_CONDA_ENV+="-trt" || DEFAULT_CFG_CONDA_ENV+="-trtext"
	DEFAULT_CFG_CONDA_ENV+="-$CFG_TENSORRT_VERSION"
fi

# Name to use for the created conda environment
CFG_CONDA_ENV="${CFG_CONDA_ENV:-$DEFAULT_CFG_CONDA_ENV}"
CFG_CONDA_CREATE="${CFG_CONDA_CREATE:-1}"  # Set this to anything other than "true" to not attempt environment creation (environment must already exist and be appropriately configured)

# Python version to use for the created conda environment (see https://github.com/pytorch/vision#installation for compatibility)
# Example: CFG_CONDA_PYTHON=3.9

# Whether to clean (post-installation) the downloaded installers (uninstaller always cleans), local working directory (0 = Do not clean, 1 = Clean build products, 2 = Clean everything) and conda cache (conda clean command, also affects uninstaller)
CFG_CLEAN_INSTALLERS="${CFG_CLEAN_INSTALLERS:-1}"
CFG_CLEAN_WORKDIR="${CFG_CLEAN_WORKDIR:-2}"
CFG_CLEAN_CONDA="${CFG_CLEAN_CONDA:-1}"

# Enter the root directory
cd "$CFG_ROOT_DIR"

# Clean up configuration variables
[[ "$CFG_STAGE" -lt -1 ]] 2>/dev/null && CFG_STAGE=0
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
[[ "$CFG_OPENCV_HEADLESS" != "0" ]] && CFG_OPENCV_HEADLESS="1"
[[ "$CFG_TENSORRT_PYTORCH" != "1" ]] && CFG_TENSORRT_PYTORCH="0"
[[ "$CFG_CONDA_CREATE" != "1" ]] && CFG_CONDA_CREATE="0"
[[ "$CFG_CLEAN_INSTALLERS" != "1" ]] && CFG_CLEAN_INSTALLERS="0"
[[ "$CFG_CLEAN_WORKDIR" != "2" ]] && [[ "$CFG_CLEAN_WORKDIR" != "1" ]] && CFG_CLEAN_WORKDIR="0"
[[ "$CFG_CLEAN_CONDA" != "1" ]] && CFG_CLEAN_CONDA="0"

# Display the configuration
echo
echo "CFG_STAGE = $CFG_STAGE"
echo "CFG_QUICK = $CFG_QUICK"
echo "CFG_AUTO_ANSWER = $CFG_AUTO_ANSWER"
echo "CFG_ALLOW_SUDO = $CFG_ALLOW_SUDO"
echo "CFG_ROOT_DIR = $CFG_ROOT_DIR"
echo "CFG_CUDA_VERSION = $CFG_CUDA_VERSION"
echo "CFG_CUDA_NAME = $CFG_CUDA_NAME"
echo "CFG_CUDA_LOCATION = $CFG_CUDA_LOCATION"
echo "CFG_PYTORCH_TAG = $CFG_PYTORCH_TAG"
echo "CFG_PYTORCH_VERSION = $CFG_PYTORCH_VERSION"
echo "CFG_PYTORCH_NAME = $CFG_PYTORCH_NAME"
echo "CFG_TORCHVISION_TAG = $CFG_TORCHVISION_TAG"
echo "CFG_TORCHVISION_VERSION = $CFG_TORCHVISION_VERSION"
echo "CFG_TORCHAUDIO_TAG = $CFG_TORCHAUDIO_TAG"
echo "CFG_TORCHAUDIO_VERSION = $CFG_TORCHAUDIO_VERSION"
echo "CFG_TORCHTEXT_TAG = $CFG_TORCHTEXT_TAG"
echo "CFG_TORCHTEXT_VERSION = $CFG_TORCHTEXT_VERSION"
echo "CFG_OPENCV_TAG = $CFG_OPENCV_TAG"
echo "CFG_OPENCV_VERSION = $CFG_OPENCV_VERSION"
echo "CFG_OPENCV_HEADLESS = $CFG_OPENCV_HEADLESS"
echo "CFG_OPENCV_CMAKE = $CFG_OPENCV_CMAKE"
echo "CFG_TENSORRT_VERSION = $CFG_TENSORRT_VERSION"
echo "CFG_TENSORRT_URL = $CFG_TENSORRT_URL"
echo "CFG_TENSORRT_ONNX_TAG = $CFG_TENSORRT_ONNX_TAG"
echo "CFG_TENSORRT_PYTORCH = $CFG_TENSORRT_PYTORCH"
echo "CFG_CONDA_CREATE = $CFG_CONDA_CREATE"
echo "CFG_CONDA_ENV = $CFG_CONDA_ENV"
echo "CFG_CONDA_PYTHON = $CFG_CONDA_PYTHON"
echo "CFG_CLEAN_INSTALLERS = $CFG_CLEAN_INSTALLERS"
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
echo "Starting PyTorch installation..."
echo

# Install system dependencies
echo "Installing various system dependencies..."
if [[ "$CFG_ALLOW_SUDO" == "1" ]]; then
	[[ -n "$CFG_TENSORRT_URL" ]] && [[ -z "$CFG_QUICK" ]] && sudo apt install $CFG_AUTO_YES python3-numpy python3-pil
	sudo apt install $CFG_AUTO_YES libnuma-dev
	sudo apt install $CFG_AUTO_YES libva-dev libtbb-dev
	sudo apt install $CFG_AUTO_YES v4l-utils libv4l-dev
	sudo apt install $CFG_AUTO_YES openmpi-bin libopenmpi-dev
	sudo apt install $CFG_AUTO_YES libglu1-mesa libglu1-mesa-dev freeglut3-dev libglfw3 libglfw3-dev libgl1-mesa-glx
	sudo apt install $CFG_AUTO_YES qt5-default
	sudo apt install $CFG_AUTO_YES fftw3 fftw3-dev
	sudo apt install $CFG_AUTO_YES protobuf-compiler libprotobuf-dev
fi
echo

# Stop if stage limit reached
[[ "$CFG_STAGE" -eq -1 ]] && exit 0

# Initialise uninstaller script
UNINSTALLERS_DIR="$CFG_ROOT_DIR/Uninstallers"
UNINSTALLER_SCRIPT="$UNINSTALLERS_DIR/uninstall-$CFG_CONDA_ENV-pytorch.sh"
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
INSTALLERS_DIR="$CFG_ROOT_DIR/Installers"
if [[ -n "$CFG_TENSORRT_URL" ]]; then
	TENSORRT_TARNAME="${CFG_TENSORRT_URL##*/}"
	TENSORRT_TAR="$INSTALLERS_DIR/$TENSORRT_TARNAME"
	if [[ "$TENSORRT_TARNAME" =~ ^([a-zA-Z]+-[0-9]+\.[0-9]+\.[0-9]+(\.[0-9]+)?)\..*$ ]]; then
		TENSORRT_DIRNAME="${BASH_REMATCH[1]}"
	else
		echo "Failed to parse TensorRT directory name from: $TENSORRT_TARNAME"
		exit 1
	fi
	MAIN_TENSORRT_DIR="$CFG_ROOT_DIR/TensorRT"
	TENSORRT_INSTALL_DIR="$MAIN_TENSORRT_DIR/$TENSORRT_DIRNAME"
	TENSORRT_ENVS_LIST="$TENSORRT_INSTALL_DIR/envs.list"
	TENSORRT_SAMPLES_COMPILED="$TENSORRT_INSTALL_DIR/samples/compiled-$CFG_CUDA_NAME"
fi

# Stage 1 uninstall
UNINSTALLER_COMMANDS="Commands to undo stage 1:"
[[ -n "$CFG_TENSORRT_URL" ]] && UNINSTALLER_COMMANDS+=$'\n'"rm -rf '$TENSORRT_TAR'"
UNINSTALLER_COMMANDS+=$'\n'"rmdir --ignore-fail-on-non-empty '$INSTALLERS_DIR' 2>/dev/null || true"
add_uninstall_cmds "# $UNINSTALLER_COMMANDS"
echo "$UNINSTALLER_COMMANDS"
echo

# Download installers
echo "Downloading installers..."
[[ ! -d "$INSTALLERS_DIR" ]] && mkdir "$INSTALLERS_DIR"
echo
if [[ -n "$CFG_TENSORRT_URL" ]]; then
	echo "Downloading TensorRT $CFG_TENSORRT_VERSION..."
	if [[ ! -d "$TENSORRT_INSTALL_DIR" ]] && [[ ! -f "$TENSORRT_TAR" ]]; then
		echo "Please log in with your NVIDIA account and don't close the browser..."
		xdg-open 'https://www.nvidia.com/en-us/account' || echo "xdg-open failed: Please manually perform the requested action"
		read -n 1 -p "Press enter when you have done that [ENTER] "
		echo "Opening download URL: $CFG_TENSORRT_URL"
		echo "Please save tar to: $TENSORRT_TAR"
		xdg-open "$CFG_TENSORRT_URL" || echo "xdg-open failed: Please manually perform the requested action"
		read -n 1 -p "Press enter when it has finished downloading [ENTER] "
		if [[ ! -f "$TENSORRT_TAR" ]]; then
			echo "File does not exist: $TENSORRT_TAR"
			exit 1
		fi
	fi
	echo
fi
rmdir --ignore-fail-on-non-empty "$INSTALLERS_DIR" 2>/dev/null || true

# Stop if stage limit reached
[[ "$CFG_STAGE" -eq 1 ]] && exit 0

#
# Stage 2
#

# Variables
ENVS_DIR="$CFG_ROOT_DIR/envs"
ENV_DIR="$ENVS_DIR/$CFG_CONDA_ENV"
PYTORCH_COMPILED="$ENV_DIR/pytorch_compiled"
PYTORCH_GIT_DIR="$ENV_DIR/pytorch"
TORCHVISION_GIT_DIR="$ENV_DIR/torchvision"
TORCHAUDIO_GIT_DIR="$ENV_DIR/torchaudio"
TORCHTEXT_GIT_DIR="$ENV_DIR/torchtext"
OPENCV_GIT_DIR="$ENV_DIR/opencv"
OPENCV_CONTRIB_GIT_DIR="$ENV_DIR/opencv_contrib"

# Stage 2 uninstall
read -r -d '' UNINSTALLER_COMMANDS << EOM || true
Commands to undo stage 2:
rm -rf '$PYTORCH_GIT_DIR' '$TORCHVISION_GIT_DIR' '$TORCHAUDIO_GIT_DIR' '$TORCHTEXT_GIT_DIR' '$OPENCV_GIT_DIR' '$OPENCV_CONTRIB_GIT_DIR'
rmdir --ignore-fail-on-non-empty '$ENV_DIR' 2>/dev/null || true
rmdir --ignore-fail-on-non-empty '$ENVS_DIR' 2>/dev/null || true
EOM
if [[ -n "$CFG_TENSORRT_URL" ]]; then
	read -r -d '' EXTRA_UNINSTALLER_COMMANDS << EOM || true
[[ -d '$TENSORRT_INSTALL_DIR/samples' ]] && ( cd '$TENSORRT_INSTALL_DIR/samples'; export CUDA_INSTALL_DIR='$CUDA_INSTALL_DIR'; export CUDNN_INSTALL_DIR="\$CUDA_INSTALL_DIR"; export TRT_LIB_DIR='$TENSORRT_INSTALL_DIR/lib'; export PROTOBUF_INSTALL_DIR=/usr/lib/x86_64-linux-gnu; make clean >/dev/null; )
rm -rf '$TENSORRT_INSTALL_DIR/bintmp'
rm -f '$TENSORRT_INSTALL_DIR/data/mnist/'{train,t10k}-{images,labels}-*
rm -f '$TENSORRT_SAMPLES_COMPILED'
[[ -f '$TENSORRT_ENVS_LIST' ]] && { grep -vFx '$CFG_CONDA_ENV'$'\n' '$TENSORRT_ENVS_LIST' > '${TENSORRT_ENVS_LIST}.tmp' || true; mv '${TENSORRT_ENVS_LIST}.tmp' '$TENSORRT_ENVS_LIST'; }
[[ "\$(cat '$TENSORRT_ENVS_LIST' 2>/dev/null | wc -l)" -eq 0 ]] && rm -rf '$TENSORRT_INSTALL_DIR'
rmdir --ignore-fail-on-non-empty '$MAIN_TENSORRT_DIR' 2>/dev/null || true
EOM
	UNINSTALLER_COMMANDS+=$'\n'"$EXTRA_UNINSTALLER_COMMANDS"
fi
add_uninstall_cmds "# $UNINSTALLER_COMMANDS"
echo "$UNINSTALLER_COMMANDS"
echo

# Ensure the envs directory and subdirectory exists
[[ ! -d "$ENVS_DIR" ]] && mkdir "$ENVS_DIR"
[[ ! -d "$ENV_DIR" ]] && mkdir "$ENV_DIR"

# Clone the PyTorch repository
echo "Cloning PyTorch $CFG_PYTORCH_VERSION..."
if [[ ! -f "$PYTORCH_COMPILED" ]] && [[ ! -d "$PYTORCH_GIT_DIR" ]]; then
	(
		set -x
		cd "$ENV_DIR"
		git clone --recursive -j"$(nproc)" https://github.com/pytorch/pytorch pytorch
		cd "$PYTORCH_GIT_DIR"
		git checkout "$CFG_PYTORCH_TAG"
		git checkout --recurse-submodules "$CFG_PYTORCH_TAG"
		git submodule sync
		git submodule update --init --recursive
		git submodule status
		[[ -f "$PYTORCH_GIT_DIR/caffe2/utils/threadpool/pthreadpool-cpp.cc" ]] && sed -i 's/TORCH_WARN("Leaking Caffe2 thread-pool after fork.");/;/g' "$PYTORCH_GIT_DIR/caffe2/utils/threadpool/pthreadpool-cpp.cc"
		[[ -f "$PYTORCH_GIT_DIR/tools/setup_helpers/cmake.py" ]] && sed -i "s|additional_options = {|&'pybind11_PREFER_third_party': 'pybind11_PREFER_third_party',|" "$PYTORCH_GIT_DIR/tools/setup_helpers/cmake.py"
		if [[ -f "$PYTORCH_GIT_DIR/binaries/CMakeLists.txt" ]]; then
			grep -Fq '${CMAKE_CURRENT_SOURCE_DIR}/../modules' "$PYTORCH_GIT_DIR/binaries/CMakeLists.txt" && ! grep -Fq 'target_include_directories(convert_and_benchmark ' "$PYTORCH_GIT_DIR/binaries/CMakeLists.txt" && patch -s -u -f -F 0 -N -r - --no-backup-if-mismatch "$PYTORCH_GIT_DIR/binaries/CMakeLists.txt" >/dev/null << 'EOM' || true
@@ -109,2 +109,3 @@
   caffe2_binary_target("convert_and_benchmark.cc")
+  target_include_directories(convert_and_benchmark PUBLIC ${CMAKE_CURRENT_SOURCE_DIR}/../modules)
   target_link_libraries(convert_and_benchmark ${OpenCV_LIBS})
EOM
			grep -q '\WBUILD_CAFFE2\W' "$PYTORCH_GIT_DIR/binaries/CMakeLists.txt" && patch -s -u -f -F 0 -N -r - --no-backup-if-mismatch "$PYTORCH_GIT_DIR/binaries/CMakeLists.txt" >/dev/null << 'EOM' || true
@@ -61,2 +61,2 @@
-if(USE_CUDA)
+if(USE_CUDA AND BUILD_CAFFE2)
   caffe2_binary_target("inspect_gpu.cc")
@@ -84,2 +84,2 @@
-if(USE_ZMQ)
+if(USE_ZMQ AND BUILD_CAFFE2)
   caffe2_binary_target("zmq_feeder.cc")
@@ -89,2 +89,2 @@
-if(USE_MPI)
+if(USE_MPI AND BUILD_CAFFE2)
   caffe2_binary_target("run_plan_mpi.cc")
@@ -94,2 +94,2 @@
-if(USE_OPENCV AND USE_LEVELDB)
+if(USE_OPENCV AND USE_LEVELDB AND BUILD_CAFFE2)
   caffe2_binary_target("convert_encoded_to_raw_leveldb.cc")
@@ -101,2 +101,2 @@
-if(USE_OPENCV)
+if(USE_OPENCV AND BUILD_CAFFE2)
   caffe2_binary_target("make_image_db.cc")
@@ -108,2 +108,2 @@
-if(USE_OBSERVERS AND USE_OPENCV)
+if(USE_OBSERVERS AND USE_OPENCV AND BUILD_CAFFE2)
   caffe2_binary_target("convert_and_benchmark.cc")
EOM
		fi
		if [[ -n "$CFG_TENSORRT_URL" ]]; then
			if [[ -n "$CFG_TENSORRT_ONNX_TAG" ]]; then
				(
					cd "$PYTORCH_GIT_DIR/third_party/onnx-tensorrt"
					git checkout "$CFG_TENSORRT_ONNX_TAG"
					git checkout --recurse-submodules "$CFG_TENSORRT_ONNX_TAG"
					git submodule sync
					git submodule update --init --recursive
					git submodule status
				)
			fi
			[[ -f "$PYTORCH_GIT_DIR/tools/setup_helpers/cmake.py" ]] && sed -i "s/'BUILD_', 'USE_', 'CMAKE_'/&, 'TENSORRT_'/" "$PYTORCH_GIT_DIR/tools/setup_helpers/cmake.py"
			[[ -f "$PYTORCH_GIT_DIR/caffe2/contrib/tensorrt/tensorrt_tranformer.cc" ]] && sed -i "s/^\s*auto cutResult = opt::OptimizeForBackend(\*pred_net, supports, trt_converter)$/&;/" "$PYTORCH_GIT_DIR/caffe2/contrib/tensorrt/tensorrt_tranformer.cc"
			[[ -f "$PYTORCH_GIT_DIR/third_party/onnx-tensorrt/builtin_op_importers.cpp" ]] && sed -i "s/constexpr auto getMatrixOp = \[\]/auto getMatrixOp = []/g" "$PYTORCH_GIT_DIR/third_party/onnx-tensorrt/builtin_op_importers.cpp"
		fi
	)
fi
echo

# Clone the torchvision repository
if [[ -n "$CFG_TORCHVISION_TAG" ]]; then
	echo "Cloning Torchvision $CFG_TORCHVISION_VERSION..."
	if [[ ! -f "$PYTORCH_COMPILED" ]] && [[ ! -d "$TORCHVISION_GIT_DIR" ]]; then
		(
			set -x
			cd "$ENV_DIR"
			git clone --recursive -j"$(nproc)" https://github.com/pytorch/vision.git torchvision
			cd "$TORCHVISION_GIT_DIR"
			git checkout "$CFG_TORCHVISION_TAG"
			git checkout --recurse-submodules "$CFG_TORCHVISION_TAG"
			git submodule sync
			git submodule update --init --recursive
			git submodule status
		)
	fi
	echo
fi

# Clone the torchaudio repository
if [[ -n "$CFG_TORCHAUDIO_TAG" ]]; then
	echo "Cloning Torchaudio $CFG_TORCHAUDIO_VERSION..."
	if [[ ! -f "$PYTORCH_COMPILED" ]] && [[ ! -d "$TORCHAUDIO_GIT_DIR" ]]; then
		(
			set -x
			cd "$ENV_DIR"
			git clone --recursive -j"$(nproc)" https://github.com/pytorch/audio.git torchaudio
			cd "$TORCHAUDIO_GIT_DIR"
			git checkout "$CFG_TORCHAUDIO_TAG"
			git checkout --recurse-submodules "$CFG_TORCHAUDIO_TAG"
			git submodule sync
			git submodule update --init --recursive
			git submodule status
			[[ -n "$CFG_TENSORRT_URL" ]] && [[ -f "$TORCHAUDIO_GIT_DIR/build_tools/setup_helpers/extension.py" ]] && sed -i 's|cmake_args = \[|&f"-DTENSORRT_ROOT={os.getenv('"'"'TENSORRT_ROOT'"'"')}", |' "$TORCHAUDIO_GIT_DIR/build_tools/setup_helpers/extension.py"
			[[ -f "$TORCHAUDIO_GIT_DIR/third_party/kaldi/CMakeLists.txt" ]] && sed -i 's|COMMAND sh get_version\.sh|COMMAND ./get_version.sh|g' "$TORCHAUDIO_GIT_DIR/third_party/kaldi/CMakeLists.txt"
		)
	fi
	echo
fi

# Clone the torchtext repository
if [[ -n "$CFG_TORCHTEXT_TAG" ]]; then
	echo "Cloning Torchtext $CFG_TORCHTEXT_VERSION..."
	if [[ ! -f "$PYTORCH_COMPILED" ]] && [[ ! -d "$TORCHTEXT_GIT_DIR" ]]; then
		(
			set -x
			cd "$ENV_DIR"
			git clone --recursive -j"$(nproc)" https://github.com/pytorch/text.git torchtext
			cd "$TORCHTEXT_GIT_DIR"
			git checkout "$CFG_TORCHTEXT_TAG"
			git checkout --recurse-submodules "$CFG_TORCHTEXT_TAG"
			git submodule sync
			git submodule update --init --recursive
			git submodule status
		)
	fi
	echo
fi

# Clone the OpenCV repositories
echo "Cloning OpenCV $CFG_OPENCV_VERSION..."
if [[ ! -f "$PYTORCH_COMPILED" ]] && [[ ! -d "$OPENCV_GIT_DIR" ]]; then
	(
		set -x
		cd "$ENV_DIR"
		git clone https://github.com/opencv/opencv opencv
		git clone https://github.com/opencv/opencv_contrib opencv_contrib
		cd "$OPENCV_GIT_DIR"
		git checkout "$CFG_OPENCV_TAG"
		cd "$OPENCV_CONTRIB_GIT_DIR"
		git checkout "$CFG_OPENCV_TAG"
	)
fi
echo

# Unpack TensorRT
if [[ -n "$CFG_TENSORRT_URL" ]]; then
	echo "Unpacking TensorRT $CFG_TENSORRT_VERSION..."
	[[ ! -d "$MAIN_TENSORRT_DIR" ]] && mkdir "$MAIN_TENSORRT_DIR"
	if [[ ! -d "$TENSORRT_INSTALL_DIR" ]]; then
		echo "Unpacking: $TENSORRT_TAR"
		tar -xf "$TENSORRT_TAR" -C "$MAIN_TENSORRT_DIR"
		if [[ ! -d "$TENSORRT_INSTALL_DIR" ]]; then
			echo "TensorRT tar unpacking failed or unpacked to an unexpected directory name (should be $TENSORRT_DIRNAME): $TENSORRT_TAR"
			exit 1
		fi
	fi
	if ! grep -qFx "$CFG_CONDA_ENV" "$TENSORRT_ENVS_LIST" 2>/dev/null; then
		echo "$CFG_CONDA_ENV" >> "$TENSORRT_ENVS_LIST"
	fi
	echo
	echo "Creating TensorRT path management scripts..."
	read -r -d '' TENSORRT_ADD_PATH_CONTENTS << 'EOM' || true
#!/bin/bash
# Add TensorRT paths to the current environment
# Usage:
#   source #TENSORRT_INSTALL_DIR#/add_path.sh
# Check the results using:
#   echo "$TENSORRT_PATH"    # --> Custom variable specifying the (single) TensorRT installation path
#   echo "$PATH"             # --> For finding binaries to run
#   echo "$LIBRARY_PATH"     # --> For finding libraries to link at compile time
#   echo "$LD_LIBRARY_PATH"  # --> For finding shared libraries to link at runtime

# Ensure this script is being sourced not run
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
	echo "Error: This script should be sourced, not run!"
	exit 1
fi

# Ensure that we don't overwrite any existing bash functions
if type __PrependPath &>/dev/null; then
	echo "Error: __PrependPath function already exists in environment => Aborting script to avoid conflicts..."
	return 1
fi

# Heuristically check that no other TensorRT installations are currently on the path
search_path="$TENSORRT_PATH:$PATH:$LIBRARY_PATH:$LD_LIBRARY_PATH"
while read match; do
	if [[ "$match" != "/#TENSORRT_DIRNAME#/" ]]; then
		echo "Error: Another TensorRT installation (not #TENSORRT_DIRNAME#) is already detected on the path => Aborting..."
		echo
		echo "TENSORRT_PATH: $TENSORRT_PATH"
		echo "PATH: $PATH"
		echo "LIBRARY_PATH: $LIBRARY_PATH"
		echo "LD_LIBRARY_PATH: $LD_LIBRARY_PATH"
		return 1
	fi
done < <(egrep -oi "/TensorRT-[0-9]+\.[0-9]+\.[0-9]+(\.[0-9]+)?/" <<< "$search_path")

# Function to prepend an item to a path if it is not already there
function __PrependPath() { local __args __item; for __args in "${@:2}"; do [[ -n "${!1}" ]] && while IFS= read -r -d ':' __item; do [[ "$__item" == "$__args" ]] && continue 2; done <<< "${!1}:"; ([[ -n "${!1#:}" ]] || [[ -z "$__args" ]]) && __args+=':'; export "${1}"="$__args${!1}"; done; }

# Custom exported variables
export TENSORRT_PATH="#TENSORRT_INSTALL_DIR#"

# Add the required TensorRT directories to the environment paths
__PrependPath PATH "$TENSORRT_PATH/bin"
__PrependPath LD_LIBRARY_PATH "$TENSORRT_PATH/lib"

# Unset the function we have created
unset -f __PrependPath
# EOF
EOM
	read -r -d '' TENSORRT_REMOVE_PATH_CONTENTS << 'EOM' || true
#!/bin/bash
# Remove TensorRT paths to the current environment
# Usage:
#   source #TENSORRT_INSTALL_DIR#/remove_path.sh
# Check the results using:
#   echo "$TENSORRT_PATH"    # --> Custom variable specifying the (single) TensorRT installation path
#   echo "$PATH"             # --> For finding binaries to run
#   echo "$LIBRARY_PATH"     # --> For finding libraries to link at compile time
#   echo "$LD_LIBRARY_PATH"  # --> For finding shared libraries to link at runtime

# Ensure this script is being sourced (not run)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
	echo "Error: This script should be sourced, not run!"
	exit 1
fi

# Ensure that we don't overwrite any existing bash functions
if type __RemovePath &>/dev/null; then
	echo "Error: __RemovePath function already exists in environment => Aborting script to avoid conflicts..."
	return 1
fi

# Function to remove all instances of an item from a path
function __RemovePath() { local __item __args __path=; [[ -n "${!1}" ]] && while IFS= read -r -d ':' __item; do for __args in "${@:2}"; do [[ "$__item" == "$__args" ]] && continue 2; done; __path="$__path:$__item"; done <<< "${!1}:"; [[ "$__path" != ":" ]] && __path="${__path#:}"; export "${1}"="$__path"; }

# Custom exported variables
OUR_TENSORRT_PATH="#TENSORRT_INSTALL_DIR#"
[[ "$TENSORRT_PATH" == "$OUR_TENSORRT_PATH" ]] && unset TENSORRT_PATH

# Remove the required TensorRT directories from the environment paths
__RemovePath PATH "$OUR_TENSORRT_PATH/bin"
__RemovePath LD_LIBRARY_PATH "$OUR_TENSORRT_PATH/lib"

# Unset the function we have created
unset -f __RemovePath
# EOF
EOM
	TENSORRT_ADD_PATH_CONTENTS="${TENSORRT_ADD_PATH_CONTENTS//#TENSORRT_INSTALL_DIR#/$TENSORRT_INSTALL_DIR}"
	TENSORRT_ADD_PATH_CONTENTS="${TENSORRT_ADD_PATH_CONTENTS//#TENSORRT_DIRNAME#/$TENSORRT_DIRNAME}"
	TENSORRT_REMOVE_PATH_CONTENTS="${TENSORRT_REMOVE_PATH_CONTENTS//#TENSORRT_INSTALL_DIR#/$TENSORRT_INSTALL_DIR}"
	TENSORRT_ADD_PATH="$TENSORRT_INSTALL_DIR/add_path.sh"
	TENSORRT_REMOVE_PATH="$TENSORRT_INSTALL_DIR/remove_path.sh"
	echo "$TENSORRT_ADD_PATH_CONTENTS" > "$TENSORRT_ADD_PATH"
	echo "Created: $TENSORRT_ADD_PATH"
	echo "$TENSORRT_REMOVE_PATH_CONTENTS" > "$TENSORRT_REMOVE_PATH"
	echo "Created: $TENSORRT_REMOVE_PATH"
	echo
	echo "Compiling the TensorRT samples as a test..."
	if [[ -z "$CFG_QUICK" ]] && [[ ! -f "$TENSORRT_SAMPLES_COMPILED" ]]; then
		(
			cd "$TENSORRT_INSTALL_DIR/samples"
			sed -i 's|^\(\s*OUT_PATH\s*=\s*\$(ROOT_PATH)/bin\)$|\1tmp|' "$TENSORRT_INSTALL_DIR/samples/Makefile.config"
			if ! egrep -qx '\s*OUT_PATH\s*=\s*\$\(ROOT_PATH\)/bintmp' "$TENSORRT_INSTALL_DIR/samples/Makefile.config"; then
				echo "Failed to adjust output directory for TensorRT samples compilation"
				exit 1
			fi
			set +u
			source "$CUDA_INSTALL_DIR/add_path.sh"
			set -u
			export CUDA_INSTALL_DIR
			export CUDNN_INSTALL_DIR="$CUDA_INSTALL_DIR"
			export TRT_LIB_DIR="$TENSORRT_INSTALL_DIR/lib"
			export PROTOBUF_INSTALL_DIR=/usr/lib/x86_64-linux-gnu
			echo "make"
			time make  # Note: Not multiple jobs as the samples explicitly specify .NOTPARALLEL
			echo
			(
				echo "Preparing MNIST data..."
				if [[ ! -f "$TENSORRT_INSTALL_DIR/data/mnist/0.pgm" ]]; then
					cd "$TENSORRT_INSTALL_DIR/data/mnist"
					if [[ -f "$TENSORRT_INSTALL_DIR/data/mnist/download_pgms.py" ]]; then
						"$TENSORRT_INSTALL_DIR/data/mnist/download_pgms.py"
					elif [[ -f "$TENSORRT_INSTALL_DIR/data/mnist/generate_pgms.py" ]]; then
						wget -nc http://yann.lecun.com/exdb/mnist/train-images-idx3-ubyte.gz http://yann.lecun.com/exdb/mnist/train-labels-idx1-ubyte.gz http://yann.lecun.com/exdb/mnist/t10k-images-idx3-ubyte.gz http://yann.lecun.com/exdb/mnist/t10k-labels-idx1-ubyte.gz
						gunzip *.gz
						"$TENSORRT_INSTALL_DIR/data/mnist/generate_pgms.py"
						rm -f {train,t10k}-{images,labels}-*
					fi
					ls -1 "$TENSORRT_INSTALL_DIR/data/mnist"/*.pgm
				fi
				echo
				set +u
				source "$TENSORRT_INSTALL_DIR/add_path.sh"
				set -u
				cd "$TENSORRT_INSTALL_DIR/bintmp"
				echo "Running: $TENSORRT_INSTALL_DIR/bintmp/sample_mnist"
				"$TENSORRT_INSTALL_DIR/bintmp/sample_mnist"
				echo
				echo "Running: $TENSORRT_INSTALL_DIR/bintmp/sample_mnist_api"
				"$TENSORRT_INSTALL_DIR/bintmp/sample_mnist_api"
				echo
				echo "Running: $TENSORRT_INSTALL_DIR/bintmp/sample_onnx_mnist"
				"$TENSORRT_INSTALL_DIR/bintmp/sample_onnx_mnist"
				echo
				echo "Running: $TENSORRT_INSTALL_DIR/bintmp/sample_uff_mnist"
				"$TENSORRT_INSTALL_DIR/bintmp/sample_uff_mnist"
				echo
			)
			touch "$TENSORRT_SAMPLES_COMPILED"
			echo "Cleaning up TensorRT samples build..."
			make clean >/dev/null
			rm -rf "$TENSORRT_INSTALL_DIR/bintmp"
		)
	fi
	echo
fi

# Stop if stage limit reached
[[ "$CFG_STAGE" -eq 2 ]] && exit 0

#
# Stage 3
#

# Stage 3 uninstall
UNINSTALLER_COMMANDS="Commands to undo stage 3:"$'\n'"set +ux"
[[ "$CFG_CONDA_CREATE" == "1" ]] && UNINSTALLER_COMMANDS+=$'\n'"conda deactivate"$'\n'"conda env remove -n '$CFG_CONDA_ENV'"
[[ "$CFG_CLEAN_CONDA" == "1" ]] && UNINSTALLER_COMMANDS+=$'\n'"conda clean -y --all"
UNINSTALLER_COMMANDS+=$'\n'"set -ux"
add_uninstall_cmds "# $UNINSTALLER_COMMANDS"
echo "$UNINSTALLER_COMMANDS"
echo

# Create conda environment
echo "Creating conda environment..."
if [[ "$CFG_CONDA_CREATE" != "1" ]] || find "$(conda info --base)"/envs -mindepth 1 -maxdepth 1 -type d -printf "%f\n" | grep -Fqx "$CFG_CONDA_ENV"; then
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
if [[ -n "$CFG_TENSORRT_URL" ]]; then
	SOURCE_TENSORRT_ADD=$'\n'"source '$TENSORRT_INSTALL_DIR/add_path.sh'"
	SOURCE_TENSORRT_REMOVE=$'\n'"source '$TENSORRT_INSTALL_DIR/remove_path.sh'"
else
	SOURCE_TENSORRT_ADD=
	SOURCE_TENSORRT_REMOVE=
fi
cat << EOM > "$CONDA_ENV_DIR/etc/conda/activate.d/env_vars.sh"
#!/bin/sh
source '$CUDA_INSTALL_DIR/add_path.sh'$SOURCE_TENSORRT_ADD
# EOF
EOM
cat << EOM > "$CONDA_ENV_DIR/etc/conda/deactivate.d/env_vars.sh"
#!/bin/sh
source '$CUDA_INSTALL_DIR/remove_path.sh'$SOURCE_TENSORRT_REMOVE
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
	conda install $CFG_AUTO_YES cython
	conda install $CFG_AUTO_YES ceres-solver cmake ffmpeg freetype gflags glog gstreamer gst-plugins-base gst-plugins-good harfbuzz hdf5 jpeg libdc1394 libiconv libpng libtiff libva libwebp mkl mkl-include ninja numpy openjpeg pkgconfig setuptools six snappy tbb tbb-devel tbb4py tifffile  # For OpenCV
	[[ -n "$CFG_TENSORRT_URL" ]] && conda install $CFG_AUTO_YES numpy six setuptools onnx protobuf libprotobuf  # For TensorRT
	conda install $CFG_AUTO_YES astunparse cffi cmake future mkl mkl-include ninja numpy pillow pkgconfig pyyaml requests setuptools six typing typing_extensions libjpeg-turbo libpng magma-cuda"$(cut -d. -f'1 2' <<< "$CFG_CUDA_VERSION" | tr -d .)"  # For PyTorch
	[[ -n "$CFG_TORCHVISION_TAG" ]] && conda install $CFG_AUTO_YES typing_extensions numpy requests scipy scikit-learn-intelex  # For Torchvision
	[[ -n "$CFG_TORCHAUDIO_TAG" ]] && conda install $CFG_AUTO_YES numpy scipy scikit-learn-intelex kaldi_io  # For Torchaudio
	[[ -n "$CFG_TORCHTEXT_TAG" ]] && conda install $CFG_AUTO_YES tqdm numpy requests nltk spacy sacremoses  # For Torchtext
	conda install $CFG_AUTO_YES decorator appdirs mako numpy six platformdirs  # For pip packages
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
	set -u
	[[ -f "$CONDA_ENV_DIR/etc/conda/activate.d/libblas_mkl_activate.sh" ]] && chmod +x "$CONDA_ENV_DIR/etc/conda/activate.d/libblas_mkl_activate.sh"
	[[ -f "$CONDA_ENV_DIR/etc/conda/deactivate.d/libblas_mkl_deactivate.sh" ]] && chmod +x "$CONDA_ENV_DIR/etc/conda/deactivate.d/libblas_mkl_deactivate.sh"
	echo
	echo "Installing pip packages..."
	pip install --no-deps --no-cache-dir pycuda pytools
	echo
	if [[ -n "$CFG_TENSORRT_URL" ]]; then
		echo "Installing TensorRT..."
		CONDA_PYTHON_CODE="$(sed 's/^\([0-9]\+\)\.\([0-9]\+\).*$/\1\2/' <<< "$CFG_CONDA_PYTHON")"
		pip install --no-deps "$TENSORRT_INSTALL_DIR/python/$(tr "[:upper:]" "[:lower:]" <<< "$TENSORRT_DIRNAME")-cp$CONDA_PYTHON_CODE-"*.whl
		pip install --no-deps "$TENSORRT_INSTALL_DIR/uff/uff-"*.whl
		pip install --no-deps "$TENSORRT_INSTALL_DIR/graphsurgeon/graphsurgeon-"*.whl
		[[ -d "$TENSORRT_INSTALL_DIR/onnx_graphsurgeon" ]] && pip install --no-deps "$TENSORRT_INSTALL_DIR/onnx_graphsurgeon/onnx_graphsurgeon-"*.whl
		echo
	fi
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

# Stop if stage limit reached
[[ "$CFG_STAGE" -eq 3 ]] && exit 0

#
# Stage 4
#

# Variables
OPENCV_BUILD_DIR="$OPENCV_GIT_DIR/build"
OPENCV_PYTHON_STUB_DIR="$ENV_DIR/opencv-python-stub"

# Stage 4 uninstall
read -r -d '' UNINSTALLER_COMMANDS << EOM || true
Commands to undo stage 4:
set +ux
conda activate '$CFG_CONDA_ENV' && pip uninstall -y \$(pip list | grep -e "^opencv-" | cut -d' ' -f1 | tr $'\n' ' ') || true
set -ux
if [[ -d '$OPENCV_BUILD_DIR' ]]; then ( cd '$OPENCV_BUILD_DIR'; make uninstall || true; make clean || true; ) elif [[ -f '$OPENCV_GIT_DIR/install_manifest.txt' ]]; then echo 'You will need to check the install manifest and uninstall manually: $OPENCV_GIT_DIR/install_manifest.txt'; fi
rm -rf '$OPENCV_BUILD_DIR' '$OPENCV_GIT_DIR/.cache' '$OPENCV_PYTHON_STUB_DIR'
EOM
add_uninstall_cmds "# $UNINSTALLER_COMMANDS"
echo "$UNINSTALLER_COMMANDS"
echo

# Build OpenCV
echo "Building OpenCV $CFG_OPENCV_VERSION..."
if [[ ! -f "$PYTORCH_COMPILED" ]] && [[ ! -f "$CONDA_PREFIX/bin/opencv_version" ]]; then
	(
		[[ ! -d "$OPENCV_BUILD_DIR" ]] && mkdir "$OPENCV_BUILD_DIR"
		rm -rf "$OPENCV_BUILD_DIR"/* "$OPENCV_GIT_DIR/.cache"
		cd "$OPENCV_BUILD_DIR"
		set +u
		conda activate "$CFG_CONDA_ENV"
		set -u
		[[ "$CFG_OPENCV_HEADLESS" == "0" ]] && WITH_QT=ON || WITH_QT=OFF
		export CMAKE_PREFIX_PATH="$CONDA_PREFIX"
		cmake -DCMAKE_INSTALL_PREFIX="$CONDA_PREFIX" -DOPENCV_EXTRA_MODULES_PATH=../../opencv_contrib/modules -DCMAKE_BUILD_TYPE=Release -DCMAKE_CXX_STANDARD=14 -DBUILD_SHARED_LIBS=ON -DENABLE_CONFIG_VERIFICATION=ON -DOPENCV_ENABLE_NONFREE=ON -DENABLE_FAST_MATH=OFF -DBUILD_TESTS=OFF -DBUILD_PERF_TESTS=OFF -DBUILD_EXAMPLES=OFF -DBUILD_DOCS=OFF -DBUILD_opencv_apps=ON -DPYTHON_DEFAULT_EXECUTABLE="$CONDA_PREFIX/bin/python" -DPYTHON3_EXECUTABLE="$CONDA_PREFIX/bin/python" -DBUILD_opencv_python2=OFF -DBUILD_opencv_python3=ON -DBUILD_opencv_java=OFF -DWITH_MATLAB=OFF -DWITH_IMGCODEC_HDR=ON -DWITH_IMGCODEC_SUNRASTER=ON -DWITH_IMGCODEC_PXM=ON -DWITH_IMGCODEC_PFM=ON -DWITH_ADE=ON -DWITH_PNG=ON -DWITH_JPEG=ON -DWITH_TIFF=ON -DWITH_WEBP=ON -DWITH_OPENJPEG=ON -DWITH_JASPER=OFF -DWITH_OPENEXR=ON -DBUILD_OPENEXR=ON -DWITH_TESSERACT=OFF -DWITH_V4L=ON -DWITH_FFMPEG=ON -DWITH_GSTREAMER=ON -DWITH_1394=ON -DWITH_OPENGL=ON -DOpenGL_GL_PREFERENCE=LEGACY -DWITH_VTK=OFF -DWITH_GTK=OFF -DWITH_QT="$WITH_QT" -DWITH_PTHREADS_PF=ON -DWITH_TBB=ON -DWITH_OPENMP=ON -DWITH_CUDA=ON -DCUDA_GENERATION=Auto -DCUDA_FAST_MATH=OFF -DWITH_CUDNN=ON -DWITH_CUFFT=ON -DWITH_CUBLAS=ON -DWITH_OPENCL=ON -DWITH_OPENCLAMDFFT=OFF -DWITH_OPENCLAMDBLAS=OFF -DWITH_VA=ON -DWITH_VA_INTEL=ON -DWITH_PROTOBUF=ON -DBUILD_PROTOBUF=ON -DPROTOBUF_UPDATE_FILES=OFF -DOPENCV_DNN_CUDA=ON -DOPENCV_DNN_OPENCL=ON -DWITH_EIGEN=ON -DWITH_LAPACK=ON -DWITH_QUIRC=ON $CFG_OPENCV_CMAKE ..
		time make -j"$(nproc)"
		echo
		echo "Checking which external libraries the build products dynamically link to..."
		find "$OPENCV_BUILD_DIR" -type f -executable -exec ldd {} \; 2>/dev/null | grep -vF "$OPENCV_BUILD_DIR/" | grep -vF "$CONDA_ENV_DIR/" | grep -vF "$CUDA_INSTALL_DIR/" | sed 's/ (0x[0-9a-fx]\+)//g' | sort | uniq
		echo
		echo "Uninstalling any existing OpenCV from conda environment..."
		pip uninstall $CFG_AUTO_YES $(pip list | grep -e "^opencv-" | cut -d' ' -f1 | tr $'\n' ' ') || true
		echo
		echo "Installing OpenCV into conda environment..."
		make install
		cp "$OPENCV_BUILD_DIR/install_manifest.txt" "$OPENCV_GIT_DIR/install_manifest.txt"
		echo
		echo "Running opencv_version script and showing build information..."
		"$CONDA_PREFIX/bin/opencv_version"
		python -c "import cv2; print('Found Python OpenCV', cv2.__version__); print(cv2.getBuildInformation())"
	)
fi
echo

# Clean the OpenCV build
if [[ "$CFG_CLEAN_WORKDIR" -ge 1 ]]; then
	echo "Cleaning up OpenCV build..."
	rm -rf "$OPENCV_BUILD_DIR" "$OPENCV_GIT_DIR/.cache"
	echo
fi

# Install OpenCV stub package if required
echo "Building OpenCV python stub package for version $CFG_OPENCV_VERSION..."
if [[ ! -f "$PYTORCH_COMPILED" ]]; then
	[[ ! -d "$OPENCV_PYTHON_STUB_DIR" ]] && mkdir "$OPENCV_PYTHON_STUB_DIR"
	if find "$OPENCV_PYTHON_STUB_DIR" -maxdepth 1 -type f -name "opencv_python-*.whl" -exec false {} +; then
		(
			[[ ! -d "$OPENCV_PYTHON_STUB_DIR/opencv-python" ]] && mkdir "$OPENCV_PYTHON_STUB_DIR/opencv-python"
			cat << EOM > "$OPENCV_PYTHON_STUB_DIR/setup.py"
from setuptools import setup
setup(
	name='opencv-python',
	version='$CFG_OPENCV_VERSION',
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
	echo "Installing OpenCV python stub package for version $CFG_OPENCV_VERSION..."
	OPENCV_STUB_WHEEL="$(find "$OPENCV_PYTHON_STUB_DIR" -maxdepth 1 -type f -name "opencv_python-*.whl" -print -quit)"
	if [[ -z "$OPENCV_STUB_WHEEL" ]]; then
		echo "Failed to find output OpenCV stub wheel"
		exit 1
	fi
	if ! pip show "opencv-python" &>/dev/null; then
		pip install "$OPENCV_STUB_WHEEL"
	fi
fi
echo

# Clean the OpenCV stub package build
if [[ "$CFG_CLEAN_WORKDIR" -ge 1 ]]; then
	echo "Cleaning up OpenCV stub package build..."
	rm -rf "$OPENCV_PYTHON_STUB_DIR"/{build,*.whl,*.egg-info}
	echo
fi

# Stop if stage limit reached
[[ "$CFG_STAGE" -eq 4 ]] && exit 0

#
# Stage 5
#

# Variables
PYTORCH_BUILD_DIR="$PYTORCH_GIT_DIR/build"

# Stage 5 uninstall
read -r -d '' UNINSTALLER_COMMANDS << EOM || true
Commands to undo stage 5:
set +ux
conda activate '$CFG_CONDA_ENV' && ( pip uninstall -y torch || true; [[ -d '$PYTORCH_GIT_DIR' ]] && cd '$PYTORCH_GIT_DIR' && python setup.py clean || true; )
set -ux
rm -rf '$PYTORCH_BUILD_DIR' '$PYTORCH_GIT_DIR/torch.egg-info'
EOM
add_uninstall_cmds "# $UNINSTALLER_COMMANDS"
echo "$UNINSTALLER_COMMANDS"
echo

# Build PyTorch
echo "Building PyTorch $CFG_PYTORCH_VERSION..."
if [[ ! -f "$PYTORCH_COMPILED" ]] && find "$CONDA_ENV_DIR/lib" -type d -path "*/lib/python*/site-packages/torch" -exec false {} +; then
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
		export USE_SYSTEM_BIND11=OFF pybind11_PREFER_third_party=ON
		if [[ -n "$CFG_TENSORRT_URL" ]] && [[ "$CFG_TENSORRT_PYTORCH" == 1 ]]; then
			export USE_TENSORRT=ON
			export TENSORRT_ROOT="$TENSORRT_INSTALL_DIR"
		else
			export USE_TENSORRT=OFF
		fi
		RETRIED=
		while ! time python setup.py build; do
			echo
			if [[ "$CFG_AUTO_ANSWER" == "0" ]]; then
				response=
				echo "Known reasons for a required build restart:"
				echo " - PyTorch 1.10 introduced 'fatal error: ATen/core/TensorBody.h: No such file or directory' due to a build target ordering/dependency problem"
				echo
				read -p "Try build again (y/N)? " response 2>&1
				response="${response,,}"
				[[ "$response" != "y" ]] && exit 1
				echo
			elif [[ -n "$RETRIED" ]]; then
				exit 1
			fi
			RETRIED=true
		done
		echo
		echo "Checking which external libraries the build products dynamically link to..."
		find "$PYTORCH_BUILD_DIR" -type f -executable -exec ldd {} \; 2>/dev/null | grep -vF "$PYTORCH_BUILD_DIR/" | grep -vF "$CONDA_ENV_DIR/" | grep -vF "$CUDA_INSTALL_DIR/" | sed 's/ (0x[0-9a-fx]\+)//g' | sort | uniq
		echo
		echo "Uninstalling any existing PyTorch from conda environment..."
		pip uninstall $CFG_AUTO_YES torch || true
		echo
		echo "Installing PyTorch into conda environment..."
		python setup.py install
		echo
		echo "Checking PyTorch is available in python..."
		cd "$ENV_DIR"
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
		if [[ -n "$CFG_TENSORRT_URL" ]] && [[ "$CFG_TENSORRT_PYTORCH" == 1 ]]; then
			echo
			echo "Checking PyTorch TensorRT is available in python..."
			python - << EOM
from caffe2.python import workspace
from caffe2.python.trt.transform import convert_onnx_model_to_trt_op, transform_caffe2_net
if workspace.C.use_trt:
	print("TensorRT is supported within PyTorch/Caffe2")
else:
	print("No TensorRT support in PyTorch/Caffe2")
EOM
		fi
	)
fi
echo

# Clean the PyTorch build
if [[ "$CFG_CLEAN_WORKDIR" -ge 1 ]]; then
	echo "Cleaning up PyTorch build..."
	rm -rf "$PYTORCH_BUILD_DIR"
	echo
fi

# Stop if stage limit reached
[[ "$CFG_STAGE" -eq 5 ]] && exit 0

#
# Stage 6
#

# Variables
TORCHVISION_BUILD_DIR="$TORCHVISION_GIT_DIR/build"

# Stage 6 uninstall
if [[ -n "$CFG_TORCHVISION_TAG" ]]; then
	read -r -d '' UNINSTALLER_COMMANDS << EOM || true
Commands to undo stage 6:
set +ux
conda activate '$CFG_CONDA_ENV' && ( pip uninstall -y torchvision || true; [[ -d '$TORCHVISION_GIT_DIR' ]] && cd '$TORCHVISION_GIT_DIR' && python setup.py clean || true; )
set -ux
rm -rf '$TORCHVISION_BUILD_DIR'
EOM
	add_uninstall_cmds "# $UNINSTALLER_COMMANDS"
	echo "$UNINSTALLER_COMMANDS"
	echo
fi

# Build Torchvision
if [[ -n "$CFG_TORCHVISION_TAG" ]]; then
	echo "Building Torchvision $CFG_TORCHVISION_VERSION..."
	if [[ ! -f "$PYTORCH_COMPILED" ]] && find "$CONDA_ENV_DIR/lib" -type d -path "*/lib/python*/site-packages/torchvision-*.egg" -exec false {} +; then
		(
			[[ ! -d "$TORCHVISION_BUILD_DIR" ]] && mkdir "$TORCHVISION_BUILD_DIR"
			rm -rf "$TORCHVISION_BUILD_DIR"/*
			cd "$TORCHVISION_GIT_DIR"
			set +u
			conda activate "$CFG_CONDA_ENV"
			set -u
			export CMAKE_PREFIX_PATH="$CONDA_PREFIX"
			export FORCE_CUDA=ON
			RETRIED=
			while ! time python setup.py build; do
				echo
				if [[ "$CFG_AUTO_ANSWER" == "0" ]]; then
					response=
					read -p "Try build again (y/N)? " response 2>&1
					response="${response,,}"
					[[ "$response" != "y" ]] && exit 1
					echo
				elif [[ -n "$RETRIED" ]]; then
					exit 1
				fi
				RETRIED=true
			done
			echo
			echo "Checking which external libraries the build products dynamically link to..."
			find "$TORCHVISION_BUILD_DIR" -type f -executable -exec ldd {} \; 2>/dev/null | grep -vF "$TORCHVISION_BUILD_DIR/" | grep -vF "$CONDA_ENV_DIR/" | grep -vF "$CUDA_INSTALL_DIR/" | sed 's/ (0x[0-9a-fx]\+)//g' | sort | uniq
			echo
			echo "Uninstalling any existing Torchvision from conda environment..."
			pip uninstall $CFG_AUTO_YES torchvision || true
			echo
			echo "Installing Torchvision into conda environment..."
			python setup.py install
		)
	fi
	echo
	if [[ "$CFG_CLEAN_WORKDIR" -ge 1 ]]; then
		echo "Cleaning up Torchvision build..."
		rm -rf "$TORCHVISION_BUILD_DIR"
		echo
	fi
fi

# Stop if stage limit reached
[[ "$CFG_STAGE" -eq 6 ]] && exit 0

#
# Stage 7
#

# Variables
TORCHAUDIO_BUILD_DIR="$TORCHAUDIO_GIT_DIR/build"

# Stage 7 uninstall
if [[ -n "$CFG_TORCHAUDIO_TAG" ]]; then
	read -r -d '' UNINSTALLER_COMMANDS << EOM || true
Commands to undo stage 7:
set +ux
conda activate '$CFG_CONDA_ENV' && ( pip uninstall -y torchaudio || true; [[ -d '$TORCHAUDIO_GIT_DIR' ]] && cd '$TORCHAUDIO_GIT_DIR' && python setup.py clean || true; )
set -ux
rm -rf '$TORCHAUDIO_BUILD_DIR'
EOM
	add_uninstall_cmds "# $UNINSTALLER_COMMANDS"
	echo "$UNINSTALLER_COMMANDS"
	echo
fi

# Build Torchaudio
if [[ -n "$CFG_TORCHAUDIO_TAG" ]]; then
	echo "Building Torchaudio $CFG_TORCHAUDIO_VERSION..."
	if [[ ! -f "$PYTORCH_COMPILED" ]] && find "$CONDA_ENV_DIR/lib" -type d -path "*/lib/python*/site-packages/torchaudio-*.egg" -exec false {} +; then
		(
			[[ ! -d "$TORCHAUDIO_BUILD_DIR" ]] && mkdir "$TORCHAUDIO_BUILD_DIR"
			rm -rf "$TORCHAUDIO_BUILD_DIR"/*
			cd "$TORCHAUDIO_GIT_DIR"
			set +u
			conda activate "$CFG_CONDA_ENV"
			if [[ -n "$CFG_TENSORRT_URL" ]]; then
				source "$TENSORRT_INSTALL_DIR/add_path.sh"
				export TENSORRT_ROOT="$TENSORRT_INSTALL_DIR"
			fi
			set -u
			export CMAKE_PREFIX_PATH="$CONDA_PREFIX"
			export USE_CUDA=ON BUILD_SOX=ON
			RETRIED=
			while ! time python setup.py build; do
				echo
				if [[ "$CFG_AUTO_ANSWER" == "0" ]]; then
					response=
					read -p "Try build again (y/N)? " response 2>&1
					response="${response,,}"
					[[ "$response" != "y" ]] && exit 1
					echo
				elif [[ -n "$RETRIED" ]]; then
					exit 1
				fi
				RETRIED=true
			done
			echo
			echo "Checking which external libraries the build products dynamically link to..."
			find "$TORCHAUDIO_BUILD_DIR" -type f -executable -exec ldd {} \; 2>/dev/null | grep -vF "$TORCHAUDIO_BUILD_DIR/" | grep -vF "$CONDA_ENV_DIR/" | grep -vF "$CUDA_INSTALL_DIR/" | sed 's/ (0x[0-9a-fx]\+)//g' | sort | uniq
			echo
			echo "Uninstalling any existing Torchaudio from conda environment..."
			pip uninstall $CFG_AUTO_YES torchaudio || true
			echo
			echo "Installing Torchaudio into conda environment..."
			python setup.py install
		)
	fi
	echo
	if [[ "$CFG_CLEAN_WORKDIR" -ge 1 ]]; then
		echo "Cleaning up Torchaudio build..."
		rm -rf "$TORCHAUDIO_BUILD_DIR"
		echo
	fi
fi

# Stop if stage limit reached
[[ "$CFG_STAGE" -eq 7 ]] && exit 0

#
# Stage 8
#

# Variables
TORCHTEXT_BUILD_DIR="$TORCHTEXT_GIT_DIR/build"

# Stage 8 uninstall
if [[ -n "$CFG_TORCHTEXT_TAG" ]]; then
	read -r -d '' UNINSTALLER_COMMANDS << EOM || true
Commands to undo stage 8:
set +ux
conda activate '$CFG_CONDA_ENV' && ( pip uninstall -y torchtext || true; [[ -d '$TORCHTEXT_GIT_DIR' ]] && cd '$TORCHTEXT_GIT_DIR' && python setup.py clean || true; )
set -ux
rm -rf '$TORCHTEXT_BUILD_DIR'
EOM
	add_uninstall_cmds "# $UNINSTALLER_COMMANDS"
	echo "$UNINSTALLER_COMMANDS"
	echo
fi

# Build Torchtext
if [[ -n "$CFG_TORCHTEXT_TAG" ]]; then
	echo "Building Torchtext $CFG_TORCHTEXT_VERSION..."
	if [[ ! -f "$PYTORCH_COMPILED" ]] && find "$CONDA_ENV_DIR/lib" -type d -path "*/lib/python*/site-packages/torchtext-*.egg" -exec false {} +; then
		(
			[[ ! -d "$TORCHTEXT_BUILD_DIR" ]] && mkdir "$TORCHTEXT_BUILD_DIR"
			rm -rf "$TORCHTEXT_BUILD_DIR"/*
			cd "$TORCHTEXT_GIT_DIR"
			set +u
			conda activate "$CFG_CONDA_ENV"
			set -u
			export CMAKE_PREFIX_PATH="$CONDA_PREFIX"
			RETRIED=
			while ! time python setup.py build; do
				echo
				if [[ "$CFG_AUTO_ANSWER" == "0" ]]; then
					response=
					read -p "Try build again (y/N)? " response 2>&1
					response="${response,,}"
					[[ "$response" != "y" ]] && exit 1
					echo
				elif [[ -n "$RETRIED" ]]; then
					exit 1
				fi
				RETRIED=true
			done
			echo
			echo "Checking which external libraries the build products dynamically link to..."
			find "$TORCHTEXT_BUILD_DIR" -type f -executable -exec ldd {} \; 2>/dev/null | grep -vF "$TORCHTEXT_BUILD_DIR/" | grep -vF "$CONDA_ENV_DIR/" | grep -vF "$CUDA_INSTALL_DIR/" | sed 's/ (0x[0-9a-fx]\+)//g' | sort | uniq
			echo
			echo "Uninstalling any existing Torchtext from conda environment..."
			pip uninstall $CFG_AUTO_YES torchtext || true
			echo
			echo "Installing Torchtext into conda environment..."
			python setup.py install
		)
	fi
	echo
	if [[ "$CFG_CLEAN_WORKDIR" -ge 1 ]]; then
		echo "Cleaning up Torchtext build..."
		rm -rf "$TORCHTEXT_BUILD_DIR"
		echo
	fi
fi

# Stop if stage limit reached
[[ "$CFG_STAGE" -eq 8 ]] && exit 0

#
# Stage 9
#

# Stage 9 uninstall
read -r -d '' UNINSTALLER_COMMANDS << EOM || true
Commands to undo stage 9:
rm -rf '$PYTORCH_COMPILED'
EOM
add_uninstall_cmds "# $UNINSTALLER_COMMANDS"
echo "$UNINSTALLER_COMMANDS"
echo

# Mark PyTorch as compiled
[[ ! -f "$PYTORCH_COMPILED" ]] && touch "$PYTORCH_COMPILED"

# Clean up installers
if [[ "$CFG_CLEAN_INSTALLERS" == "1" ]]; then
	echo "Cleaning up installers..."
	[[ -n "$CFG_TENSORRT_URL" ]] && rm -rf "$TENSORRT_TAR"
	rmdir --ignore-fail-on-non-empty "$INSTALLERS_DIR" 2>/dev/null || true
	echo
fi

# Clean up local working directory
if [[ "$CFG_CLEAN_WORKDIR" -ge 2 ]]; then
	echo "Cleaning local working directory..."
	find "$ENV_DIR" -mindepth 1 -not -name "$(basename "$PYTORCH_COMPILED")" -prune -exec rm -rf {} +
	echo
fi

# Stop if stage limit reached
[[ "$CFG_STAGE" -eq 9 ]] && exit 0

#
# Finish
#

# Signal that the script completely finished
echo "Finished PyTorch installation into conda env $CFG_CONDA_ENV"
echo

# EOF
