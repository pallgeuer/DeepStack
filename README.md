# Deep Learning Stack

**Version:** 1.0

**Author:** Philipp Allgeuer

Setting up a deep learning stack can be quite a complex and involved task,
especially for those new to the task. Even for experienced users, further
wanting to have *multiple* independent deep learning stacks in parallel on the
same machine vastly increases the difficulty (e.g. multiple simultaneous
versions of CUDA). This repository seeks to address this issue, while at the
same time automating the entire process. Furthermore, for optimal performance
this repository manually compiles libraries like OpenCV and PyTorch, as, for
example, PyTorch built from source can be observed to be up to 4x faster than a
naive install.

## Tested configurations

This repository can be used to install arbitrary version combinations of all the
component libraries involved, but some configurations will obviously work better
than others due to library dependencies and cross-compatibilities. This
repository has so far been tested on selected combinations of the following
component versions:

 * **Ubuntu:** 18.04, 20.04 (x86_64)
 * **Conda:** 4.8.2 to 4.11.0
 * **NVIDIA driver:** 470 to 510
 * **Python:** 3.6 to 3.9
 * **CUDA:** 10.1 to 11.5
 * **cuDNN:** 7.6.5 to 8.3.2
 * **OpenCV:** 3.4.17 to 4.5.5
 * **TensorRT:** 6.0.1 to 8.2.3
 * **PyTorch:** 1.8.2 to 1.10.2
 * **Torchvision:** 0.9.2 to 0.11.3
 * **Torchaudio:** 0.8.2 to 0.10.2
 * **Torchtext:** 0.9.2 to 0.11.2

## Prerequisites

In order to get started you will require an Ubuntu OS with an NVIDIA driver
installed that is compatible with your GPU. You will further require an
installed conda distribution, i.e. Anaconda or Miniconda.

### NVIDIA driver

If you have an NVIDIA graphics card, especially in a laptop setting, it can
happen that the default Ubuntu graphics driver does not work out of the box.
This can cause weird screen effects when attempting to boot, and failure to
properly load the graphical interface. One workaround that often helps is to
temporarily specify the `nomodeset` kernel boot option until you can install a
graphics driver that works properly (e.g. a suitable NVIDIA one). When at the
GRUB screen during boot, instead of pressing `Enter` to launch `Ubuntu`, have it
highlighted and press `e` and then add the keyword `nomodeset` after `quiet
splash`. Then press `F10` to boot. Note that this is a temporary change for a
single boot only.

Once booted, before installing an NVIDIA graphics driver, check what driver is
actually currently being used:
```
lsmod | egrep 'nouveau|nvidia'
```
Even if this does not show an NVIDIA driver currently in use, you should still
be extraordinarily careful to make sure no single package belonging to another
NVIDIA driver is currently installed before continuing. It happens by accident
more often than you think, and can be fatal for the driver working. So first
check what is installed:
```
dpkg -l | egrep -i 'nvidia|390|418|430|435|440|450|455|460|465|470|495|510'
```
The numbers being searched for are Linux AMD64 NVIDIA driver version numbers.
This is needed because not all packages that are part of the driver have
`nvidia` in the name, e.g. `libxnvctrl0`. This will potentially produce some
false positives, but these can be filtered out with a bit of common sense. Note
however, that not all packages with `nvidia` in the name are automatically part
of the driver (e.g. `nvidia-container-toolkit` is not). Based on the returned
list, uninstall all currently installed packages belonging to old NVIDIA driver
installations. Just as a reference, the packages that are part of the 470.57
driver are:

