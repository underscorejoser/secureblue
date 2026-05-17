#!/usr/bin/env bash

# SPDX-FileCopyrightText: Copyright 2025 Universal Blue
# SPDX-FileCopyrightText: Copyright 2025-2026 The Secureblue Authors
#
# SPDX-License-Identifier: Apache-2.0

set -euo pipefail

mkdir -p /var/tmp
chmod 1777 /var/tmp

KERNEL_VERSION="$(rpm -q 'kernel' --queryformat '%{VERSION}')"
KERNEL_RELEASE="$(rpm -q 'kernel' --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}')"

# shellcheck disable=SC2312
dnf install -y --setopt=install_weak_deps=False "kernel-devel-matched-${KERNEL_VERSION}"
dnf install -y --setopt=install_weak_deps=False akmods gcc-c++

if [[ "${IMAGE_NAME}" == *open* ]]; then
    packages=(
        'akmod-nvidia' 'nvidia-kmod-common' 'nvidia-modprobe'
        'libnvidia-cfg' 'libnvidia-gpucomp' 'libnvidia-ml'
        'nvidia-driver' 'nvidia-driver-cuda-libs' 'nvidia-driver-libs'
    )
    nvidia_kmod='nvidia'
else
    packages=(
        'akmod-nvidia-580xx' 'nvidia-580xx-kmod-common' 'nvidia-modprobe-580xx'
        'libnvidia-cfg-580xx' 'libnvidia-gpucomp-580xx' 'libnvidia-ml-580xx'
        'nvidia-driver-580xx' 'nvidia-driver-580xx-cuda-libs' 'nvidia-driver-580xx-libs'
    )
    nvidia_kmod='nvidia-580xx'
fi

source "$(dirname "$0")"/terra.sh

# shellcheck disable=SC2312
IFS=" " read -r -a rpms <<< "$(download_and_verify terra-nvidia "${packages[@]}")"

# TODO remove this when fixed upstream
sed -i.backup -e '/if \[\[ -w \/var \]\] ; then/,/fi/d' /usr/sbin/akmodsbuild

dnf install -y --setopt=install_weak_deps=False \
    --enable-repo='terra-nvidia' \
    --disable-repo='fedora-multimedia' \
    "${rpms[*]}"

echo "Installing kmod..."
akmods --force --kernels "${KERNEL_RELEASE}" --kmod "${nvidia_kmod}"

mv /usr/sbin/akmodsbuild.backup /usr/sbin/akmodsbuild

modinfo /usr/lib/modules/"${KERNEL_RELEASE}"/extra/"${nvidia_kmod}"/nvidia{,-drm,-modeset,-peermem,-uvm}.ko.xz > /dev/null || \
    { cat /var/cache/akmods/"${nvidia_kmod}"/*.failed.log && exit 1; }

# View license information
modinfo -l /usr/lib/modules/"${KERNEL_RELEASE}"/extra/"${nvidia_kmod}"/nvidia{,-drm,-modeset,-peermem,-uvm}.ko.xz

./signmodules.sh "${nvidia_kmod}"

systemctl disable akmods-keygen@akmods-keygen.service akmods-keygen.target
systemctl mask akmods-keygen@akmods-keygen.service akmods-keygen.target
