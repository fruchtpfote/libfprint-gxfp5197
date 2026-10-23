# SPDX-License-Identifier: LGPL-2.1-or-later
# Debian 13: Debian's libfprint source, our patch, dpkg-buildpackage.

debian_builddeps() {
  local deps
  read -r -a deps <<< "$(grep -v '^#' "$GX_DIR/packaging/debian-builddeps.txt" | tr '\n' ' ')"
  gx_install_missing debian builddeps "${deps[@]}"
}

debian_build() {
  gx_run_user build_pkg -- sh "${GXE_DEB_BUILD:-$GX_DIR/packaging/build-deb.sh}" || return 1
  GX_PKG=$(ls "$GX_BUILD"/deb/libfprint-2-2_*_amd64.deb 2>/dev/null | head -1)
  [ -n "$GX_PKG" ]
}

debian_install() {
  local stock
  stock=$(gx_detect_libfprint_stock debian)
  gx_install_missing debian runtime fprintd libpam-fprintd || return 1
  gx_run_root install_pkg -- apt-get install -y "$1" || return 1
  gx_state_add_once driver debian "$stock"
  gx_activate
}

debian_lock() {
  gx_run_root lock -- install -D -m 0644 "$GX_DIR/packaging/99-libfprint-goodixtls.pref" \
    "$(gx_r /etc/apt/preferences.d/99-libfprint-goodixtls.pref)" || return 1
  gx_state_add_once lock apt-pin
}

debian_restore_stock() {
  local v=${1:-} avail
  avail=$(gx_detect_libfprint_stock debian)
  # The recorded version may be gone from the archive by now.
  [ -n "$v" ] && apt-cache madison libfprint-2-2 2>/dev/null | grep -q " $v " || v=$avail
  gx_run_root restore -- apt-get install -y --allow-downgrades "libfprint-2-2=$v"
}

debian_remove_pkgs() {
  gx_run_root remove_pkgs -- apt-get remove -y "$@"
}

debian_spidev_param_set() {
  gx_run_root spidev_set -- install -D -m 0644 "$GX_DIR/packaging/gxfp5197-spidev.grub.cfg" \
    "$(gx_r /etc/default/grub.d/gxfp5197-spidev.cfg)" || return 1
  gx_state_add_once spidev grub-dropin
  gx_run_root bootcfg -- update-grub
}
