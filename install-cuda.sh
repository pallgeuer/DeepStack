#!/bin/bash
# Install an isolated CUDA/cuDNN stack

# Use bash strict mode
set -euo pipefail

# Retrieve the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

#
# Configuration
#

# Whether to stop after a particular stage
CFG_STAGE="${CFG_STAGE:-0}"

# Whether to skip installation steps that are not strictly necessary in order to save time
CFG_QUICK="${CFG_QUICK:-}"

# Root directory to use for downloading and compiling libraries and storing files in the process of installation
CFG_ROOT_DIR="${CFG_ROOT_DIR:-$SCRIPT_DIR}"

# Name and path of directory to install CUDA into (must NOT exist yet, and name must be unique on the system)
CFG_CUDA_NAME="${CFG_CUDA_NAME:-cuda-$CFG_CUDA_VERSION}"
CFG_CUDA_LOCATION="${CFG_CUDA_LOCATION:-/usr/local}"

# Maximum GCC major compiler version to use (if specified, try: grep "#error" /usr/local/cuda-X.X/targets/x86_64-linux/include/crt/host_config.h)
CFG_MAX_GCC_VERSION="${CFG_MAX_GCC_VERSION:-}"

# CUDA toolkit version and URL to use (https://developer.nvidia.com/cuda-toolkit-archive -> CUDA Toolkit X.X -> Linux -> x86_64 -> Ubuntu -> UU.04 -> runfile (local))
# Example: CFG_CUDA_VERSION=10.1
# Example: CFG_CUDA_URL='http://developer.download.nvidia.com/compute/cuda/10.1/Prod/local_installers/cuda_10.1.243_418.87.00_linux.run'

# CUDA toolkit patch URLs to use (https://developer.nvidia.com/cuda-toolkit-archive -> CUDA Toolkit X.X -> Linux -> x86_64 -> Ubuntu -> UU.04 -> runfile (local))
CFG_CUDA_PATCH_URLS="${CFG_CUDA_PATCH_URLS:-}"

# CUDA samples version and URL (tag should be one of these: https://github.com/NVIDIA/cuda-samples/tags)
CFG_CUDA_SAMPLES_TAG="${CFG_CUDA_SAMPLES_TAG:-v$CFG_CUDA_VERSION}"
CFG_CUDA_SAMPLES_VERSION="${CFG_CUDA_SAMPLES_VERSION:-${CFG_CUDA_SAMPLES_TAG#v}}"

# cuDNN version and URL to use (https://developer.nvidia.com/rdp/cudnn-download OR https://developer.nvidia.com/rdp/cudnn-archive -> cuDNN vY.Y.Y for CUDA X.X -> cuDNN Library / Local Installer for Linux x86_64 (right-click) -> Copy link address, should be *.tar.xz or *.tgz)
# Example: CFG_CUDNN_VERSION=7.6.5
# Example: CFG_CUDNN_URL='https://developer.nvidia.com/compute/machine-learning/cudnn/secure/7.6.5.32/Production/10.1_20191031/cudnn-10.1-linux-x64-v7.6.5.32.tgz'

# Whether to clean (post-installation) the downloaded installers (uninstaller always cleans) and local working directory (0 = Do not clean, 1 = Clean build products, 2 = Clean everything)
CFG_CLEAN_INSTALLERS="${CFG_CLEAN_INSTALLERS:-1}"
CFG_CLEAN_WORKDIR="${CFG_CLEAN_WORKDIR:-2}"

# Enter the root directory
cd "$CFG_ROOT_DIR"

# Clean up configuration variables
[[ "$CFG_STAGE" -le 0 ]] 2>/dev/null && CFG_STAGE=0
CFG_ROOT_DIR="$(pwd)"
CFG_CUDA_URL="${CFG_CUDA_URL%/}"
CFG_CUDNN_URL="${CFG_CUDNN_URL%/}"
CFG_CUDA_LOCATION="${CFG_CUDA_LOCATION%/}"
[[ "$CFG_CLEAN_INSTALLERS" != "1" ]] && CFG_CLEAN_INSTALLERS="0"
[[ "$CFG_CLEAN_WORKDIR" != "2" ]] && [[ "$CFG_CLEAN_WORKDIR" != "1" ]] && CFG_CLEAN_WORKDIR="0"

