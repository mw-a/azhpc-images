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
. /etc/os-release
case "$VERSION_ID" in
	9.*) dnf config-manager --set-enabled crb ;;
	8.*) dnf config-manager --set-enabled powertools ;;
esac
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
spec=$rpmbuild_base/SPECS/kernel.spec
rpmbuild -bp $spec --target=$rpmarch --define="dist $dist"

tarballrel=$(grep define.*tarfile_release $spec | awk '{print $3}')
if [ -n "$tarballrel" ] ; then
        specver=$(grep define.*specversion $spec | awk '{print $3}')
        tarballver=$specver-$tarballrel
else
        tarballver=$kernvernoarch
fi

kernsrc=$rpmbuild_base/BUILD/kernel-$tarballver/linux-$kernver
pushd $kernsrc

# copy existing distro config
cp /boot/config-$kernver .config

# prepare module build
kernextraver=$(echo $kernver | sed "s/^[0-9]*\.[0-9]*\.[0-9]*//")
sed -i "s/EXTRAVERSION =.*/EXTRAVERSION = $kernextraver/" Makefile

case "$kernver" in
	# smb client was moved from fs/cifs to fs/smb/client somewhere
	# inbetween 4.18 and 5.6
	[5-9].*)	smbdir=fs/smb/client ;;
	*)		smbdir=fs/cifs ;;
esac

# finally build cifs module like an out-of-tree module so it picks up the
# modified Modules.symvers from OFED. Otherwise it still seems to build with
# internal kernel headers so symbols in OFED are still required to be
# binary-compatible.
make -j$(nproc) -C /lib/modules/`uname -r`/build \
	M=$PWD/"$smbdir" \
	KBUILD_EXTRA_SYMBOLS=/etc/alternatives/ofa_kernel_headers/Module.symvers

# install the module
stockmod=/lib/modules/$kernver/kernel/"$smbdir"/cifs.ko.xz
mv "$stockmod" "$stockmod".disabled
xz < "$smbdir"/cifs.ko > "$stockmod"

# move OFED dummy out of the way and update dependencies to make recompiled
# stock module visible again
# no dummy module for 5.x kernels (yet)
dummymod=/lib/modules/$kernver/extra/mlnx-ofa_kernel/"$smbdir"/cifs.ko
[ ! -f "$dummymod" ] || mv "$dummymod" "$dummymod".disabled
depmod -a

popd
popd
rm -rf "$tmp" ~/rpmbuild
