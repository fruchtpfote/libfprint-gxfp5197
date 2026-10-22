#!/bin/sh
# SPDX-License-Identifier: LGPL-2.1-or-later
# Root step R4: installs the locally built libfprint-2-2 with goodixtls, pins
# it against Debian updates and restarts fprintd with the gpiochip drop-in.
#     sudo sh packaging/install.sh
set -eu
R=$(cd "$(dirname "$0")/.." && pwd)
[ "$(id -u)" -eq 0 ] || { echo "run with sudo" >&2; exit 1; }
apt-get install "$R"/build/deb/libfprint-2-2_1.94.9-1+gxfp5197.3_amd64.deb
install -m 0644 "$R/packaging/99-libfprint-goodixtls.pref" /etc/apt/preferences.d/
systemctl daemon-reload
systemctl try-restart fprintd
apt-cache policy libfprint-2-2 | head -3
