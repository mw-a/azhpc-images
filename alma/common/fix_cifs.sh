#!/bin/bash

set -e

# building the Redhat stock cifs kernel module after OFED
# has been installed following
# https://www.pixelbeat.org/docs/rebuild_kernel_module.html

tmp=$(mktemp -d)
pushd "$tmp"

kernver=$(uname -r)
rpmarch=$(rpm -q --qf="%{ARCH}\n" kernel | head -n1)

# download kernel source RPM automatically (requires source repo to be available):
yum -y install yum-utils
dnf config-manager --set-enabled powertools
yumdownloader --source --disableexcludes all kernel-$kernver

kernvernoarch=$(echo $kernver | sed -n "\$s/\.$rpmarch$//p")
rpmbase=kernel-$kernvernoarch

# install the source RPM for building
rpm -ivh $rpmbase.src.rpm

# install build dependencies automatically:
yum-builddep --disableexcludes all -y kernel

# prepare kernel source
rpmbuild_base=~/rpmbuild
dist=.el${kernvernoarch##*.el}
rpmbuild -bp $rpmbuild_base/SPECS/kernel.spec --target=$rpmarch --define="dist $dist"

kernsrc=$rpmbuild_base/BUILD/kernel-$kernvernoarch/linux-$kernver
pushd $kernsrc

# copy existing distro config
cp /boot/config-$kernver .config

# prepare module build
kernextraver=$(echo $kernver | sed "s/^[0-9]*\.[0-9]*\.[0-9]*//")
sed -i "s/EXTRAVERSION =.*/EXTRAVERSION = $kernextraver/" Makefile
make -j$(nproc) oldconfig prepare scripts_build

# build the whole kernel to get a Module.symvers file to make dependencies and
# versioning work as expected and avoid warning messages upon module load,
# includes build of all modules, including cifs which will be built in-tree and
# thus still incompatible with OFED
#make -j$(nproc)

# clean out the in-tree build of the cifs module
#make -j$(nproc) SUBDIRS=fs/cifs/ clean

# instead of rebuilding the whole kernel, use kernel-devel Module.symvers for
# massive speed-up
cp /lib/modules/$kernver/build/Module.symvers .

# copy over the OFED symbol and version registry for the module rebuild to pick
# up (see Section 6 of Documentation/kbuild/modules.txt about automatic
# additional pick-up of Modules.symver in build directories of out-of-tree
# modules)
# use alternatives link as DOCA provides pre-built upstream packages as well
# whose install path in /usr/src cannot easily be guessed (e.g. path component
# 4.18.0-553.el8_10 instead of actual host kernel version
# 4.18.0.553.16.1.el8_10). symvers seem to match still.
cp /etc/alternatives/ofa_kernel_headers/Module.symvers fs/cifs/

# finally build cifs module like an out-of-tree module so it picks up the
# modified Modules.symvers from OFED. Otherwise it still seems to build with
# internal kernel headers so symbols in OFED are still required to be
# binary-compatible.
make -j$(nproc) SUBDIRS=fs/cifs modules

# install the module
mv /lib/modules/$kernver/kernel/fs/cifs/cifs.ko.xz /lib/modules/$kernver/kernel/fs/cifs/cifs.ko.xz.disabled
xz < fs/cifs/cifs.ko > /lib/modules/$kernver/kernel/fs/cifs/cifs.ko.xz

# move OFED dummy out of the way and update dependencies to make recompiled
# stock module visible again
mv /lib/modules/$kernver/extra/mlnx-ofa_kernel/fs/cifs/cifs.ko /lib/modules/$kernver/extra/mlnx-ofa_kernel/fs/cifs/cifs.ko.disabled
depmod -a

popd
popd
rm -rf "$tmp" ~/rpmbuild
