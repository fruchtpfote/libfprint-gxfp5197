#!/bin/bash
# SPDX-License-Identifier: LGPL-2.1-or-later
# Express installation of the goodixtls fingerprint driver (GXFP5197/GXFP5187)
# for Debian 13, Fedora and Arch. Interactive: every change is shown and
# confirmed first. Run it again to repair or to uninstall.
#     ./express-install.sh
set -euo pipefail

GX_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
for _f in msg_de msg_en ui detect state undo backend_common backend_debian backend_fedora \
          backend_arch flow; do
  [ -f "$GX_DIR/express/lib/$_f.sh" ] && source "$GX_DIR/express/lib/$_f.sh"
done
unset _f

if [ "${GXE_SOURCE_ONLY:-}" != 1 ]; then
  gx_main "$@"
fi
