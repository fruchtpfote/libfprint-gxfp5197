#!/bin/sh
# SPDX-License-Identifier: LGPL-2.1-or-later
# Root step R3: build dependencies of libfprint 1:1.94.9-1 (from its
# debian/control, as dpkg-checkbuilddeps lists them) plus packaging tools.
# Installs packages only; touches neither apt sources nor the sensor.
set -eu
[ "$(id -u)" -eq 0 ] || { echo "run with sudo" >&2; exit 1; }
apt-get install --no-install-recommends \
  debhelper dh-sequence-gir gir1.2-gobject-2.0-dev gir1.2-gio-2.0-dev \
  gtk-doc-tools libcairo-dev libgirepository1.0-dev libglib2.0-dev \
  libgudev-1.0-dev libgusb-dev libpixman-1-dev libssl-dev systemd-dev \
  umockdev libglib2.0-doc libgusb-doc \
  devscripts lintian