# Display the configuration
echo
echo "CFG_STAGE = $CFG_STAGE"
echo "CFG_QUICK = $CFG_QUICK"
echo "CFG_ROOT_DIR = $CFG_ROOT_DIR"
echo "CFG_CUDA_VERSION = $CFG_CUDA_VERSION"
echo "CFG_CUDA_URL = $CFG_CUDA_URL"
echo "CFG_CUDA_PATCH_URLS = $CFG_CUDA_PATCH_URLS"
echo "CFG_CUDA_SAMPLES_TAG = $CFG_CUDA_SAMPLES_TAG"
echo "CFG_CUDA_SAMPLES_VERSION = $CFG_CUDA_SAMPLES_VERSION"
echo "CFG_CUDNN_VERSION = $CFG_CUDNN_VERSION"
echo "CFG_CUDNN_URL = $CFG_CUDNN_URL"
echo "CFG_CUDA_NAME = $CFG_CUDA_NAME"
echo "CFG_CUDA_LOCATION = $CFG_CUDA_LOCATION"
echo "CFG_MAX_GCC_VERSION = $CFG_MAX_GCC_VERSION"
echo "CFG_CLEAN_INSTALLERS = $CFG_CLEAN_INSTALLERS"
echo "CFG_CLEAN_WORKDIR = $CFG_CLEAN_WORKDIR"
echo
read -n 1 -p "Continue [ENTER] "
echo

#
# Installation
#

# Signal that the script is starting
echo "Starting CUDA stack installation..."
echo

# Dependent variables
if [[ "$CFG_MAX_GCC_VERSION" -gt 0 ]] && [[ ! -v CC ]] && [[ ! -v CXX ]] && [[ "$(c++ --version 2>/dev/null | head -n1 | cut -d' ' -f1)" == "c++" ]] && [[ "$(c++ -dumpversion)" -gt "$CFG_MAX_GCC_VERSION" ]]; then
	GCC_PATH="/usr/bin/gcc-$CFG_MAX_GCC_VERSION"
	GXX_PATH="/usr/bin/g++-$CFG_MAX_GCC_VERSION"
	if [[ ! -f "$GCC_PATH" ]] || [[ ! -f "$GXX_PATH" ]]; then
		echo "The following GCC binaries (or older) are required for this CUDA version, but cannot be found:"
		echo "$GCC_PATH"
		echo "$GXX_PATH"
		exit 1
	fi
else
	GCC_PATH=
	GXX_PATH=
fi

# Initialise uninstaller script
UNINSTALLERS_DIR="$CFG_ROOT_DIR/Uninstallers"
UNINSTALLER_SCRIPT="$UNINSTALLERS_DIR/uninstall-$CFG_CUDA_NAME.sh"
echo "Creating uninstaller script: $UNINSTALLER_SCRIPT"
[[ ! -d "$UNINSTALLERS_DIR" ]] && mkdir "$UNINSTALLERS_DIR"
read -r -d '' UNINSTALLER_HEADER << EOM || true
#!/bin/bash
# Uninstall $CFG_CUDA_NAME

# Use bash strict mode
set -xeuo pipefail
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
sudo apt install libfreeimage3 libfreeimage-dev
sudo apt install libvulkan1 libvulkan-dev
sudo apt install libglfw3 libglfw3-dev
sudo apt install g++ freeglut3-dev build-essential libx11-dev libxmu-dev libxi-dev libglu1-mesa libglu1-mesa-dev
sudo apt install zlib1g
echo

#
# Stage 1
#

# Variables
INSTALLERS_DIR="$CFG_ROOT_DIR/Installers"
CUDA_RUNFILE="$INSTALLERS_DIR/${CFG_CUDA_URL##*/}"
CUDA_PATCH_URLS=($CFG_CUDA_PATCH_URLS)
CUDA_PATCH_RUNFILES=()
for CUDA_PATCH_URL in "${CUDA_PATCH_URLS[@]}"; do
	CUDA_PATCH_RUNFILES+=("$INSTALLERS_DIR/${CUDA_PATCH_URL##*/}")
done
CUDNN_TAR="$INSTALLERS_DIR/${CFG_CUDNN_URL##*/}"
MAIN_CUDA_DIR="$CFG_ROOT_DIR/CUDA"
LOCAL_CUDA_DIR="$MAIN_CUDA_DIR/$CFG_CUDA_NAME"
CUDA_INSTALL_DIR="$CFG_CUDA_LOCATION/$CFG_CUDA_NAME"

