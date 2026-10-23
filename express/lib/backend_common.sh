# SPDX-License-Identifier: LGPL-2.1-or-later
# Shared by the three backends.

GX_BUILD=${GX_BUILD:-$GX_DIR/build}

# gx_missing DISTRO PKG...: prints the packages that are not installed.
gx_missing() {
  local distro=$1 p
  shift
  for p in "$@"; do
    case $distro in
      debian) dpkg-query -W -f='${Status}' "$p" 2>/dev/null | grep -q 'ok installed' ;;
      fedora) rpm -q --whatprovides "$p" >/dev/null 2>&1 ;;
      arch)   pacman -T "$p" >/dev/null 2>&1 ;;
    esac || echo "$p"
  done
}

# gx_install_missing DISTRO DESC_KEY PKG...: installs what is missing, in one
# command, and records each package so the uninstall can offer to remove it.
gx_install_missing() {
  local distro=$1 desc=$2 p
  shift 2
  mapfile -t miss < <(gx_missing "$distro" "$@")
  [ ${#miss[@]} -gt 0 ] || return 0
  case $distro in
    debian) gx_run_root "$desc" -- apt-get install -y --no-install-recommends "${miss[@]}" ;;
    fedora) gx_run_root "$desc" -- dnf install -y "${miss[@]}" ;;
    arch)   gx_run_root "$desc" -- pacman -S --needed --noconfirm "${miss[@]}" ;;
  esac || return 1
  for p in "${miss[@]}"; do
    # Fedora installs capabilities such as pkgconfig(glib-2.0); record the
    # package that provides it, the only name dnf remove accepts.
    if [ "$distro" = fedora ]; then
      p=$(rpm -q --whatprovides "$p" --qf '%{NAME}\n' 2>/dev/null | head -1)
      [ -n "$p" ] || continue
    fi
    gx_state_add_once pkg_added "$p"
  done
}

# After a new libfprint: bind the sensor to spidev and restart fprintd with
# the new drop-in.
gx_activate() {
  gx_run_root activate -- udevadm trigger --action=add --subsystem-match=spi &&
    gx_run_root activate -- systemctl daemon-reload &&
    gx_run_root activate -- systemctl restart fprintd
}

gx_spidev_modprobe_set() {
  gx_run_root spidev_set -- install -D -m 0644 \
    "$GX_DIR/packaging/gxfp5197-spidev.modprobe.conf" \
    "$(gx_r /etc/modprobe.d/gxfp5197-spidev.conf)" || return 1
  gx_state_add_once spidev modprobe
}

gx_spidev_manual() {
  gx_msg spidev_manual "$GX_SPIDEV_PARAM"
  return 1
}
