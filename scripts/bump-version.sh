#!/usr/bin/env bash
set -euo pipefail

VERSION="${1:?usage: bump-version.sh <version>}"

build=1
if grep -q '^version: .*+' pubspec.yaml; then
  build=$(grep '^version: ' pubspec.yaml | sed 's/.*+//')
  build=$((build + 1))
fi
sed -i "s/^version: .*/version: ${VERSION}+${build}/" pubspec.yaml

grep -q "^version: ${VERSION}+" pubspec.yaml
