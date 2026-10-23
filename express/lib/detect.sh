# SPDX-License-Identifier: LGPL-2.1-or-later
# Detection: distribution, libfprint versions, sensor, spidev, boot loader and
# the traces of an existing installation. Read-only.
#
# Every system path goes through GXE_ROOT (tests), sysfs through GXE_SYSFS.

GX_PAM_LINE="auth sufficient pam_fprintd.so max-tries=1 timeout=10"
GX_SPIDEV_PARAM="spidev.bufsiz=65536"
GX_DROPIN=/usr/lib/systemd/system/fprintd.service.d/goodixtls.conf

gx_r()   { printf '%s%s' "${GXE_ROOT:-}" "$1"; }
gx_sys() { printf '%s%s' "${GXE_SYSFS:-${GXE_ROOT:-}/sys}" "$1"; }

# Read-only command as root (traces live in root-only places).
gx_rsh() { ${GXE_SUDO-sudo} "$@"; }

gx_detect_distro() {
  local f id ver
  f=$(gx_r /etc/os-release)
  [ -r "$f" ] || { echo "unsupported:unknown"; return; }
  # shellcheck disable=SC1090
  id=$(. "$f"; echo "${ID:-unknown}")
  ver=$(. "$f"; echo "${VERSION_ID:-}")
  case $id in
    debian) [ "$ver" = 13 ] && echo debian || echo "unsupported:debian" ;;
    fedora) echo fedora ;;
    arch)   echo arch ;;
    *)      echo "unsupported:$id" ;;
  esac
}

# The distribution's own libfprint version, from its repositories.
gx_detect_libfprint_stock() {
  case $1 in
    debian)
      apt-cache madison libfprint-2-2 2>/dev/null |
        awk -F' *\\| *' '$2 !~ /gxfp5197/ && $3 !~ /dpkg\/status/ {print $2; exit}' ;;
    fedora)
      dnf -q repoquery --available --qf '%{evr}\n' libfprint 2>/dev/null |
        grep -v gxfp5197 | sort -V | tail -1 ;;
    arch)
      pacman -Si libfprint 2>/dev/null | awk -F' *: *' '$1 == "Version" {print $2; exit}' ;;
  esac
}

# "1:1.94.9-1" -> "1.94.9"
gx_upstream_version() {
  local v=${1#*:}
  echo "${v%%-*}"
}

gx_patch_for_version() {
  case $(gx_upstream_version "$1") in
    1.94.9)   echo "$GX_DIR/packaging/patches/0100-goodixtls-gxfp5197.patch" ;;
    1.94.100) echo "$GX_DIR/packaging/patches/1.94.100/0100-goodixtls-gxfp5197.patch" ;;
    *) return 1 ;;
  esac
}

gx_detect_sensor() {
  local id d
  for id in GXFP5197 GXFP5187; do
    for d in "$(gx_sys /bus/acpi/devices)/$id":*; do
      [ -e "$d" ] && { echo "$id"; return; }
    done
  done
}

gx_spidev_builtin() {
  local k=${GXE_KREL:-$(uname -r)} f
  for f in "$(gx_r /lib/modules/"$k"/modules.builtin)" \
           "$(gx_r /usr/lib/modules/"$k"/modules.builtin)"; do
    [ -r "$f" ] && grep -q '/spidev\.ko$' "$f" && return 0
  done
  return 1
}

gx_spidev_bufsiz_ok() {
  local f v
  f=$(gx_sys /module/spidev/parameters/bufsiz)
  [ -r "$f" ] || return 1
  v=$(cat "$f")
  [ "$v" -ge 65536 ] 2>/dev/null
}

gx_detect_bootloader() {
  if [ -e "$(gx_r /boot/grub/grub.cfg)" ] || [ -e "$(gx_r /boot/grub2/grub.cfg)" ]; then
    echo grub
  elif [ -d "$(gx_r /boot/loader/entries)" ]; then
    echo systemd-boot
  else
    echo unknown
  fi
}

gx_installed_libfprint() {
  case $1 in
    debian) dpkg-query -W -f='${Version}' libfprint-2-2 2>/dev/null ;;
    fedora) rpm -q --qf '%{VERSION}-%{RELEASE}' libfprint 2>/dev/null ;;
    arch)   pacman -Q libfprint 2>/dev/null | awk '{print $2}' ;;
  esac
}

gx_pam_has_line() {
  local f
  f=$(gx_r /etc/pam.d/sudo)
  [ -r "$f" ] && grep -Eq '^[[:space:]]*auth[[:space:]].*pam_fprintd\.so' "$f"
}

# One tab-separated line per trace found; nothing on a clean system.
gx_detect_traces() {
  local distro=$1 v d u
  if [ -e "$(gx_r "$GX_DROPIN")" ]; then
    v=$(gx_installed_libfprint "$distro")
    printf 'driver\t%s\n' "$v"
  fi
  case $distro in
    debian)
      [ -e "$(gx_r /etc/apt/preferences.d/99-libfprint-goodixtls.pref)" ] &&
        printf 'lock\tapt-pin\n' ;;
    fedora)
      dnf versionlock list 2>/dev/null | grep -q '^libfprint-' &&
        printf 'lock\tversionlock\n' ;;
    arch)
      grep -Eq '^[[:space:]]*IgnorePkg[[:space:]]*=.*\blibfprint\b' \
          "$(gx_r /etc/pacman.conf)" 2>/dev/null &&
        printf 'lock\tignorepkg\n' ;;
  esac
  [ -e "$(gx_r /etc/default/grub.d/gxfp5197-spidev.cfg)" ] && printf 'spidev\tgrub-dropin\n'
  [ -e "$(gx_r /etc/modprobe.d/gxfp5197-spidev.conf)" ] && printf 'spidev\tmodprobe\n'
  if [ "$distro" = fedora ]; then
    grubby --info=ALL 2>/dev/null | grep -q "$GX_SPIDEV_PARAM" && printf 'spidev\tgrubby\n'
  fi
  if [ "$distro" = arch ]; then
    grep -q "^GRUB_CMDLINE_LINUX_DEFAULT=.*$GX_SPIDEV_PARAM" \
        "$(gx_r /etc/default/grub)" 2>/dev/null && printf 'spidev\tgrub-default\n'
    grep -qs "^options.*$GX_SPIDEV_PARAM" "$(gx_r /boot/loader/entries)"/*.conf &&
      printf 'spidev\tsdboot\n'
  fi
  gx_pam_has_line && printf 'pam_sudo\n'
  d=$(gx_r /var/lib/fprint)
  for u in $(gx_rsh find "$d" -mindepth 2 -maxdepth 2 -name goodixtls -printf '%h\n' 2>/dev/null); do
    printf 'enrolled\t%s\n' "${u##*/}"
  done
  return 0
}
