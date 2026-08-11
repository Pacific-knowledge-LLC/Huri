#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
version="$(tr -d '[:space:]' < "$project_root/VERSION")"
release_dir="$project_root/dist/releases"
signing_identity="${SIGNING_IDENTITY:-}"

: "${signing_identity:?SIGNING_IDENTITY must be a Developer ID Application identity}"

mkdir -p "$release_dir"

BUILD_ARCHS="arm64 x86_64" \
DISTRIBUTION=homebrew \
SIGNING_IDENTITY="$signing_identity" \
  bash "$project_root/Scripts/package-app.sh"

REQUIRE_DEVELOPER_ID=1 \
REQUIRED_ARCHS="arm64 x86_64" \
  bash "$project_root/Scripts/verify-app.sh"

DMG_SIGNING_IDENTITY="$signing_identity" \
  bash "$project_root/Scripts/create-dmg.sh"

output="$release_dir/Huri-macos-universal.dmg"
cp "$project_root/dist/Huri.dmg" "$output"
bash "$project_root/Scripts/notarize-dmg.sh" "$output"
REQUIRED_ARCHS="arm64 x86_64" bash "$project_root/Scripts/verify-distribution.sh" "$output"

symbols="$release_dir/Huri-$version-macos-universal.dSYM.zip"
ditto -c -k --keepParent "$project_root/dist/Huri.dSYM" "$symbols"

shasum -a 256 "$output" | tee "$output.sha256"
shasum -a 256 "$symbols" | tee "$symbols.sha256"

echo "Signed, notarized universal release created in $release_dir"