| Package                       | Version                    | Description                                               |
| ----------------------------- | -------------------------- | --------------------------------------------------------- |
| libnvidia-cfg1-470:amd64      | 470.57.02-0ubuntu0.18.04.1 | NVIDIA binary OpenGL/GLX configuration library            |
| libnvidia-common-470          | 470.57.02-0ubuntu0.18.04.1 | Shared files used by the NVIDIA libraries                 |
| libnvidia-compute-470:amd64   | 470.57.02-0ubuntu0.18.04.1 | NVIDIA libcompute package                                 |
| libnvidia-compute-470:i386    | 470.57.02-0ubuntu0.18.04.1 | NVIDIA libcompute package                                 |
| libnvidia-decode-470:amd64    | 470.57.02-0ubuntu0.18.04.1 | NVIDIA Video Decoding runtime libraries                   |
| libnvidia-decode-470:i386     | 470.57.02-0ubuntu0.18.04.1 | NVIDIA Video Decoding runtime libraries                   |
| libnvidia-encode-470:amd64    | 470.57.02-0ubuntu0.18.04.1 | NVENC Video Encoding runtime library                      |
| libnvidia-encode-470:i386     | 470.57.02-0ubuntu0.18.04.1 | NVENC Video Encoding runtime library                      |
| libnvidia-extra-470:amd64     | 470.57.02-0ubuntu0.18.04.1 | Extra libraries for the NVIDIA driver                     |
| libnvidia-fbc1-470:amd64      | 470.57.02-0ubuntu0.18.04.1 | NVIDIA OpenGL-based Framebuffer Capture runtime library   |
| libnvidia-fbc1-470:i386       | 470.57.02-0ubuntu0.18.04.1 | NVIDIA OpenGL-based Framebuffer Capture runtime library   |
| libnvidia-gl-470:amd64        | 470.57.02-0ubuntu0.18.04.1 | NVIDIA OpenGL/GLX/EGL/GLES GLVND libraries and Vulkan ICD |
| libnvidia-gl-470:i386         | 470.57.02-0ubuntu0.18.04.1 | NVIDIA OpenGL/GLX/EGL/GLES GLVND libraries and Vulkan ICD |
| libnvidia-ifr1-470:amd64      | 470.57.02-0ubuntu0.18.04.1 | NVIDIA OpenGL-based Inband Frame Readback runtime library |
| libnvidia-ifr1-470:i386       | 470.57.02-0ubuntu0.18.04.1 | NVIDIA OpenGL-based Inband Frame Readback runtime library |
| libxnvctrl0:amd64             | 470.57.01-0ubuntu0.18.04.1 | NV-CONTROL X extension (runtime library)                  |
| nvidia-compute-utils-470      | 470.57.02-0ubuntu0.18.04.1 | NVIDIA compute utilities                                  |
| nvidia-dkms-470               | 470.57.02-0ubuntu0.18.04.1 | NVIDIA DKMS package                                       |
| nvidia-driver-470             | 470.57.02-0ubuntu0.18.04.1 | NVIDIA driver metapackage                                 |
| nvidia-kernel-common-470      | 470.57.02-0ubuntu0.18.04.1 | Shared files used with the kernel module                  |
| nvidia-kernel-source-470      | 470.57.02-0ubuntu0.18.04.1 | NVIDIA kernel source package                              |
| nvidia-prime                  | 0.8.16~0.18.04.1           | Tools to enable NVIDIA's Prime                            |
| nvidia-settings               | 470.57.01-0ubuntu0.18.04.1 | Tool for configuring the NVIDIA graphics driver           |
| nvidia-utils-470              | 470.57.02-0ubuntu0.18.04.1 | NVIDIA driver support binaries                            |
| xserver-xorg-video-nvidia-470 | 470.57.02-0ubuntu0.18.04.1 | NVIDIA binary Xorg driver                                 |

To uninstall the packages in the table you would do:
```
packages=(libnvidia-cfg1-470:amd64 libnvidia-common-470 libnvidia-compute-470:amd64 libnvidia-compute-470:i386 libnvidia-decode-470:amd64 libnvidia-decode-470:i386 libnvidia-encode-470:amd64 libnvidia-encode-470:i386 libnvidia-extra-470:amd64 libnvidia-fbc1-470:amd64 libnvidia-fbc1-470:i386 libnvidia-gl-470:amd64 libnvidia-gl-470:i386 libnvidia-ifr1-470:amd64 libnvidia-ifr1-470:i386 libxnvctrl0:amd64 nvidia-compute-utils-470 nvidia-dkms-470 nvidia-driver-470 nvidia-kernel-common-470 nvidia-kernel-source-470 nvidia-prime nvidia-settings nvidia-utils-470 xserver-xorg-video-nvidia-470)
sudo apt-mark unhold "${packages[@]}"
sudo apt purge "${packages[@]}"
```
Note that when uninstalling these packages, it is possible that other packages
that explicitly depend on these packages also get removed (e.g. `psensor`). This
is not easily avoidable, and you can reinstall the uninstalled packages after
you have installed the new driver, but if you want to avoid them being purged
(not just removed), then explicitly remove those packages manually beforehand.

