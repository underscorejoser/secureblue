#!/usr/bin/env bash

# SPDX-FileCopyrightText: Copyright 2026 The Secureblue Authors
#
# SPDX-License-Identifier: Apache-2.0

set -euo pipefail
shopt -s extglob

ARCH="$(uname -m)"

download_and_verify() {
    declare -r repo="$1"
    declare -a packages_to_download
    IFS=" " read -r -a packages_to_download <<< "${@:2}" 

    dnf --best --repo="${repo}" -y download "${packages_to_download[@]}" &>/dev/null

    declare -a return_packages=()
    for package in "${packages_to_download[@]}"; do
        for rpm in "${package}"*.@("${ARCH}"|noarch).rpm; do
            # gh attestation verify --repo terrapkg/packages "${rpm}" &>/dev/null
            true # TODO: remove when they fix it.
            return_packages+=("${rpm}")
        done
    done
    # return
    echo "${return_packages[@]}"
}

swap_packages() {
    declare -r repo="$1"
    declare -nr packages_ref="$2"

    for i in "${!packages_ref[@]}"; do
        declare old_package="${i}"
        declare new_package="${packages_ref[${i}]}"

        echo "Swapping ${old_package} with ${new_package}"

        dnf --setopt=install_weak_deps=False swap --from-repo="${repo}" "${old_package}" "${new_package}"
    done
}
