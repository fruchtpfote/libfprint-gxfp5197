#!/bin/sh
# SPDX-License-Identifier: LGPL-2.1-or-later
# Builds libfprint 1:1.94.9-1 with the goodixtls driver as Debian packages,
# without root: the source comes through a private apt configuration (the
# host's deb-src entries may be disabled), the driver as a quilt patch.
# Result: build/deb/*.deb
set -eu
R=$(cd "$(dirname "$0")/.." && pwd)
VER=1.94.9
DEBVER=1:1.94.9-1
OURVER=1:1.94.9-1+gxfp5197.4
W="$R/build/deb"
A="$R/build/apt"

mkdir -p "$A/lists/partial" "$A/cache/archives/partial" "$A/parts"
cat > "$A/parts/src.sources" <<SRC
Types: deb-src
URIs: http://deb.debian.org/debian/
Suites: trixie
Components: main
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg
SRC
O="-o Dir::State::Lists=$A/lists -o Dir::Cache=$A/cache \
   -o Dir::Etc::SourceList=/dev/null -o Dir::Etc::SourceParts=$A/parts \
   -o Debug::NoLocking=1"
apt-get $O -qq update

rm -rf "$W" && mkdir -p "$W" && cd "$W"
apt-get $O -qq source "libfprint=$DEBVER"
cd "libfprint-$VER"

mkdir -p debian/patches debian/goodixtls
cp "$R/packaging/patches/0100-goodixtls-gxfp5197.patch" debian/patches/
echo 0100-goodixtls-gxfp5197.patch >> debian/patches/series
cp "$R/packaging/fprintd-goodixtls.conf" debian/goodixtls/goodixtls.conf
echo "debian/goodixtls/goodixtls.conf usr/lib/systemd/system/fprintd.service.d/" \
  >> debian/libfprint-2-2.install

# Debian's postinst only re-triggers USB ids; bind an already present SPI
# sensor to spidev too, so no reboot is needed.
for f in debian/libfprint-2-2.postinst debian/libfprint-2-2.postinst.in; do
  perl -0pi -e 's/\nfi\n\nexit 0/\n\tfor id in GXFP5187 GXFP5197; do\n\t\tudevadm trigger --action=add --subsystem-match=spi --property-match="MODALIAS=acpi:\$id:*" || true\n\tdone\nfi\n\nexit 0/' "$f"
  grep -q GXFP5197 "$f"
done

DEBFULLNAME=${DEBFULLNAME:-$(git -C "$R" config user.name || echo "local build")} \
DEBEMAIL=${DEBEMAIL:-$(git -C "$R" config user.email || echo "$USER@localhost")} \
  dch -v "$OURVER" -D trixie --force-distribution \
  "Goodix GXFP5187/GXFP5197 SPI (TLS-PSK) driver goodixtls (local build)."

dpkg-buildpackage -us -uc -b
cd "$W"
ls -1 *.deb
