#!/bin/bash
set -ex

dnf groupinstall -y "Infiniband support"
dnf install -y rdma-core-devel ucx-rdmacm ucx-ib ucx-devel
