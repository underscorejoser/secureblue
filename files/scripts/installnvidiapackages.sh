#!/usr/bin/env bash

# SPDX-FileCopyrightText: Copyright 2025-2026 The Secureblue Authors
#
# SPDX-License-Identifier: Apache-2.0

set -euo pipefail

declare -a nvidia_packages_list=('libva-nvidia-driver' 'nvidia-container-toolkit')
declare -a nvidia_desktop_packages_list+=(
    'libnvidia-fbc' 'nvidia-driver' 'nvidia-modprobe' 'nvidia-persistenced' 'nvidia-settings'
)

is_desktop='false'
[[ "${IMAGE_NAME}" != *'securecore'* && "${IMAGE_NAME}" != *'iot'* ]] && is_desktop='true'

declare -a packages_to_install=("${nvidia_packages_list[@]}")
if [[ "${IMAGE_NAME}" == *open* ]]; then
    packages_to_install+=('nvidia-driver-cuda')
    [[ "${is_desktop}" == 'true' ]] && packages_to_install+=("${nvidia_desktop_packages_list[@]}")
else
    packages_to_install+=('nvidia-driver-580xx-cuda')
    [[ "${is_desktop}" == 'true' ]] && packages_to_install+=("${nvidia_desktop_packages_list[@]/%/-580xx}")
fi

dnf install -y --setopt=install_weak_deps=False \
    --enable-repo='terra-nvidia' \
    --enable-repo='nvidia-container-toolkit' \
    --disable-repo='fedora-multimedia' \
    "${packages_to_install[@]}"

kmod_version=$(rpm -qa | grep akmod-nvidia | awk -F':' '{print $(NF)}' | awk -F'-' '{print $(NF-1)}')
terra_version=$(rpm -qa | grep nvidia-modprobe | awk -F':' '{print $(NF)}' | awk -F'-' '{print $(NF-1)}')

echo "kmod_version: ${kmod_version}"
echo "terra_version: ${terra_version}"
if [[ "${kmod_version}" != "${terra_version}" ]]; then
    echo 'Version mismatch!'
    exit 1
fi

cd ./selinux/nvidia-container
make -f /usr/share/selinux/devel/Makefile nvidia-container.pp
semodule -v -X 300 -i nvidia-container.pp
