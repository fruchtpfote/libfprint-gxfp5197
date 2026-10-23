#!/bin/sh
# SPDX-License-Identifier: LGPL-2.1-or-later
# Builds Fedora's libfprint 1.94.100 with the goodixtls driver, without root.
#     sh packaging/fedora/build-rpm.sh           # result in build/rpm/RPMS/x86_64/
#     sh packaging/fedora/build-rpm.sh --fetch   # only fetch the source RPM, print its path
# Install: sudo dnf install build/rpm/RPMS/x86_64/libfprint-1.94.100-*.gxfp5197.*.rpm
# Lock:    sudo dnf versionlock add libfprint
set -eu
R=$(cd "$(dirname "$0")/../.." && pwd)
W="$R/build/rpm"
mkdir -p "$W/SRPMS"
srpm=$(ls "$W"/SRPMS/libfprint-1.94.100-*.src.rpm 2>/dev/null | head -1 || true)
if [ -z "$srpm" ]; then
  (cd "$W/SRPMS" && dnf -q download --source libfprint >/dev/null)
  srpm=$(ls "$W"/SRPMS/libfprint-*.src.rpm | head -1)
fi
case $srpm in
  */libfprint-1.94.100-*) ;;
  *) echo "unsupported libfprint source: $srpm (patch is for 1.94.100)" >&2; exit 1 ;;
esac
[ "${1:-}" = --fetch ] && { echo "$srpm"; exit 0; }

rm -rf "$W/SPECS" "$W/SOURCES" "$W/BUILD" "$W/BUILDROOT" "$W/RPMS"
rpm -i --define "_topdir $W" "$srpm"
cp "$R/packaging/patches/1.94.100/0100-goodixtls-gxfp5197.patch" \
   "$R/packaging/fprintd-goodixtls.conf" "$W/SOURCES/"
S="$W/SPECS/libfprint.spec"
sed -i -E 's/^Release:.*/Release:        1%{?dist}.gxfp5197.1/' "$S"
sed -i '/^Source0:/a Patch100:       0100-goodixtls-gxfp5197.patch\nSource100:      fprintd-goodixtls.conf' "$S"
sed -i '/^%meson_install/a install -Dm644 %{SOURCE100} %{buildroot}%{_prefix}/lib/systemd/system/fprintd.service.d/goodixtls.conf' "$S"
sed -i '\|^%{_udevrulesdir}/70-libfprint-2.rules|a %{_prefix}/lib/systemd/system/fprintd.service.d/goodixtls.conf' "$S"
for want in Patch100 SOURCE100 'fprintd.service.d/goodixtls.conf$' 'gxfp5197.1'; do
  grep -q "$want" "$S" || { echo "spec edit failed: $want" >&2; exit 1; }
done
rpmbuild -bb --define "_topdir $W" "$S"
ls "$W"/RPMS/x86_64/libfprint-1.94.100-*.rpm
