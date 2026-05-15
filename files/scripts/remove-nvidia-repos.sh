#!/usr/bin/env bash

# SPDX-FileCopyrightText: Copyright 2025-2026 The Secureblue Authors
#
# SPDX-License-Identifier: Apache-2.0

set -euo pipefail

# Nvidia repos only used during build process
rm -f \
    /etc/yum.repos.d/terra-nvidia.repo \
    /etc/yum.repos.d/nvidia-container-toolkit.repo
