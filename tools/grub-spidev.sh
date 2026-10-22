#!/bin/sh
# SPDX-License-Identifier: LGPL-2.1-or-later
# Raise spidev's per-transfer buffer to 64 KiB at the next boot: the sensor
# sends its image as one ~22 KB frame, the built-in default is 4096. spidev is
# built into Debian's kernel, so only the kernel command line can change it.
# Undo: sudo rm /etc/default/grub.d/gxfp5197-spidev.cfg && sudo update-grub
set -eu
[ "$(id -u)" -eq 0 ] || { echo "run with sudo" >&2; exit 1; }
CFG=/etc/default/grub.d/gxfp5197-spidev.cfg
printf '%s\n' '# GXFP5197 fingerprint sensor: image frames are ~22 KB' \
    'GRUB_CMDLINE_LINUX="$GRUB_CMDLINE_LINUX spidev.bufsiz=65536"' > "$CFG"
cat "$CFG"
update-grub
grep -c 'spidev.bufsiz=65536' /boot/grub/grub.cfg
