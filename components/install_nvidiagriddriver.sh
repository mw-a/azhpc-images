#!/bin/bash
set -ex

# GRID/vGPU driver install for NCv6.
# Differences vs install_nvidiagpudriver.sh
#   - GRID driver from Microsoft instead of Tesla driver from NVIDIA
#   - No nvidia-peermem (no InfiniBand)
#   - No GDRCopy (BAR1 mapping fails under vGPU and no RDMA to support)
#   - No NVIDIA Fabric Manager (no NVSwitch/NVLink fabric)

source ${UTILS_DIR}/utilities.sh

# Retrieve GRID driver metadata from versions.json
grid_metadata=$(get_component_config "nvidia_grid")
GRID_DRIVER_URL=$(jq -r '.url' <<< $grid_metadata)
GRID_DRIVER_SHA256=$(jq -r '.sha256' <<< $grid_metadata)
GRID_DRIVER_VERSION=$(jq -r '.version' <<< $grid_metadata)

# Download the GRID driver
download_and_verify $GRID_DRIVER_URL $GRID_DRIVER_SHA256

bash NVIDIA-Linux-x86_64-${GRID_DRIVER_VERSION}-grid-azure.run --silent --dkms --kernel-module-type=proprietary

write_component_version "NVIDIA_GRID" ${GRID_DRIVER_VERSION}

# Configure GRID licensing
cp /etc/nvidia/gridd.conf.template /etc/nvidia/gridd.conf
# Ensure required settings are present and remove FeatureType=0 if present (per Azure documentation)
grep -q '^IgnoreSP=' /etc/nvidia/gridd.conf && sed -i 's/^IgnoreSP=.*/IgnoreSP=FALSE/' /etc/nvidia/gridd.conf || echo 'IgnoreSP=FALSE' >> /etc/nvidia/gridd.conf
grep -q '^EnableUI=' /etc/nvidia/gridd.conf && sed -i 's/^EnableUI=.*/EnableUI=FALSE/' /etc/nvidia/gridd.conf || echo 'EnableUI=FALSE' >> /etc/nvidia/gridd.conf
sed -i '/^FeatureType=0/d' /etc/nvidia/gridd.conf

# Install CUDA toolkit
cuda_metadata=$(get_component_config "cuda")
CUDA_DRIVER_VERSION=$(jq -r '.driver.version' <<< $cuda_metadata)
CUDA_DRIVER_DISTRIBUTION=$(jq -r '.driver.distribution' <<< $cuda_metadata)
if [[ $DISTRIBUTION == *"ubuntu"* ]]; then
# Add NVIDIA CUDA APT repo (provides toolkit packages)
wget https://developer.download.nvidia.com/compute/cuda/repos/${CUDA_DRIVER_DISTRIBUTION}/x86_64/cuda-keyring_1.1-1_all.deb
dpkg -i ./cuda-keyring_1.1-1_all.deb
apt-get update
apt install -y cuda-toolkit-${CUDA_DRIVER_VERSION//./-}
elif [[ $DISTRIBUTION == "azurelinux3.0" ]]; then    
    dnf install -y cuda-toolkit-${CUDA_DRIVER_VERSION//./-}
else
    # RHEL-family: AlmaLinux, Rocky Linux, RHEL, etc.
    dnf config-manager --add-repo https://developer.download.nvidia.com/compute/cuda/repos/${CUDA_DRIVER_DISTRIBUTION}/x86_64/cuda-${CUDA_DRIVER_DISTRIBUTION}.repo

    # DOCA ships mft tied to the kernel-mft-dkms it built; cuda-rhel9
    # ships mft on a different cadence (sometimes newer). Letting
    # cuda-rhel9 offer mft causes 'dnf check-update' to flag a
    # stale-package upgrade in verify_package_updates and risks an
    # accidental upgrade that breaks compat with the DOCA-built
    # kernel-mft-dkms. mft must track DOCA, not CUDA. Same pattern as
    # install_nvidia_fabric_manager.sh excluding nvidia-fabricmanager*
    # from cuda-azl3 on AzureLinux 3, and a per-repo replacement for
    # the (removed) global DOCA pin in install_doca.sh.
    cuda_excludes="mft* kernel-mft*"
    # CUDA 13 cccl packages obsolete cuda-cccl-12-*, which is still required
    # by cuda-cudart-devel-12-* and makes later DNF transactions unsolvable.
    if [[ "${CUDA_DRIVER_VERSION}" == 12.* ]]; then
        cuda_excludes="${cuda_excludes} cccl-*"
    fi

    dnf config-manager --save \
        --setopt="cuda-${CUDA_DRIVER_DISTRIBUTION}-x86_64.excludepkgs=${cuda_excludes}" >/dev/null

    dnf clean expire-cache
    dnf install -y cuda-toolkit-${CUDA_DRIVER_VERSION//./-}
fi

echo 'export PATH="${PATH:+$PATH:}/usr/local/cuda/bin"' | tee /etc/profile.d/cuda.sh > /dev/null
echo 'export LD_LIBRARY_PATH="${LD_LIBRARY_PATH:+$LD_LIBRARY_PATH:}/usr/local/cuda/lib64"' | tee -a /etc/profile.d/cuda.sh > /dev/null
chmod 644 /etc/profile.d/cuda.sh

cuda_version=$(source /etc/profile; nvcc --version | grep release | awk '{print $6}' | cut -c2-)
write_component_version "CUDA" ${cuda_version}

#$COMPONENT_DIR/install_cuda_samples.sh
$COMPONENT_DIR/configure_nvidia_persistence.sh

# cleanup downloaded files
rm -rf *.run *.tar.gz *.rpm
(
	shopt -s dotglob nullglob
	rm -rf -- */ || true
)
