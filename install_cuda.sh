#!/bin/bash -i
# Install an isolated CUDA/cuDNN stack

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

# Name and path of directory to install CUDA into (must NOT exist yet, and name must be unique on the system)
CFG_CUDA_NAME="${CFG_CUDA_NAME:-cuda-$CFG_CUDA_VERSION}"
CFG_CUDA_LOCATION="${CFG_CUDA_LOCATION:-/usr/local}"

# Custom GCC compiler to use (if specified)
CFG_GCC_VERSION="${CFG_GCC_VERSION:-}"

# CUDA toolkit version and URL to use (https://developer.nvidia.com/cuda-toolkit-archive -> CUDA Toolkit X.X -> Linux -> x86_64 -> Ubuntu -> UU.04 -> runfile (local))
# Example: CFG_CUDA_VERSION=10.1
# Example: CFG_CUDA_URL='http://developer.download.nvidia.com/compute/cuda/10.1/Prod/local_installers/cuda_10.1.243_418.87.00_linux.run'

# cuDNN version and URL to use (https://developer.nvidia.com/rdp/cudnn-archive -> cuDNN vY.Y.Y for CUDA X.X -> cuDNN Library for Linux x86_64 (right-click) -> Copy link address)
# Example: CFG_CUDNN_VERSION=7.6.5
# Example: CFG_CUDNN_URL='https://developer.nvidia.com/compute/machine-learning/cudnn/secure/7.6.5.32/Production/10.1_20191031/cudnn-10.1-linux-x64-v7.6.5.32.tgz'

# Enter the root directory
cd "$CFG_ROOT_DIR"

# Clean up configuration variables
CFG_ROOT_DIR="$(pwd)"
CFG_CUDA_URL="${CFG_CUDA_URL%/}"
CFG_CUDNN_URL="${CFG_CUDNN_URL%/}"
CFG_CUDA_LOCATION="${CFG_CUDA_LOCATION%/}"

# Display the configuration
echo
echo "CFG_QUICK = $CFG_QUICK"
echo "CFG_ROOT_DIR = $CFG_ROOT_DIR"
echo "CFG_CUDA_VERSION = $CFG_CUDA_VERSION"
echo "CFG_CUDA_URL = $CFG_CUDA_URL"
echo "CFG_CUDNN_VERSION = $CFG_CUDNN_VERSION"
echo "CFG_CUDNN_URL = $CFG_CUDNN_URL"
echo "CFG_CUDA_NAME = $CFG_CUDA_NAME"
echo "CFG_CUDA_LOCATION = $CFG_CUDA_LOCATION"
echo "CFG_GCC_VERSION = $CFG_GCC_VERSION"
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
if [[ -n "$CFG_GCC_VERSION" ]]; then
	GCC_PATH="/usr/bin/gcc-$CFG_GCC_VERSION"
	GXX_PATH="/usr/bin/g++-$CFG_GCC_VERSION"
else
	GCC_PATH=
	GXX_PATH=
fi

# Initialise uninstaller script
UNINSTALLERS_DIR="$CFG_ROOT_DIR/Uninstallers"
UNINSTALLER_SCRIPT="$UNINSTALLERS_DIR/uninstall-$CFG_CUDA_NAME.sh"
echo "Creating uninstaller script: $UNINSTALLER_SCRIPT"
[[ ! -d "$UNINSTALLERS_DIR" ]] && mkdir "$UNINSTALLERS_DIR"
echo "# EOF" > "$UNINSTALLER_SCRIPT"
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
CUDNN_TAR="$INSTALLERS_DIR/${CFG_CUDNN_URL##*/}"

# Stage 1 uninstall
UNINSTALLER_CONTENTS="$(cat "$UNINSTALLER_SCRIPT")"
echo -en "\n# " > "$UNINSTALLER_SCRIPT"
tee -a "$UNINSTALLER_SCRIPT" << EOM
Commands to undo stage 1:
rm -rf "$CUDA_RUNFILE" "$CUDNN_TAR"
rmdir --ignore-fail-on-non-empty "$INSTALLERS_DIR" || true
EOM
echo "$UNINSTALLER_CONTENTS" >> "$UNINSTALLER_SCRIPT"
echo

# Download installers
echo "Downloading installers..."
[[ ! -d "$INSTALLERS_DIR" ]] && mkdir "$INSTALLERS_DIR"
echo
echo "Downloading CUDA $CFG_CUDA_VERSION..."
[[ ! -f "$CUDA_RUNFILE" ]] && wget "$CFG_CUDA_URL" -P "$INSTALLERS_DIR"
echo
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

