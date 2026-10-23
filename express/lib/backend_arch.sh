# SPDX-License-Identifier: LGPL-2.1-or-later
# Arch: Arch's libfprint PKGBUILD plus our patch, makepkg.

# makepkg -s would install the dependencies itself, unrecorded; install them
# here instead.
arch_builddeps() {
  gx_install_missing arch builddeps base-devel git glib2 glib2-devel libgudev \
    libgusb openssl pixman gobject-introspection gtk-doc meson python-cairo \
    python-gobject systemd cairo umockdev
}

arch_build() {
  local w=$GX_BUILD/arch
  mkdir -p "$w"
  cp "$GX_DIR/packaging/arch/PKGBUILD" \
     "$GX_DIR/packaging/patches/1.94.100/0100-goodixtls-gxfp5197.patch" \
     "$GX_DIR/packaging/fprintd-goodixtls.conf" "$w/"
  (cd "$w" && gx_run_user build_pkg -- makepkg -f --noconfirm) || return 1
  GX_PKG=$(ls "$w"/libfprint-1*-x86_64.pkg.tar.zst 2>/dev/null | grep -v debug | head -1)
  [ -n "$GX_PKG" ]
}

arch_install() {
  local stock
  stock=$(gx_detect_libfprint_stock arch)
  gx_install_missing arch runtime fprintd || return 1
  gx_run_root install_pkg -- pacman -U --noconfirm "$1" || return 1
  gx_state_add_once driver arch "$stock"
  gx_activate
}

arch_lock() {
  local f
  f=$(gx_r /etc/pacman.conf)
  if grep -Eq '^[[:space:]]*IgnorePkg[[:space:]]*=.*(^|[[:space:]=])libfprint([[:space:]]|$)' "$f"; then
    :
  elif grep -Eq '^[[:space:]]*IgnorePkg[[:space:]]*=' "$f"; then
    gx_run_root lock -- sed -i -E '0,/^[[:space:]]*IgnorePkg[[:space:]]*=/{/^[[:space:]]*IgnorePkg[[:space:]]*=/s/[[:space:]]*$/ libfprint/}' "$f" || return 1
  elif grep -Eq '^#[[:space:]]*IgnorePkg[[:space:]]*=' "$f"; then
    gx_run_root lock -- sed -i -E '0,/^#[[:space:]]*IgnorePkg/s/^#[[:space:]]*IgnorePkg[[:space:]]*=.*$/IgnorePkg = libfprint/' "$f" || return 1
  else
    gx_run_root lock -- sed -i '/^\[options\]/a IgnorePkg = libfprint' "$f" || return 1
  fi
  gx_state_add_once lock ignorepkg
}

arch_restore_stock() {
  gx_run_root restore -- pacman -S --noconfirm libfprint
}

arch_remove_pkgs() {
  gx_run_root remove_pkgs -- pacman -Rns --noconfirm "$@"
}

arch_spidev_param_set() {
  local bl b
  bl=$(gx_detect_bootloader)
  case $bl in
    grub)
      b=$(gx_backup /etc/default/grub)
      gx_log "backup /etc/default/grub -> $b"
      gx_run_root spidev_set -- sed -i -E \
        -e '/^GRUB_CMDLINE_LINUX_DEFAULT=""/s/""/"spidev.bufsiz=65536"/' \
        -e '/^GRUB_CMDLINE_LINUX_DEFAULT=/{/spidev\.bufsiz=65536/!s/"$/ spidev.bufsiz=65536"/}' \
        "$(gx_r /etc/default/grub)" || return 1
      gx_state_add_once spidev grub-default
      gx_run_root bootcfg -- grub-mkconfig -o /boot/grub/grub.cfg ;;
    systemd-boot)
      gx_run_root spidev_set -- sh -c \
        "sed -i '/^options/{/spidev\\.bufsiz=65536/!s/\$/ spidev.bufsiz=65536/}' $(gx_r /boot/loader/entries)/*.conf" || return 1
      gx_state_add_once spidev sdboot ;;
    *)
      gx_spidev_manual ;;
  esac
}
