# SPDX-License-Identifier: LGPL-2.1-or-later
# Undoing what the state file records. Each change is shown and confirmed
# like during the installation; only our own part of a shared file is removed.

gx_undo_lock() {
  case $1 in
    apt-pin)
      gx_run_root undo_lock -- rm -f "$(gx_r /etc/apt/preferences.d/99-libfprint-goodixtls.pref)" ;;
    versionlock)
      gx_run_root undo_lock -- dnf versionlock delete libfprint ;;
    ignorepkg)
      gx_run_root undo_lock -- sed -i -E \
        -e '/^[[:space:]]*IgnorePkg[[:space:]]*=/{s/[[:space:]]libfprint([[:space:]]|$)/\1/;s/=libfprint([[:space:]]|$)/=\1/}' \
        -e 's/^[[:space:]]*IgnorePkg[[:space:]]*=[[:space:]]*$/#IgnorePkg   =/' \
        "$(gx_r /etc/pacman.conf)" ;;
    *) return 1 ;;
  esac
}

gx_undo_spidev() {
  case $1 in
    modprobe)
      gx_run_root undo_spidev -- rm -f "$(gx_r /etc/modprobe.d/gxfp5197-spidev.conf)" ;;
    grub-dropin)
      gx_run_root undo_spidev -- rm -f "$(gx_r /etc/default/grub.d/gxfp5197-spidev.cfg)" &&
        gx_run_root bootcfg -- update-grub ;;
    grubby)
      gx_run_root undo_spidev -- grubby --update-kernel=ALL --remove-args="$GX_SPIDEV_PARAM" ;;
    grub-default)
      gx_run_root undo_spidev -- sed -i -E \
        -e '/^GRUB_CMDLINE_LINUX_DEFAULT=/{s/ ?spidev\.bufsiz=65536//;s/="[[:space:]]+/="/}' \
        "$(gx_r /etc/default/grub)" &&
        gx_run_root bootcfg -- grub-mkconfig -o /boot/grub/grub.cfg ;;
    sdboot)
      gx_run_root undo_spidev -- sh -c \
        "sed -i 's/ spidev\\.bufsiz=65536//' $(gx_r /boot/loader/entries)/*.conf" ;;
    *) return 1 ;;
  esac
}

gx_undo_pam_sudo() {
  gx_run_root undo_pam -- sed -i "\\|^${GX_PAM_LINE}\$|d" "$(gx_r /etc/pam.d/sudo)"
}

# Declining keeps the prints; that is a choice, not a failure.
gx_undo_enrolled() {
  gx_ask_yn undo_enrolled_q n || return 0
  gx_run_root undo_enrolled -- fprintd-delete "$1"
}

gx_undo_driver() {
  "${1}_restore_stock" "${2:-}" &&
    gx_run_root activate -- systemctl daemon-reload &&
    gx_run_root activate -- systemctl restart fprintd
}

# Undoes every recorded action, newest first. Stops at the first step that
# fails or is declined; what is done is struck from the state file, the rest
# stays for the next run. Packages the script installed come last, after one
# question.
gx_undo_all() {
  local distro line a pkgs=() pkglines=()
  distro=$(gx_state_get distro)
  mapfile -t lines < <(gx_state_actions | tac)
  for line in "${lines[@]}"; do
    IFS=$'\t' read -r -a a <<< "$line"
    if [ "${a[0]}" = pkg_added ]; then
      pkgs+=("${a[1]}")
      pkglines+=("$line")
      continue
    fi
    if ! "gx_undo_${a[0]}" "${a[@]:1}"; then
      gx_msg undo_failed "${a[*]}"
      return 1
    fi
    gx_state_remove "$line"
  done
  if [ ${#pkgs[@]} -gt 0 ]; then
    gx_msg undo_pkgs "${pkgs[*]}"
    if gx_ask_yn undo_pkgs_q n; then
      "${distro}_remove_pkgs" "${pkgs[@]}" || { gx_msg undo_failed "${pkgs[*]}"; return 1; }
    fi
    for line in "${pkglines[@]}"; do gx_state_remove "$line"; done
  fi
  return 0
}