#
# Stage 2
#

# Variables
CUDA_INSTALL_DIR="$CFG_CUDA_LOCATION/$CFG_CUDA_NAME"
MAIN_CUDA_DIR="$CFG_ROOT_DIR/CUDA"
LOCAL_CUDA_DIR="$MAIN_CUDA_DIR/$CFG_CUDA_NAME"
LOCAL_CUDA_SYSTEM_DIR="$LOCAL_CUDA_DIR/system"
LOCAL_CUDNN_DIR="$LOCAL_CUDA_DIR/cuDNN-$CFG_CUDNN_VERSION"

# Stage 2 uninstall
UNINSTALLER_CONTENTS="$(cat "$UNINSTALLER_SCRIPT")"
echo -en "\n# " > "$UNINSTALLER_SCRIPT"
echo "Commands to undo stage 2:" | tee -a "$UNINSTALLER_SCRIPT"
echo '(set +x; if [[ -x "'"$CUDA_INSTALL_DIR/bin/cuda-uninstaller"'" ]] && [[ -n "$(find /var/log/nvidia/.uninstallManifests -type f -name "uninstallManifest-*" -exec grep -F "'"$CUDA_INSTALL_DIR/"'" {} \+)" ]]; then sudo "'"$CUDA_INSTALL_DIR/bin/cuda-uninstaller"'"; else echo "Did not call CUDA uninstaller as no matching uninstaller/manifest was found"; fi;)' | tee -a "$UNINSTALLER_SCRIPT"
tee -a "$UNINSTALLER_SCRIPT" << EOM
sudo rm -rf "$CUDA_INSTALL_DIR" "$LOCAL_CUDA_SYSTEM_DIR"
rm -rf "$LOCAL_CUDA_DIR" "$LOCAL_CUDNN_DIR"
rmdir --ignore-fail-on-non-empty "$MAIN_CUDA_DIR" || true
EOM
echo "$UNINSTALLER_CONTENTS" >> "$UNINSTALLER_SCRIPT"
echo

# Install CUDA toolkit
echo "Installing CUDA toolkit $CFG_CUDA_VERSION..."
[[ ! -d "$MAIN_CUDA_DIR" ]] && mkdir "$MAIN_CUDA_DIR"
if [[ ! -d "$LOCAL_CUDA_DIR" ]]; then
	mkdir "$LOCAL_CUDA_DIR"
	sudo rm -rf /var/log/cuda-installer.log
	echo
	echo "Please perform the following actions in the CUDA installer:"
	echo " - Existing driver found: Select 'Continue'"
	echo " - EULA: Type 'accept'"
	echo " - Driver: Deselect all"
	echo " - CUDA Toolkit: Press 'a' and deselect all"
	echo " - CUDA Documentation: Deselect"
	echo " - Select Install"
	echo
	read -n 1 -p "Continue [ENTER] "
	echo
	sudo sh "$CUDA_RUNFILE" --toolkit --toolkitpath="$CUDA_INSTALL_DIR" --samples --samplespath="$LOCAL_CUDA_DIR" --librarypath="$LOCAL_CUDA_SYSTEM_DIR" --no-man-page --override
	echo
	echo "You can ignore the PATH / LD_LIBRARY_PATH advice above, and not worry about 'Incomplete installation"'!'"' as we already have our own NVIDIA driver installed"
	echo
	echo "Checking the installation log for anything suspicious..."
	grep -Ei "\[(WARN|WARNING|ERROR)\]" /var/log/cuda-installer.log || true
	grep -Ei " (installed|created directory)" /var/log/cuda-installer.log | grep -Fv " $CUDA_INSTALL_DIR/" | grep -Fv " $LOCAL_CUDA_SYSTEM_DIR/" | grep -Fv "$LOCAL_CUDA_DIR/" | grep -Fv /var/log/nvidia/.uninstallManifests/ || true
	echo
	echo "Performing CUDA post-installation clean-up steps..."
	if [[ -d "$LOCAL_CUDA_SYSTEM_DIR" ]]; then
		echo "Merging extra CUDA system stuff into: $CUDA_INSTALL_DIR"
		sudo rsync -qaK "$LOCAL_CUDA_SYSTEM_DIR/" "$CUDA_INSTALL_DIR/"
		sudo rm -rf "$LOCAL_CUDA_SYSTEM_DIR"
	fi
	CUDA_LD_SO_CONF="$(grep -Eo "/etc/ld\.so\.conf\.d/cuda-.*.conf" /var/log/cuda-installer.log)"
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
__PrependPath LD_LIBRARY_PATH "$CUDA_PATH/lib64" "$CUDA_PATH/extras/CUPTI/lib64"
#SET_GCC_COMPILER#

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
[[ "$CUDA_PATH" == "$OUR_CUDA_PATH" ]] && unset CC CXX

