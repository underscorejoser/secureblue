#!/usr/bin/env bash

# SPDX-FileCopyrightText: Copyright 2025-2026 The Secureblue Authors
#
# SPDX-License-Identifier: Apache-2.0

set -euo pipefail

declare -a desktop_packages+=(
    'libnvidia-fbc' 'nvidia-persistenced' 'nvidia-settings' 'nvidia-libXNVCtrl'
)

is_desktop='false'
[[ "${IMAGE_NAME}" != *'securecore'* && "${IMAGE_NAME}" != *'iot'* ]] && is_desktop='true'

declare -a packages=('libva-nvidia-driver')
if [[ "${IMAGE_NAME}" == *open* ]]; then
    packages+=('nvidia-driver-cuda')
    [[ "${is_desktop}" == 'true' ]] && packages+=("${desktop_packages[@]}")
else
    packages+=('nvidia-driver-580xx-cuda')
    [[ "${is_desktop}" == 'true' ]] && packages+=("${desktop_packages[@]/%/-580xx}")
fi

source "$(dirname "$0")"/terra.sh

# shellcheck disable=SC2312
IFS=" " read -r -a rpms <<< "$(download_and_verify terra-nvidia "${packages[@]}")"

dnf install -y --setopt=install_weak_deps=False \
    --enable-repo='terra-nvidia' \
    --disable-repo='fedora-multimedia' \
    "${rpms[@]}"

dnf install -y --setopt=install_weak_deps=False --enable-repo='nvidia-container-toolkit' nvidia-container-toolkit

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