# Stage 1 uninstall
CUDA_PATCH_RUNFILES_QUOTED=
for CUDA_PATCH_RUNFILE in "${CUDA_PATCH_RUNFILES[@]}"; do
	CUDA_PATCH_RUNFILES_QUOTED+="'$CUDA_PATCH_RUNFILE' "
done
read -r -d '' UNINSTALLER_COMMANDS << EOM || true
Commands to undo stage 1:
rm -rf '$CUDA_RUNFILE' $CUDA_PATCH_RUNFILES_QUOTED'$CUDNN_TAR'
rmdir --ignore-fail-on-non-empty '$INSTALLERS_DIR' || true
EOM
add_uninstall_cmds "# $UNINSTALLER_COMMANDS"
echo "$UNINSTALLER_COMMANDS"
echo

# Download installers
echo "Downloading installers..."
[[ ! -d "$INSTALLERS_DIR" ]] && mkdir "$INSTALLERS_DIR"
echo
if [[ ! -d "$LOCAL_CUDA_DIR" ]]; then
	echo "Downloading CUDA $CFG_CUDA_VERSION..."
	[[ ! -f "$CUDA_RUNFILE" ]] && wget "$CFG_CUDA_URL" -P "$INSTALLERS_DIR"
	echo
	for i in "${!CUDA_PATCH_URLS[@]}"; do
		CUDA_PATCH_URL="${CUDA_PATCH_URLS[$i]}"
		CUDA_PATCH_RUNFILE="${CUDA_PATCH_RUNFILES[$i]}"
		echo "Downloading CUDA patch '$(basename "$CUDA_PATCH_RUNFILE")'..."
		[[ ! -f "$CUDA_PATCH_RUNFILE" ]] && wget "$CUDA_PATCH_URL" -P "$INSTALLERS_DIR"
		echo
	done
fi
if [[ -z "$(find -H "$CUDA_INSTALL_DIR/lib64" -type f -name "libcudnn*")" ]]; then
	echo "Downloading cuDNN $CFG_CUDNN_VERSION..."
	if [[ ! -f "$CUDNN_TAR" ]]; then
		echo "Please log in with your NVIDIA account and don't close the browser..."
		xdg-open 'https://www.nvidia.com/en-us/account' || echo "xdg-open failed: Please manually perform the requested action"
		read -n 1 -p "Press enter when you have done that [ENTER] "
		echo "Opening download URL: $CFG_CUDNN_URL"
		echo "Please save tar to: $CUDNN_TAR"
		xdg-open "$CFG_CUDNN_URL" || echo "xdg-open failed: Please manually perform the requested action"
		read -n 1 -p "Press enter when it has finished downloading [ENTER] "
		if [[ ! -f "$CUDNN_TAR" ]]; then
			echo "File does not exist: $CUDNN_TAR"
			exit 1
		fi
	fi
	echo
fi

# Stop if stage limit reached
[[ "$CFG_STAGE" -eq 1 ]] && exit 0

#
# Stage 2
#

# Variables
LOCAL_CUDA_SYSTEM_DIR="$LOCAL_CUDA_DIR/system"
LOCAL_CUDNN_DIR="$LOCAL_CUDA_DIR/cuDNN-$CFG_CUDNN_VERSION"
CUDA_SAMPLES_COMPILED="$LOCAL_CUDA_DIR/samples_compiled"

# Stage 2 uninstall
UNINSTALLER_COMMANDS='Commands to undo stage 2:'$'\n''(set +x; if [[ -x '"'$CUDA_INSTALL_DIR/bin/cuda-uninstaller'"' ]] && [[ -n "$(find /var/log/nvidia/.uninstallManifests -type f -name "uninstallManifest-*" -exec grep -F '"'$CUDA_INSTALL_DIR/'"' {} \+)" ]]; then sudo '"'$CUDA_INSTALL_DIR/bin/cuda-uninstaller'"'; else echo "Did not call CUDA uninstaller as no matching uninstaller/manifest was found"; fi;)'
read -r -d '' UNINSTALLER_COMMANDS_EXTRA << EOM || true
sudo rm -rf '$CUDA_INSTALL_DIR' '$LOCAL_CUDA_SYSTEM_DIR'
rm -rf '$LOCAL_CUDA_DIR' '$LOCAL_CUDNN_DIR'
rmdir --ignore-fail-on-non-empty '$MAIN_CUDA_DIR' || true
EOM
UNINSTALLER_COMMANDS="$UNINSTALLER_COMMANDS"$'\n'"$UNINSTALLER_COMMANDS_EXTRA"
add_uninstall_cmds "# $UNINSTALLER_COMMANDS"
echo "$UNINSTALLER_COMMANDS"
echo