# Unset the function we have created
unset -f __RemovePath
# EOF
EOM
set -e
CUDA_ADD_PATH_CONTENTS="${CUDA_ADD_PATH_CONTENTS//#CUDA_INSTALL_DIR#/$CUDA_INSTALL_DIR}"
CUDA_ADD_PATH_CONTENTS="${CUDA_ADD_PATH_CONTENTS//#CFG_CUDA_NAME#/$CFG_CUDA_NAME}"
if [[ -n "$GCC_PATH" ]] || [[ -n "$GXX_PATH" ]]; then
	SET_GCC_COMPILER=$'\n# Set the default GCC compiler\n'"export CC=\"$GCC_PATH\" CXX=\"$GXX_PATH\""
	CUDA_ADD_PATH_CONTENTS="${CUDA_ADD_PATH_CONTENTS//#SET_GCC_COMPILER#/$SET_GCC_COMPILER}"
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

#
# Stage 3
#

# Variables
CUDA_SAMPLES_DIR="$(find "$LOCAL_CUDA_DIR" -type d -name "NVIDIA_CUDA-*_Samples" | head -n 1)"
CUDA_SAMPLES_COMPILED="$CUDA_SAMPLES_DIR/compiled"

# Stage 3 uninstall
UNINSTALLER_CONTENTS="$(cat "$UNINSTALLER_SCRIPT")"
echo -en "\n# " > "$UNINSTALLER_SCRIPT"
tee -a "$UNINSTALLER_SCRIPT" << EOM
Commands to undo stage 3:
if [[ -f "$CUDA_ADD_PATH" ]]; then (set +ux; source "$CUDA_ADD_PATH"; set -ux; if cd "$CUDA_SAMPLES_DIR"; then make clean -j$(nproc) >/dev/null; fi;); fi
rm -rf "$CUDA_SAMPLES_DIR/bin"
rm -f "$CUDA_SAMPLES_COMPILED"
EOM
echo "$UNINSTALLER_CONTENTS" >> "$UNINSTALLER_SCRIPT"
echo

# Compile the CUDA samples
echo "Compiling the CUDA samples as a test..."
if [[ -z "$CFG_QUICK" ]] && [[ ! -f "$CUDA_SAMPLES_COMPILED" ]]; then
	(
		cd "$CUDA_SAMPLES_DIR"
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
		echo "Running: $CUDA_SAMPLES_DIR/bin/x86_64/linux/release/deviceQuery"
		"$CUDA_SAMPLES_DIR/bin/x86_64/linux/release/deviceQuery"
		echo
		echo "Running: $CUDA_SAMPLES_DIR/bin/x86_64/linux/release/bandwidthTest"
		"$CUDA_SAMPLES_DIR/bin/x86_64/linux/release/bandwidthTest"
		echo
		echo "Running: $CUDA_SAMPLES_DIR/bin/x86_64/linux/release/UnifiedMemoryStreams"
		"$CUDA_SAMPLES_DIR/bin/x86_64/linux/release/UnifiedMemoryStreams"
		echo
		echo "Marking samples as successfully built..."
		touch "$CUDA_SAMPLES_COMPILED"
		echo "Cleaning up CUDA samples build..."
		make clean -j"$(nproc)" >/dev/null
		rm -rf "$CUDA_SAMPLES_DIR/bin"
	)
fi
echo

#
# Finish
#

# Finalise uninstaller script
echo "Finalising uninstaller script: $UNINSTALLER_SCRIPT"
UNINSTALLER_CONTENTS="$(cat "$UNINSTALLER_SCRIPT")"
cat << EOM > "$UNINSTALLER_SCRIPT"
#!/bin/bash -x
# Uninstall $CFG_CUDA_NAME

# Use bash strict mode
set -euo pipefail
EOM
echo "$UNINSTALLER_CONTENTS" >> "$UNINSTALLER_SCRIPT"
chmod +x "$UNINSTALLER_SCRIPT"
echo

# Signal that the script completely finished
echo "Finished CUDA stack installation"
echo

# EOF
