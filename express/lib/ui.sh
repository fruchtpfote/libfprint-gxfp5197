# SPDX-License-Identifier: LGPL-2.1-or-later
# Dialogue, language, terminal input and the log.
#
# Answers are read from the terminal only (GXE_TTY in tests), never from
# stdin: no terminal or end of input means abort, never "assume yes".

GX_LANG=${GX_LANG:-en}
GX_LOG=${XDG_STATE_HOME:-$HOME/.local/state}/gxfp5197-express/express.log

# Prints "de" or "en". LC_ALL overrides everything, then LC_MESSAGES, then LANG.
gx_lang_default() {
  local v=${LC_ALL:-${LC_MESSAGES:-${LANG:-}}}
  case $v in de*) echo de ;; *) echo en ;; esac
}

gx_log() {
  mkdir -p "${GX_LOG%/*}"
  printf '%s %s\n' "$(date '+%F %T')" "$*" >> "$GX_LOG"
}

# gx_msg KEY [ARGS...]: the message in the current language, printf-style.
gx_msg() {
  local -n _tab="GX_MSG_${GX_LANG}"
  if [ -z "${_tab[$1]+x}" ]; then
    echo "internal error: message '$1' missing" >&2
    exit 70
  fi
  local fmt=${_tab[$1]}
  shift
  # shellcheck disable=SC2059
  printf -- "$fmt\n" "$@"
}

gx_die() {
  gx_log "abort: $1"
  echo
  gx_msg "$@" >&2
  gx_msg log_at "$GX_LOG" >&2
  exit 1
}

# Opens the terminal once, so consecutive reads consume consecutive answers.
gx_ui_init() {
  # The braces keep the 2>/dev/null to this one exec; on exec itself it would
  # silence the script's stderr for good.
  if ! { exec {GX_TTY_FD}<"${GXE_TTY:-/dev/tty}"; } 2>/dev/null; then
    gx_die no_tty
  fi
  gx_log "start lang=$GX_LANG"
}

gx_read() {
  local -n _out=$1
  if ! IFS= read -r -u "$GX_TTY_FD" _out; then
    gx_die abort
  fi
}

# gx_ask_yn KEY [y|n]: 0 for yes, 1 for no.
gx_ask_yn() {
  local def=${2:-y} hint ans
  if [ "$def" = y ]; then hint=$(gx_msg yn_hint_y); else hint=$(gx_msg yn_hint_n); fi
  while :; do
    printf '%s %s ' "$(gx_msg "$1")" "$hint"
    gx_read ans
    ans=${ans,,}
    [ -n "$ans" ] || ans=$def
    case $ans in
      y|yes|j|ja) gx_log "ask $1: yes"; return 0 ;;
      n|no|nein)  gx_log "ask $1: no"; return 1 ;;
    esac
  done
}

# gx_choose KEY OPT...: numbered menu of message keys, prints the chosen key.
gx_choose() {
  local q=$1 i ans
  shift
  gx_msg "$q" >&2
  for i in $(seq 1 $#); do
    printf '  %d) %s\n' "$i" "$(gx_msg "${!i}")" >&2
  done
  while :; do
    printf '%s ' "$(gx_msg choose_prompt)" >&2
    gx_read ans
    if [[ $ans =~ ^[0-9]+$ ]] && [ "$ans" -ge 1 ] && [ "$ans" -le $# ]; then
      gx_log "choose $q: ${!ans}"
      echo "${!ans}"
      return 0
    fi
  done
}

# Shows a step, its exact command, asks, runs it. Returns the command's status,
# or 1 without running it when the user declines.
gx__run() {
  local pre=$1 desc=$2
  shift 3                       # pre, desc, --
  echo
  gx_msg "$desc"
  printf '    $ %s\n' "$(printf '%q ' ${pre:+$pre} "$@")"
  if ! gx_ask_yn confirm_run y; then
    gx_log "skipped: $*"
    return 1
  fi
  local rc flags=$-
  set +e
  if [ -n "$pre" ]; then "$pre" "$@"; else "$@"; fi 2>&1 | tee -a "$GX_LOG"
  rc=${PIPESTATUS[0]}
  [[ $flags == *e* ]] && set -e
  gx_log "ran: $* rc=$rc"
  return "$rc"
}

gx_run_root() { gx__run "${GXE_SUDO-sudo}" "$@"; }
gx_run_user() { gx__run "" "$@"; }