# Install CUDA toolkit
echo "Installing CUDA toolkit $CFG_CUDA_VERSION..."
[[ ! -d "$MAIN_CUDA_DIR" ]] && mkdir "$MAIN_CUDA_DIR"
if [[ ! -d "$LOCAL_CUDA_DIR" ]]; then
	mkdir "$LOCAL_CUDA_DIR"
	echo
	echo "Please perform the following actions in the CUDA installer:"
	echo " - Existing driver found: Select 'Continue'"
	echo " - EULA: Type 'accept'"
	echo " - Driver: Deselect"
	echo " - CUDA Toolkit: Press 'a' and deselect all"
	echo " - CUDA Documentation: Deselect"
	echo " - Select Install"
	echo
	read -n 1 -p "Continue [ENTER] "
	echo
	sudo rm -rf /var/log/cuda-installer.log
	sh "$CUDA_RUNFILE" --help |& grep -q -- "--samplespath=" && CUDA_SAMPLES_CMDS=(--samples --samplespath="$LOCAL_CUDA_DIR") || CUDA_SAMPLES_CMDS=()
	sudo sh "$CUDA_RUNFILE" --toolkit --toolkitpath="$CUDA_INSTALL_DIR" "${CUDA_SAMPLES_CMDS[@]}" --librarypath="$LOCAL_CUDA_SYSTEM_DIR" --no-man-page --override
	echo
	echo -e "\033[1;32mYou can ignore the PATH / LD_LIBRARY_PATH advice above, and not worry about 'Incomplete installation"'!'"' as you should already have manually installed your own NVIDIA driver (see README.md)\033[0m"
	echo
	echo "Checking the installation log for anything suspicious..."
	grep -Ei "\[(WARN|WARNING|ERROR)\]" /var/log/cuda-installer.log || true
	grep -Ei " (installed|created directory)" /var/log/cuda-installer.log | grep -Fv " $CUDA_INSTALL_DIR/" | grep -Fv " $LOCAL_CUDA_SYSTEM_DIR/" | grep -Fv "$LOCAL_CUDA_DIR/" | grep -Fv /var/log/nvidia/.uninstallManifests/ || true
	CUDA_LD_SO_CONF="$(grep -Eo "/etc/ld\.so\.conf\.d/cuda-.*.conf" /var/log/cuda-installer.log)"
	echo
	for CUDA_PATCH_RUNFILE in "${CUDA_PATCH_RUNFILES[@]}"; do
		echo "Please perform the following actions in the CUDA patch '$(basename "$CUDA_PATCH_RUNFILE")' installer:"
		echo " - Existing driver found: Select 'Continue'"
		echo " - EULA: Type 'accept'"
		echo " - CUDA Toolkit: Press 'a' and deselect all"
		echo " - Select Install"
		echo " - Select Upgrade all"
		echo
		read -n 1 -p "Continue [ENTER] "
		echo
		sudo rm -rf /var/log/cuda-installer.log
		sudo sh "$CUDA_PATCH_RUNFILE" --toolkit --toolkitpath="$CUDA_INSTALL_DIR" "${CUDA_SAMPLES_CMDS[@]}" --librarypath="$LOCAL_CUDA_SYSTEM_DIR" --no-man-page --override
		echo
		echo "You can ignore the PATH / LD_LIBRARY_PATH advice above, and not worry about 'Incomplete installation"'!'"' as we already have our own NVIDIA driver installed"
		echo
		echo "Checking the installation log for anything suspicious..."
		grep -Ei "\[(WARN|WARNING|ERROR)\]" /var/log/cuda-installer.log || true
		grep -Ei " (installed|created directory)" /var/log/cuda-installer.log | grep -Fv " $CUDA_INSTALL_DIR/" | grep -Fv " $LOCAL_CUDA_SYSTEM_DIR/" | grep -Fv "$LOCAL_CUDA_DIR/" | grep -Fv /var/log/nvidia/.uninstallManifests/ || true
		echo
	done
	echo "Performing CUDA post-installation clean-up steps..."
	if [[ -d "$LOCAL_CUDA_SYSTEM_DIR" ]]; then
		echo "Merging extra CUDA system stuff into: $CUDA_INSTALL_DIR"
		sudo rsync -qaK "$LOCAL_CUDA_SYSTEM_DIR/" "$CUDA_INSTALL_DIR/"
		sudo rm -rf "$LOCAL_CUDA_SYSTEM_DIR"
	fi
	if [[ -n "$CUDA_LD_SO_CONF" ]] && [[ -f "$CUDA_LD_SO_CONF" ]]; then
		echo "Removing ldconfig conf: $CUDA_LD_SO_CONF"
		sudo rm -rf "$CUDA_LD_SO_CONF"
		sudo ldconfig
	fi
