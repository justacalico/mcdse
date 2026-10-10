#!/usr/bin/env bash
# Package a built Flutter Linux bundle as an RPM for Fedora and friends.
# Installs to /opt/mcdse with a /usr/bin/mcdse symlink, matching the
# layout used by the .deb package built in CI.
#
# Usage: scripts/build-rpm.sh <bundle-dir> <version> <rpm-arch> <output-file> [release]
#   rpm-arch: x86_64 or aarch64
#   release: rpm release number, defaults to 1 (CI passes the build number so
#            nightly rpms stay upgradeable via dnf)
set -euo pipefail

BUNDLE_DIR="${1:?usage: build-rpm.sh <bundle-dir> <version> <rpm-arch> <output-file> [release]}"
VERSION="${2:?usage: build-rpm.sh <bundle-dir> <version> <rpm-arch> <output-file> [release]}"
ARCH="${3:?usage: build-rpm.sh <bundle-dir> <version> <rpm-arch> <output-file> [release]}"
OUT="${4:?usage: build-rpm.sh <bundle-dir> <version> <rpm-arch> <output-file> [release]}"
RELEASE="${5:-1}"

if ! command -v rpmbuild >/dev/null 2>&1; then
  echo "build-rpm: rpmbuild not found (install the rpm/rpm-build package)" >&2
  exit 1
fi
if [ ! -d "$BUNDLE_DIR" ]; then
  echo "build-rpm: bundle dir not found: $BUNDLE_DIR" >&2
  exit 1
fi
if [ "$ARCH" != "x86_64" ] && [ "$ARCH" != "aarch64" ]; then
  echo "build-rpm: unsupported arch: $ARCH" >&2
  exit 1
fi

# rpm forbids '-' in Version; '~' is the rpm convention for prereleases and
# sorts before the final release.
RPM_VERSION="$(printf '%s' "$VERSION" | tr '-' '~')"

TOPDIR="$(mktemp -d)"
trap 'rm -rf "$TOPDIR"' EXIT
mkdir -p "$TOPDIR"/{BUILD,RPMS,SOURCES,SPECS,SRPMS}

# rpmbuild turns every DT_NEEDED of the bundled binaries into a Requires, but
# the plugin and flutter libs we ship are excluded from Provides below. Filter
# out Requires on any soname that exists inside the bundle, otherwise installs
# fail unless some unrelated package happens to provide the same sonames.
BUNDLED_SOS="$(find "$BUNDLE_DIR" -type f -name '*.so*' -printf '%f\n' | sort -u | sed 's/\./[.]/g' | paste -sd'|')"
REQUIRES_EXCLUDE="^(${BUNDLED_SOS})([(].*[)])*$"

cat > "$TOPDIR/SPECS/mcdse.spec" <<'EOF'
Name: mcdse
Version: %{pkg_version}
Release: %{pkg_release}%{?dist}
Summary: Minecraft Dungeons save editor
License: AGPL-3.0-only
URL: https://gitlab.com/HttpAnimations/mcdse

# The bundle is already compiled; skip debug packages and buildroot policy
# scripts (strip, rpath checks) that would mangle or reject the prebuilt libs.
%global debug_package %{nil}
%global __os_install_post %{nil}
# Bundled libs must not leak into the rpm provides namespace.
%global __provides_exclude_from ^/opt/mcdse/.*
%global __requires_exclude %{requires_exclude}

%description
Minecraft Dungeons save file editor for desktop.

%install
mkdir -p %{buildroot}/opt/mcdse %{buildroot}/usr/bin
cp -a %{bundle_dir}/. %{buildroot}/opt/mcdse/
ln -sf /opt/mcdse/mcdse %{buildroot}/usr/bin/mcdse

%files
/opt/mcdse
/usr/bin/mcdse
EOF

rpmbuild -bb \
  --target "$ARCH" \
  --define "_topdir $TOPDIR" \
  --define "pkg_version $RPM_VERSION" \
  --define "pkg_release $RELEASE" \
  --define "bundle_dir $(realpath "$BUNDLE_DIR")" \
  --define "requires_exclude $REQUIRES_EXCLUDE" \
  "$TOPDIR/SPECS/mcdse.spec"

RPM_PATH="$(find "$TOPDIR/RPMS" -name '*.rpm' -print -quit)"
if [ -z "$RPM_PATH" ]; then
  echo "build-rpm: rpmbuild produced no rpm" >&2
  exit 1
fi
cp "$RPM_PATH" "$OUT"
echo "build-rpm: $RPM_PATH -> $OUT"
