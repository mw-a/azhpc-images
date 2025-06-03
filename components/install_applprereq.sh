#!/bin/sh
set -ex

# xfsprogs xfsdump cryptsetup mdadm lvm2 are actually prereqs for cyclecloud's cvolume!
# libpq is openpbs prereq
# azure-cli for reverse dns update

. /etc/os-release
case "$VERSION_ID" in
	9.*) distpkgs= ;;
	8.*) distpkgs="lsb python2 \
		python39 python39-requests \
		python3.11 python3.11-requests \
		python3.12 python3.12-requests \
		python3-pandas \
		python3-numpy python39-numpy python3.11-numpy python3.12-numpy \
		compat-openssl10" ;;
esac

dnf install -y epel-release
dnf install -y tmux screen vim-enhanced libXp motif libnsl xterm perl-Locale-Maketext perl-Sys-Syslog \
	xfsprogs xfsdump cryptsetup mdadm lvm2 azure-cli libpq grace svn boost glibc.i686 $distpkgs
