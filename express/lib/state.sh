# SPDX-License-Identifier: LGPL-2.1-or-later
# The state file: what this script changed, so that uninstalling undoes
# exactly that and nothing else.
#
# One tab-separated line per entry, appended. Keys (lang, distro, phase,
# boot_id) may repeat, the last one wins; every other line is an action, in
# the order it was done.

GX_STATE_KEYS=" lang distro phase boot_id "

gx_state_dir()  { gx_r /var/lib/gxfp5197-express; }
gx_state_file() { printf '%s/state' "$(gx_state_dir)"; }

gx_state_exists() { [ -s "$(gx_state_file)" ]; }

gx__state_append() {
  gx_rsh mkdir -p "$(gx_state_dir)"
  local IFS=$'\t'
  printf '%s\n' "$*" | gx_rsh tee -a "$(gx_state_file)" >/dev/null
}

gx_state_add() { gx__state_append "$@"; gx_log "state: $*"; }

# Adds the action unless exactly this line is already recorded (repair runs).
gx_state_add_once() {
  local IFS=$'\t'
  gx_state_actions | grep -Fxq -- "$*" || gx_state_add "$@"
}
gx_state_set() { gx__state_append "$1" "$2"; }

gx_state_get() {
  [ -r "$(gx_state_file)" ] || return 0
  awk -F'\t' -v k="$1" '$1 == k {v = $2} END {if (v != "") print v}' "$(gx_state_file)"
}

gx_state_actions() {
  [ -r "$(gx_state_file)" ] || return 0
  awk -F'\t' -v keys="$GX_STATE_KEYS" 'index(keys, " " $1 " ") == 0' "$(gx_state_file)"
}

# Drops the last occurrence of exactly this action line.
gx_state_remove() {
  local f tmp
  f=$(gx_state_file)
  tmp=$(mktemp)
  awk -v line="$1" '{a[NR] = $0} $0 == line {last = NR}
                    END {for (i = 1; i <= NR; i++) if (i != last) print a[i]}' "$f" > "$tmp"
  gx_rsh cp "$tmp" "$f"
  rm -f "$tmp"
}

gx_state_clear() { gx_rsh rm -rf "$(gx_state_dir)"; }

# Copies FILE (a system path) into the backup directory, prints the copy's path.
gx_backup() {
  local src b
  src=$(gx_r "$1")
  b="$(gx_state_dir)/backup/$(printf '%s' "$1" | tr / _).$(date +%Y%m%d%H%M%S)"
  gx_rsh mkdir -p "$(gx_state_dir)/backup"
  gx_rsh cp -a "$src" "$b"
  echo "$b"
}
