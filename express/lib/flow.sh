# SPDX-License-Identifier: LGPL-2.1-or-later
# The overall flow: checks, what is already there, installation with reboot
# and resume, optional enrolment and sudo, uninstallation.

gx_boot_id() { cat "$(gx_r /proc/sys/kernel/random/boot_id)" 2>/dev/null || true; }

gx_choose_lang() {
  local def ans
  def=$(gx_lang_default)
  if [ "$def" = de ]; then
    printf 'Sprache / Language:  1) Deutsch  2) English  [1] '
  else
    printf 'Sprache / Language:  1) Deutsch  2) English  [2] '
  fi
  gx_read ans
  case $ans in
    1) GX_LANG=de ;;
    2) GX_LANG=en ;;
    *) GX_LANG=$def ;;
  esac
  gx_log "lang=$GX_LANG"
}

# A failed or declined step: say so, offer to undo what was done so far.
gx_fail() {
  echo
  gx_msg step_failed "$GX_LOG"
  gx_state_exists && gx_ask_yn undo_now_q n && gx_undo_all && gx_state_clear
  exit 1
}

gx_pam_sudo_add() {
  local f b
  f=$(gx_r /etc/pam.d/sudo)
  if gx_pam_has_line; then
    gx_msg sudo_already
    return 3
  fi
  b=$(gx_backup /etc/pam.d/sudo)
  gx_log "backup /etc/pam.d/sudo -> $b"
  gx_run_root sudo_add -- sed -i \
    "0,/^[[:space:]]*\\(auth\\|@include[[:space:]]\\+common-auth\\)/s//${GX_PAM_LINE}\\n&/" "$f" ||
    return 1
  gx_state_add_once pam_sudo
}

gx_verify() {
  if fprintd-list "$USER" 2>&1 | grep -q 'found [1-9]'; then
    gx_msg verify_ok
    return 0
  fi
  gx_msg verify_failed
  if [ "$GX_DISTRO" = fedora ] && [ "$(getenforce 2>/dev/null)" = Enforcing ]; then
    gx_msg selinux_hint
  fi
  return 1
}

gx_offer_use() {
  if gx_ask_yn enroll_q y; then
    gx_msg enroll_hint
    if gx_run_user enroll -- fprintd-enroll; then
      gx_state_add_once enrolled "$USER"
    else
      gx_msg enroll_failed
    fi
  fi
  if gx_ask_yn sudo_q y; then
    local rc=0
    gx_pam_sudo_add || rc=$?
    if [ $rc = 0 ]; then
      gx_msg sudo_test_hint
      gx_run_user sudo_test -- sh -c 'sudo -k; sudo true' || gx_msg sudo_test_failed
    elif [ $rc != 3 ]; then
      gx_msg sudo_not_added
    fi
  fi
}

# Everything after the spidev buffer is in place.
gx_install_continue() {
  local d=$GX_DISTRO stock
  stock=$(gx_detect_libfprint_stock "$d")
  gx_patch_for_version "$stock" >/dev/null || gx_die unknown_version "${stock:-?}"
  gx_spidev_bufsiz_ok || { gx_msg spidev_still_small; gx_fail; }
  gx_state_set phase building
  "${d}_builddeps" || gx_fail
  "${d}_build" || gx_fail
  gx_state_set phase installing
  "${d}_install" "$GX_PKG" || gx_fail
  "${d}_lock" || gx_fail
  gx_state_set phase installed
  gx_verify || gx_fail
  gx_offer_use
  gx_state_set phase done
  echo
  gx_msg done
}

gx_install() {
  gx_state_set lang "$GX_LANG"
  gx_state_set distro "$GX_DISTRO"
  gx_state_set phase start
  if gx_spidev_bufsiz_ok; then
    gx_msg spidev_ok
  else
    gx_msg spidev_explain
    if gx_spidev_builtin; then
      "${GX_DISTRO}_spidev_param_set" || gx_fail
    else
      gx_spidev_modprobe_set || gx_fail
    fi
    gx_state_set boot_id "$(gx_boot_id)"
    gx_state_set phase await_reboot
    echo
    gx_msg reboot_now
    exit 0
  fi
  gx_install_continue
}

