# SPDX-License-Identifier: LGPL-2.1-or-later
# Fedora: Fedora's libfprint source RPM, our patch, rpmbuild.

fedora_builddeps() {
  gx_install_missing fedora builddeps rpm-build dnf5-plugins || return 1
  # The source RPM names its BuildRequires as capabilities; install the
  # missing ones the same way, so each can be removed again.
  local srpm caps
  srpm=$(sh "$GX_DIR/packaging/fedora/build-rpm.sh" --fetch) || return 1
  mapfile -t caps < <(rpm -qp --requires "$srpm" 2>/dev/null | grep -v '^rpmlib(' | awk '{print $1}')
  gx_install_missing fedora builddeps "${caps[@]}"
}

fedora_build() {
  gx_run_user build_pkg -- sh "$GX_DIR/packaging/fedora/build-rpm.sh" || return 1
  GX_PKG=$(ls "$GX_BUILD"/rpm/RPMS/x86_64/libfprint-1*.gxfp5197.*.x86_64.rpm 2>/dev/null | head -1)
  [ -n "$GX_PKG" ]
}

fedora_install() {
  local stock
  stock=$(gx_detect_libfprint_stock fedora)
  gx_install_missing fedora runtime fprintd fprintd-pam || return 1
  gx_run_root install_pkg -- dnf install -y "$1" || return 1
  gx_state_add_once driver fedora "$stock"
  gx_activate
}

fedora_lock() {
  gx_run_root lock -- dnf versionlock add libfprint || return 1
  gx_state_add_once lock versionlock
}

# Whatever version the repositories carry now.
fedora_restore_stock() {
  gx_run_root restore -- dnf distro-sync -y libfprint
}

fedora_remove_pkgs() {
  gx_run_root remove_pkgs -- dnf remove -y "$@"
}

fedora_spidev_param_set() {
  gx_run_root spidev_set -- grubby --update-kernel=ALL --args="$GX_SPIDEV_PARAM" || return 1
  gx_state_add_once spidev grubby
}