fi
echo

# Create CUDA path management scripts
echo "Creating CUDA path management scripts..."
set +e
read -r -d '' CUDA_ADD_PATH_CONTENTS << 'EOM'
#!/bin/bash
# Add CUDA paths to the current environment
# Usage:
#   source #CUDA_INSTALL_DIR#/add_path.sh
# Check the results using:
#   echo "$CUDA_PATH"        # --> Custom variable specifying the (single) CUDA installation path
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

# Heuristically check that no other CUDA installations are currently on the path
search_path="$CUDA_PATH:$PATH:$LIBRARY_PATH:$LD_LIBRARY_PATH"
while read match; do
	if [[ "$match" != "/#CFG_CUDA_NAME#/" ]]; then
		echo "Error: Another CUDA installation (not #CFG_CUDA_NAME#) is already detected on the path => Aborting..."
		echo
		echo "CUDA_PATH: $CUDA_PATH"
		echo "PATH: $PATH"
		echo "LIBRARY_PATH: $LIBRARY_PATH"
		echo "LD_LIBRARY_PATH: $LD_LIBRARY_PATH"
		return 1
	fi
done < <(egrep -o "/cuda-[0-9]+(\.[0-9]+)?/" <<< "$search_path")

# Function to prepend an item to a path if it is not already there
function __PrependPath() { local __args __item; for __args in "${@:2}"; do [[ -n "${!1}" ]] && while IFS= read -r -d ':' __item; do [[ "$__item" == "$__args" ]] && continue 2; done <<< "${!1}:"; ([[ -n "${!1#:}" ]] || [[ -z "$__args" ]]) && __args+=':'; export "${1}"="$__args${!1}"; done; }

# Custom exported variables
export CUDA_PATH="#CUDA_INSTALL_DIR#"

# Add the required CUDA directories to the environment paths
__PrependPath PATH "$CUDA_PATH/bin"
__PrependPath LD_LIBRARY_PATH "$CUDA_PATH/lib64" "$CUDA_PATH/extras/CUPTI/lib64"#SET_GCC_COMPILER#

# Unset the function we have created
unset -f __PrependPath
# EOF
EOM
read -r -d '' CUDA_REMOVE_PATH_CONTENTS << 'EOM'
#!/bin/bash
# Remove CUDA paths from the current environment
# Usage:
#   source #CUDA_INSTALL_DIR#/remove_path.sh
# Check the results using:
#   echo "$CUDA_PATH"        # --> Custom variable specifying the (single) CUDA installation path
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
OUR_CUDA_PATH="#CUDA_INSTALL_DIR#"
[[ "$CUDA_PATH" == "$OUR_CUDA_PATH" ]] && unset CUDA_PATH

# Remove the required CUDA directories from the environment paths
__RemovePath PATH "$OUR_CUDA_PATH/bin"
__RemovePath LD_LIBRARY_PATH "$OUR_CUDA_PATH/lib64" "$OUR_CUDA_PATH/extras/CUPTI/lib64"

# Unset any default GCC compiler
[[ "$CUDA_PATH" == "$OUR_CUDA_PATH" ]] && unset CC CXX CUDAHOSTCXX