gx_uninstall() {
  local had_spidev=0
  gx_msg uninstall_list
  gx_state_actions | sed 's/\t/ /g; s/^/    /'
  gx_state_actions | grep -q '^spidev' && had_spidev=1
  gx_ask_yn uninstall_q y || exit 0
  gx_undo_all || exit 1
  gx_state_clear
  echo
  gx_msg uninstalled
  [ $had_spidev = 0 ] || gx_msg reboot_recommended
}

# Turns the traces of a manual installation into state entries.
gx_adopt() {
  local traces=$1 stock kind arg
  gx_msg traces_found
  printf '%s\n' "$traces" | sed 's/\t/ /g; s/^/    /'
  gx_ask_yn adopt_q y || exit 0
  stock=$(gx_detect_libfprint_stock "$GX_DISTRO")
  gx_state_set lang "$GX_LANG"
  gx_state_set distro "$GX_DISTRO"
  # Recorded in installation order, so the undo runs the right way round.
  while IFS=$'\t' read -r kind arg; do
    [ "$kind" = spidev ] && gx_state_add_once spidev "$arg"
  done <<< "$traces"
  while IFS=$'\t' read -r kind arg; do
    case $kind in
      driver)   gx_state_add_once driver "$GX_DISTRO" "$stock" ;;
      lock)     gx_state_add_once lock "$arg" ;;
    esac
  done <<< "$traces"
  while IFS=$'\t' read -r kind arg; do
    case $kind in
      pam_sudo) gx_state_add_once pam_sudo ;;
      enrolled) gx_state_add_once enrolled "$arg" ;;
    esac
  done <<< "$traces"
  gx_state_set phase done
}

gx_menu() {
  local phase choice
  phase=$(gx_state_get phase)
  if [ "$phase" = await_reboot ]; then
    if [ "$(gx_state_get boot_id)" != "$(gx_boot_id)" ]; then
      gx_msg resume_after_reboot
      gx_install_continue
      return
    fi
    gx_msg still_need_reboot
    choice=$(gx_choose menu_q opt_uninstall opt_abort_reboot)
  elif [ "$phase" = done ]; then
    choice=$(gx_choose menu_q opt_uninstall opt_repair opt_abort)
  else
    gx_msg interrupted
    choice=$(gx_choose menu_q opt_continue opt_uninstall opt_abort)
  fi
  case $choice in
    opt_uninstall)            gx_uninstall ;;
    opt_repair|opt_continue)  gx_install_continue ;;
    *)                        exit 0 ;;
  esac
}

gx_main() {
  GX_LANG=$(gx_lang_default)
  gx_ui_init
  gx_choose_lang
  [ "${GXE_UID:-$(id -u)}" != 0 ] || gx_die no_root
  GX_DISTRO=$(gx_detect_distro)
  case $GX_DISTRO in unsupported:*) gx_die unsupported "${GX_DISTRO#unsupported:}" ;; esac
  local sensor stock traces
  sensor=$(gx_detect_sensor)
  [ -n "$sensor" ] || gx_die no_sensor
  echo
  gx_msg intro "$sensor" "$GX_DISTRO"
  if [ -n "${GXE_SUDO-sudo}" ]; then
    gx_msg sudo_needed
    ${GXE_SUDO-sudo} -v || gx_die abort
  fi
  if gx_state_exists; then
    GX_DISTRO=$(gx_state_get distro)
    gx_menu
    return
  fi
  traces=$(gx_detect_traces "$GX_DISTRO")
  if [ -n "$traces" ]; then
    gx_adopt "$traces"
    gx_menu
    return
  fi
  stock=$(gx_detect_libfprint_stock "$GX_DISTRO")
  gx_patch_for_version "$stock" >/dev/null || gx_die unknown_version "${stock:-?}"
  gx_install
}
