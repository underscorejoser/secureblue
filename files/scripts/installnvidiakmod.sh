#!/usr/bin/env bash

# SPDX-FileCopyrightText: Copyright 2025 Universal Blue
# SPDX-FileCopyrightText: Copyright 2025-2026 The Secureblue Authors
#
# SPDX-License-Identifier: Apache-2.0

set -euo pipefail

mkdir -p /var/tmp
chmod 1777 /var/tmp

if [[ "${IMAGE_NAME}" == *open* ]]; then
    packages=('nvidia-kmod-common' 'nvidia-modprobe' 'akmod-nvidia')
    nvidia_kmod='nvidia'
else
    packages=('nvidia-580xx-kmod-common' 'nvidia-modprobe-580xx' 'akmod-nvidia-580xx')
    nvidia_kmod='nvidia-580xx'
fi

# shellcheck disable=SC2312
dnf install -y --setopt=install_weak_deps=False "kernel-devel-matched-$(rpm -q 'kernel' --queryformat '%{VERSION}')"

dnf install -y --setopt=install_weak_deps=False akmods gcc-c++

# TODO remove this when fixed upstream
sed -i.backup -e '/if \[\[ -w \/var \]\] ; then/,/fi/d' /usr/sbin/akmodsbuild

dnf install -y --setopt=install_weak_deps=False \
    --enable-repo='terra-nvidia' \
    --disable-repo='fedora-multimedia' \
    "${packages[@]}"

KERNEL_VERSION="$(rpm -q 'kernel' --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}')"

echo "Installing kmod..."
akmods --force --kernels "${KERNEL_VERSION}" --kmod "${nvidia_kmod}"

mv /usr/sbin/akmodsbuild.backup /usr/sbin/akmodsbuild

modinfo /usr/lib/modules/"${KERNEL_VERSION}"/extra/"${nvidia_kmod}"/nvidia{,-drm,-modeset,-peermem,-uvm}.ko.xz > /dev/null || \
    { cat /var/cache/akmods/"${nvidia_kmod}"/*.failed.log && exit 1; }

# View license information
modinfo -l /usr/lib/modules/"${KERNEL_VERSION}"/extra/"${nvidia_kmod}"/nvidia{,-drm,-modeset,-peermem,-uvm}.ko.xz

./signmodules.sh "${nvidia_kmod}"

systemctl disable akmods-keygen@akmods-keygen.service akmods-keygen.target
systemctl mask akmods-keygen@akmods-keygen.service akmods-keygen.target