# Unset the function we have created
unset -f __RemovePath
# EOF
EOM
set -e
CUDA_ADD_PATH_CONTENTS="${CUDA_ADD_PATH_CONTENTS//#CUDA_INSTALL_DIR#/$CUDA_INSTALL_DIR}"
CUDA_ADD_PATH_CONTENTS="${CUDA_ADD_PATH_CONTENTS//#CFG_CUDA_NAME#/$CFG_CUDA_NAME}"
if [[ -n "$GCC_PATH" ]] || [[ -n "$GXX_PATH" ]]; then
	SET_GCC_COMPILER=$'\n\n# Set the default GCC compiler\n'"export CC=\"$GCC_PATH\" CXX=\"$GXX_PATH\" CUDAHOSTCXX=\"$GXX_PATH\""
	CUDA_ADD_PATH_CONTENTS="${CUDA_ADD_PATH_CONTENTS//#SET_GCC_COMPILER#/$SET_GCC_COMPILER}"
else
	CUDA_ADD_PATH_CONTENTS="${CUDA_ADD_PATH_CONTENTS//#SET_GCC_COMPILER#/}"
fi
CUDA_REMOVE_PATH_CONTENTS="${CUDA_REMOVE_PATH_CONTENTS//#CUDA_INSTALL_DIR#/$CUDA_INSTALL_DIR}"
CUDA_ADD_PATH="$CUDA_INSTALL_DIR/add_path.sh"
CUDA_REMOVE_PATH="$CUDA_INSTALL_DIR/remove_path.sh"
echo "$CUDA_ADD_PATH_CONTENTS" | sudo tee "$CUDA_ADD_PATH" >/dev/null
echo "Created: $CUDA_ADD_PATH"
echo "$CUDA_REMOVE_PATH_CONTENTS" | sudo tee "$CUDA_REMOVE_PATH" >/dev/null
echo "Created: $CUDA_REMOVE_PATH"
echo

# Install cuDNN
echo "Installing cuDNN $CFG_CUDNN_VERSION..."
if [[ -z "$(find -H "$CUDA_INSTALL_DIR/lib64" -type f -name "libcudnn*")" ]]; then
	mkdir -p "$LOCAL_CUDNN_DIR"
	echo "Unpacking cuDNN tar..."
	tar -xf "$CUDNN_TAR" -C "$LOCAL_CUDNN_DIR"
	echo "Installing cuDNN into CUDA directory..."
	sudo cp "$LOCAL_CUDNN_DIR"/cud*/include/cudnn*.h "$CUDA_INSTALL_DIR"/include
	sudo cp -P "$LOCAL_CUDNN_DIR"/cud*/lib*/libcudnn* "$CUDA_INSTALL_DIR"/lib64
	sudo chmod a+r "$CUDA_INSTALL_DIR"/include/cudnn*.h "$CUDA_INSTALL_DIR"/lib64/libcudnn*
	rm -rf "$LOCAL_CUDNN_DIR"
fi
echo

# Install CUDA samples if they are not part of the toolkit
if [[ ! -f "$CUDA_SAMPLES_COMPILED" ]] && find "$LOCAL_CUDA_DIR" -mindepth 1 -maxdepth 1 -type d \( -name "NVIDIA_CUDA-*_Samples" -o -name "cuda-samples" \) -exec false {} + -quit; then
	echo "Cloning CUDA samples $CFG_CUDA_SAMPLES_VERSION..."
	(
		set -x
		cd "$LOCAL_CUDA_DIR"
		git clone https://github.com/NVIDIA/cuda-samples.git
		cd "$LOCAL_CUDA_DIR/cuda-samples"
		git checkout "$CFG_CUDA_SAMPLES_TAG"
	)
	echo
fi

# Stop if stage limit reached
[[ "$CFG_STAGE" -eq 2 ]] && exit 0

#
# Stage 3
#

# Variables
CUDA_SAMPLES_DIR="$(find "$LOCAL_CUDA_DIR" -mindepth 1 -maxdepth 1 -type d \( -name "NVIDIA_CUDA-*_Samples" -o -name "cuda-samples" \) | sort | head -n 1)"
[[ -z "$CUDA_SAMPLES_DIR" ]] && CUDA_SAMPLES_DIR="$LOCAL_CUDA_DIR/cuda-samples"
CUDA_SAMPLES_BIN="$CUDA_SAMPLES_DIR/bin/x86_64"

