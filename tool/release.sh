#!/usr/bin/env bash
# Build the release APKs and file them under releases/<version>/, so an old
# build can always be reinstalled and nothing ships from a stale build/ dir.
#
#     tool/release.sh
#
# Bump `version:` in pubspec.yaml first — the archive is named after it, and
# Android refuses to install a build whose versionCode has not moved.
set -euo pipefail
cd "$(dirname "$0")/.."

version=$(grep '^version:' pubspec.yaml | awk '{print $2}')
out="releases/$version"

if [ -d "$out" ]; then
  echo "releases/$version already exists — bump version: in pubspec.yaml." >&2
  exit 1
fi

flutter build apk --split-per-abi --release

mkdir -p "$out"
for abi in arm64-v8a armeabi-v7a x86_64; do
  cp "build/app/outputs/flutter-apk/app-$abi-release.apk" \
     "$out/wick-$version-$abi.apk"
done

echo
echo "Wrote:"
ls -lh "$out"
echo
echo "Hand out $out/wick-$version-arm64-v8a.apk — every phone since ~2015."
