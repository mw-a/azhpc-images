#!/bin/bash
set -ex

# Expected params:
# $1 = the major version of the distro. "8" for RHEL/Alma8, "9" for RHEL/Alma9.

DISTRIB_CODENAME="el$1"
REPO_PATH=/etc/yum.repos.d/amlfs.repo

rpm --import https://packages.microsoft.com/keys/microsoft.asc

echo -e "[amlfs]" > ${REPO_PATH}
echo -e "name=Azure Lustre Packages" >> ${REPO_PATH}
echo -e "baseurl=https://packages.microsoft.com/yumrepos/amlfs-${DISTRIB_CODENAME}" >> ${REPO_PATH}
echo -e "enabled=1" >> ${REPO_PATH}
echo -e "gpgcheck=1" >> ${REPO_PATH}
echo -e "gpgkey=https://packages.microsoft.com/keys/microsoft.asc" >> ${REPO_PATH}
echo "" >> ${REPO_PATH}
echo -e "[amlfs-test]" >> ${REPO_PATH}
echo -e "name=Azure Lustre Packages Test" >> ${REPO_PATH}
echo -e "baseurl=https://packages.microsoft.com/yumrepos/amlfs-${DISTRIB_CODENAME}-test" >> ${REPO_PATH}
echo -e "enabled=1" >> ${REPO_PATH}
echo -e "gpgcheck=1" >> ${REPO_PATH}
echo -e "gpgkey=https://packages.microsoft.com/keys/microsoft.asc" >> ${REPO_PATH}
echo -e "exclude=lustre-client-dkms*" >> ${REPO_PATH}
