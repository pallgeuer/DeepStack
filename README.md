# Deep Learning Stack

**Author:** Philipp Allgeuer

Setting up a deep learning stack can be quite a complex and involved task, especially for those new to the task. Even for experienced users, further wanting to have *multiple* independent deep learning stacks in parallel on the same machine vastly increases the difficulty (e.g. multiple simultaneous versions of CUDA). This repository seeks to address this issue, while at the same time automating the entire process. Furthermore, for optimal performance this repository manually compiles libraries like OpenCV and PyTorch, as, for example, PyTorch built from source can be observed to be up to 4x faster than a naive install.

## Tested configurations

This repository can be used to install arbitrary version combinations of all the component libraries involved, but some configurations will obviously work better than others due to library dependencies and cross-compatibilities. This repository has so far been tested on certain combinations of the following component versions:

 * **Ubuntu:** 18.04, 20.04
 * **NVIDIA driver:** 470 to 510
 * **Python:** 3.6 to 3.9
 * **CUDA:** 10.1 to 11.5
 * **cuDNN:** 7.6.5 to 8.3.2
 * **OpenCV:** 3.4.17 to 4.5.5
 * **TensorRT:** 6.0.1 to 8.2.3
 * **PyTorch:** 1.8.2 to 1.10.2
 * **Torchvision:** 0.9.2 to 0.11.3

## Prerequisites

In order to get started you will require an installed Ubuntu OS, along with a GPU-compatible NVIDIA driver. You further require an installed conda distribution, i.e. Anaconda or Miniconda.

### NVIDIA driver

TODO: Installation guide for NVIDIA driver

### Conda distribution

TODO: Installation guide for Anaconda/Miniconda

## Installation

The following scripts are the main installers that are available in this repository:

 * `install-cuda.sh`: Installs a local version of CUDA/cuDNN. By default, the installation paths are kept out of the system paths so that multiple versions can be installed and used in parallel without any conflict.
 * `install-opencv-python.sh`: Compiles and installs a binary version of OpenCV Python into a conda environment. Note that this does not install development files into the conda environment, so you cannot easily compile further libraries against this install of OpenCV.
 * `install-pytorch.sh`: Compiles and installs development versions of PyTorch, Torchvision, OpenCV and TensorRT (optional) into a conda environment.

Each of these scripts have many required (and optional) configuration parameters, which are clearly documented in the Configuration section of the corresponding script source code.

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
In order to simplify the choice of library versions and configuration parameters, default scripts are available that install commonly required deep learning stacks. For example, this installs CUDA 11.5 with cuDNN 8.3.2:
```
./install-cuda-11.5-cudnn-8.3.2.sh
```
And for example, this installs OpenCV Python 4.5.5 into the new conda environment `myenv` based on an existing installation of CUDA 10.2:
```
CFG_CONDA_ENV=myenv ./install-opencv-python-4.5.5-cuda-10.2.sh
```
This installs PyTorch 1.10.2 into the new conda environment `pytch` based on an existing installation of CUDA 11.3:
```
CFG_CONDA_ENV=pytch ./install-pytorch-1.10.2-cuda-11.3.sh
```
And this installs PyTorch 1.8.2 LTS along with TensorRT 6.0.1 into the new conda environment `trt` based on an existing installation of CUDA 10.1:
```
CFG_CONDA_ENV=trt ./install-pytorch-1.8.2-cuda-10.1.sh
```
Aside from `CFG_CONDA_ENV`, two other commonly useful configuration variables are `CFG_AUTO_ANSWER=1` (automatically answer yes to all prompts) and `CFG_STAGE=X` (e.g. if set to 3 only the first three installation stages will be executed).

If anything at all goes wrong during the installation process, the script exits immediately to prevent any possibly unanticipated behaviour. This means that an installation has only completed successfully if you see a final line like `Finished CUDA stack installation` or `Finished PyTorch installation`.

When running an installer script, subdirectories are created within the main directory to store downloaded files, cloned repositories, compiled samples and more. As an overview, the created subdirectories are:

 * `CUDA`: Stores and temporarily compiles CUDA samples.
 * `envs`: Stores the cloned git repositories required for the created conda environments, e.g. PyTorch git repository.
 * `Installers`: Stores downloaded installer files, e.g. CUDA runfiles
 * `TensorRT`: Stores unpacked TensorRT versions that are possibly shared amongst multiple conda environments.
 * `Uninstallers`: Stores uninstaller scripts to reverse the actions performed by the installer scripts that have been run.

As each installer script runs, it stores the actions required to undo each installation stage into a corresponding uninstaller script. If an installation stage fails, you can open the uninstaller script and use the listed commands in the corresponding paragaph to undo just the stage that failed. You can then re-run the entire installer script to try again (assuming you have changed something that makes you think it will work this time).

## Future Work

In the future it would be great to also include support for the following library components:
 * **Torchaudio:** 0.8.2 onwards
 * **Torchtext:** 0.9.2 onwards
 * **TensorFlow:** 2.4.0 onwards
 * **TensorBoard:** 2.4.0 onwards
