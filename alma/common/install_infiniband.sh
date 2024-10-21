#!/bin/bash
set -ex

dnf groupinstall -y "Infiniband support"
dnf install -y ucx-rdmacm ucx-ib ucx-devel
