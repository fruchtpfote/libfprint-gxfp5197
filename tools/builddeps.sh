#!/bin/sh
# SPDX-License-Identifier: LGPL-2.1-or-later
# Root step: build dependencies of libfprint 1:1.94.9-1 plus packaging tools
# (list in packaging/debian-builddeps.txt). Installs packages only; touches
# neither apt sources nor the sensor.
set -eu
[ "$(id -u)" -eq 0 ] || { echo "run with sudo" >&2; exit 1; }
R=$(cd "$(dirname "$0")/.." && pwd)
# shellcheck disable=SC2046
apt-get install --no-install-recommends \
  $(grep -v '^#' "$R/packaging/debian-builddeps.txt") lintian