# Stage 3 uninstall
read -r -d '' UNINSTALLER_COMMANDS << EOM || true
Commands to undo stage 3:
if [[ -f '$CUDA_ADD_PATH' ]] && [[ -d "$CUDA_SAMPLES_DIR" ]]; then (set +ux; source '$CUDA_ADD_PATH'; set -ux; cd '$CUDA_SAMPLES_DIR' && make clean -j'$(nproc)' >/dev/null;) fi
rm -rf '$CUDA_SAMPLES_BIN'
rm -f '$CUDA_SAMPLES_COMPILED'
EOM
add_uninstall_cmds "# $UNINSTALLER_COMMANDS"
echo "$UNINSTALLER_COMMANDS"
echo

# Compile the CUDA samples
echo "Compiling the CUDA samples as a test..."
if [[ -z "$CFG_QUICK" ]] && [[ ! -f "$CUDA_SAMPLES_COMPILED" ]]; then
	(
		cd "$CUDA_SAMPLES_DIR"
		find "$CUDA_SAMPLES_DIR" -type f \( -path "*/simpleVulkan/Makefile" -o -path "*/simpleVulkanMMAP/Makefile" -o -path "*/cudaNvSci/Makefile" \) -exec mv {} {}.DISABLED \;
		set +u
		source "$CUDA_ADD_PATH"
		set -u
		if [[ -n "$GXX_PATH" ]]; then
			export HOST_COMPILER="$GXX_PATH"
		else
			unset HOST_COMPILER
		fi
		echo "make -j$(nproc)"
		time make -j"$(nproc)"
		echo
		echo "Running: $CUDA_SAMPLES_BIN/linux/release/deviceQuery"
		"$CUDA_SAMPLES_BIN/linux/release/deviceQuery"
		echo
		if [[ -f "$CUDA_SAMPLES_BIN/linux/release/bandwidthTest" ]]; then
			echo "Running: $CUDA_SAMPLES_BIN/linux/release/bandwidthTest"
			"$CUDA_SAMPLES_BIN/linux/release/bandwidthTest"
			echo
		fi
		if [[ -f "$CUDA_SAMPLES_BIN/linux/release/UnifiedMemoryStreams" ]]; then
			echo "Running: $CUDA_SAMPLES_BIN/linux/release/UnifiedMemoryStreams"
			"$CUDA_SAMPLES_BIN/linux/release/UnifiedMemoryStreams"
			echo
		fi
		echo "Marking samples as successfully built..."
		touch "$CUDA_SAMPLES_COMPILED"
	)
fi
echo

# Clean the CUDA samples build
if [[ "$CFG_CLEAN_WORKDIR" -ge 1 ]]; then
	echo "Cleaning up CUDA samples build..."
	if [[ -f "$CUDA_ADD_PATH" ]] && [[ -d "$CUDA_SAMPLES_DIR" ]]; then
		(
			set +u
			source "$CUDA_ADD_PATH"
			set -u
			cd "$CUDA_SAMPLES_DIR" && make clean -j"$(nproc)" >/dev/null
		)
	fi
	rm -rf "$CUDA_SAMPLES_BIN"
	echo
fi

# Stop if stage limit reached
[[ "$CFG_STAGE" -eq 3 ]] && exit 0

#
# Stage 4
#

# Stage 4 uninstall
read -r -d '' UNINSTALLER_COMMANDS << EOM || true
Commands to undo stage 4:
# None
EOM
add_uninstall_cmds "# $UNINSTALLER_COMMANDS"
echo "$UNINSTALLER_COMMANDS"
echo

# Clean up installers
if [[ "$CFG_CLEAN_INSTALLERS" == "1" ]]; then
	echo "Cleaning up installers..."
	rm -rf "$CUDA_RUNFILE" "$CUDNN_TAR"
	for CUDA_PATCH_RUNFILE in "${CUDA_PATCH_RUNFILES[@]}"; do
		rm -rf "$CUDA_PATCH_RUNFILE"
	done
	rmdir --ignore-fail-on-non-empty "$INSTALLERS_DIR" || true
	echo
fi

# Clean up local working directory
if [[ "$CFG_CLEAN_WORKDIR" -ge 2 ]]; then
	(
		echo "Cleaning local working directory..."
		find "$LOCAL_CUDA_DIR" -mindepth 1 -not -name "$(basename "$CUDA_SAMPLES_COMPILED")" -prune -exec rm -rf {} +
		echo
	)
fi

# Stop if stage limit reached
[[ "$CFG_STAGE" -eq 4 ]] && exit 0

#
# Finish
#

# Signal that the script completely finished
echo "Finished CUDA stack installation"
echo

# EOF