Once there are no NVIDIA graphics driver packages installed anymore, you can
install the new driver of your choosing. Choose a driver version number that you
want to install from [NVIDIA Driver
Downloads](https://www.nvidia.com/Download/Find.aspx?lang=en-us). If, for
example, this reveals that you want to install the latest available driver of
version 510, you would check what is available in the Ubuntu universe using:
```
apt-cache policy nvidia-driver-510
```
If you like the listed installation candidate, then:
```
sudo apt install build-essential
sudo apt install nvidia-driver-510
```
Automatic package updates are dangerous for the NVIDIA driver, as some packages
may be updated before others, and you might find one day that your graphical
interface is suddenly buggy or crashes. To avoid this, it is recommended to mark
*all* of the NVIDIA packages that were just installed as part of
`nvidia-driver-510` as 'on hold' (i.e. frozen):
```
sudo apt-mark hold PACKAGES JUST INSTALLED
apt-mark showhold
```
The list of packages just installed should be quite similar to the list provided
in the uninstall instructions above, just with different version numbers. You
cannot rely on this however being the case. As a check:
```
dpkg -l | egrep -i '(nvidia|390|418|430|435|440|450|455|460|465|470|495|510)|(^h)'
```
If there is `hi` at the beginning of a line then the corresponding package is
installed and on hold. Otherwise `ii` just means installed.

Reboot the computer (without adding `nomodeset` in case you were doing that so
far) and check that the NVIDIA driver works:
```
lsmod | egrep 'nouveau|nvidia'
nvidia-smi
```
You can also perform a graphical test of the graphics card and driver using:
```
sudo apt install mesa-utils
__GL_SYNC_TO_VBLANK=0 vblank_mode=0 glxgears
```
And for a more involved test:
```
sudo apt install glmark2
glmark2
```
Keep in mind that the frame rates and scores achieved by these tests are only a
rough indication of the computational power of your GPU.

### Conda distribution

Refer to the installation instructions for
[Anaconda](https://docs.anaconda.com/anaconda/install/linux) or
[Miniconda](https://docs.conda.io/en/latest/miniconda.html#linux-installers).
Maybe you need
[help deciding whether Anaconda or Miniconda](https://docs.conda.io/projects/conda/en/latest/user-guide/install/download.html#anaconda-or-miniconda)?

In the Anaconda install instructions (use these instructions also for
Miniconda), if you have Ubuntu you need to install the prerequisites for Debian
(i.e. the `apt` command). I also recommend configuring conda at the end to not
auto-activate using:
```
conda config --set auto_activate_base False
```
You should also make sure you have the latest conda binary in the base
environment:
```
conda update -n base -c defaults conda
```
Maybe now is also the right time to think about getting the IDE [PyCharm for
Anaconda](https://www.anaconda.com/pycharm) if you want an easy life.

Note that the script that installs PyTorch with TensorRT support compiles and
runs some test samples in order to check that the installation of TensorRT was
successful. This is prior to the creation of an associated conda environment (as
it may be a one-to-many mapping), so it briefly assumes there is a system-wide
Python 3 version available that has `numpy` and `Pillow` installed. This should
generally not be a problem, but if you wish to avoid this then specify
`CFG_QUICK=1`.

## Installation

The following scripts are the main installers that are available in this
repository:

 * `install-cuda.sh`: Installs a local version of CUDA/cuDNN. By default, the
installation paths are kept out of the system paths so that multiple versions
can be installed and used in parallel without any conflict.

 * `install-opencv-python.sh`: Compiles and installs a binary version of OpenCV
Python into a conda environment. Note that this does not install development
files into the conda environment, so you cannot easily compile further libraries
against this install of OpenCV.

 * `install-pytorch.sh`: Compiles and installs development versions of PyTorch, 
OpenCV, and optionally Torchvision, Torchaudio, Torchtext and TensorRT, into a 
conda environment.

Each of these scripts have many required (and optional) configuration 
parameters, which are clearly documented in the Configuration section of the 
corresponding script source code. Note that you should *not* run multiple 
instances of the same script in parallel, as this could result in race 
conditions and errors.

For instance, you can install CUDA 11.5 with cuDNN 8.3.2 using the one-liner:
```
CFG_CUDA_VERSION=11.5 CFG_CUDA_URL='https://developer.download.nvidia.com/compute/cuda/11.5.1/local_installers/cuda_11.5.1_495.29.05_linux.run' CFG_CUDNN_VERSION=8.3.2 CFG_CUDNN_URL='https://developer.nvidia.com/compute/cudnn/secure/8.3.2/local_installers/11.5/cudnn-linux-x86_64-8.3.2.44_cuda11.5-archive.tar.xz' ./install-cuda.sh
```
Or equivalently:
```
export CFG_CUDA_VERSION=11.5
export CFG_CUDA_URL='https://developer.download.nvidia.com/compute/cuda/11.5.1/local_installers/cuda_11.5.1_495.29.05_linux.run'
export CFG_CUDNN_VERSION=8.3.2
export CFG_CUDNN_URL='https://developer.nvidia.com/compute/cudnn/secure/8.3.2/local_installers/11.5/cudnn-linux-x86_64-8.3.2.44_cuda11.5-archive.tar.xz'
./install-cuda.sh
```
In order to simplify the choice of library versions and configuration
parameters, default scripts are available that install commonly required deep
learning stacks. For example, this installs CUDA 11.5 with cuDNN 8.3.2:
```
./install-cuda-11.5-cudnn-8.3.2.sh
```
And for example, this installs OpenCV Python 4.5.5 into the new conda
environment `myenv` based on an existing installation of CUDA 10.2:
```
CFG_CONDA_ENV=myenv ./install-opencv-python-4.5.5-cuda-10.2.sh
```
This installs PyTorch 1.10.2 into the new conda environment `pytch` based on an
existing installation of CUDA 11.3:
```
CFG_CONDA_ENV=pytch ./install-pytorch-1.10.2-cuda-11.3.sh
```
And this installs PyTorch 1.8.2 LTS along with TensorRT 6.0.1 into the new conda
environment `trt` based on an existing installation of CUDA 10.1:
```
CFG_CONDA_ENV=trt ./install-pytorch-1.8.2-cuda-10.1-trt-6.0.1.sh
```
The following installs PyTorch 1.10.2 along with TensorRT 8.2.3 into the new
conda environment `myproj` based on an existing installation of CUDA 11.3, but
does not explicitly compile TensorRT into PyTorch:
```
CFG_CONDA_ENV=myproj ./install-pytorch-1.10.2-cuda-11.3-trtext-8.2.3.sh
```
This may be useful in order to side-step compatibility issues, and does not
prevent you from exporting PyTorch models to TensorRT via ONNX as normal. For 
instance, PyTorch 1.10 is not directly compatible with TensorRT 8 and above (due 
to removal of deprecated APIs), and TensorRT 7 does not support Python 3.9+ or 
CUDA 11.2+ (even though at first from the website it seems CUDA 11.2 is 
supported). TensorRT 7 also only officially supports up to cuDNN 8.1.1, which 
may not match up well to the desired CUDA version.

In most of the above commands, two other commonly useful configuration variables
aside from `CFG_CONDA_ENV` are `CFG_AUTO_ANSWER=1` (automatically answer yes to
all prompts) and `CFG_STAGE=X` (e.g. if set to 3 only the first three 
installation stages will be executed). The PyTorch installation script also has 
a configuration variable `CFG_ALLOW_SUDO`, which if set to 0 skips any sudo 
commands, which are generally only used at the beginning for `apt install`. 
Running with `CFG_STAGE=-1` allows just these to be executed.

If anything at all goes wrong during the installation process, the script exits
immediately to prevent any possibly unanticipated behaviour. This means that an
installation has only completed successfully if you see a final line like
`Finished CUDA stack installation` or `Finished PyTorch installation`.

When running an installer script, subdirectories are created within the main
directory to store downloaded files, cloned repositories, compiled samples and
more. As an overview, the created subdirectories are:

 * `CUDA`: Stores CUDA samples, and is where they are temporarily compiled.

 * `envs`: Stores the cloned git repositories required for the created conda
environments, e.g. PyTorch git repository.

 * `Installers`: Stores downloaded installer files, e.g. CUDA runfiles.

 * `TensorRT`: Stores unpacked TensorRT versions that are possibly shared
amongst multiple conda environments.

 * `Uninstallers`: Stores uninstaller scripts to reverse the actions performed
by the installer scripts that were run.

As each installer script runs, it stores the actions required to undo each
installation stage into a corresponding uninstaller script. If an installation
stage fails, you can open the uninstaller script and use the listed commands in
the corresponding paragaph to undo just the stage that failed. You can then
re-run the entire installer script to try again (assuming you have changed
something that makes you think it will work this time). This automatically skips
already completed stages and keeps going where it left off.

## Future Work

In the future it would be great to also include support for the following
library components:
 * **TensorFlow:** 2.4.0 onwards
 * **TensorBoard:** 2.4.0 onwards

## Features and Bugs

Please contact the author if you encounter any issues with the repository, where
you think the installation scripts are at fault, i.e. not just a compilation
error due to library compatibility issues. If you have any specific realisable
feature suggestions, then that would be welcome too. If you're looking for a
template to build PyTorch in a docker environment, then
[PyTorch Docker Hub](https://hub.docker.com/r/pytorch/pytorch) or
[NVIDIA NGC](https://catalog.ngc.nvidia.com) or
[Cresset](https://github.com/cresset-template/cresset) may be for you.
