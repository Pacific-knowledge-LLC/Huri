#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
version="$(tr -d '[:space:]' < "$project_root/VERSION")"
download_dir="$project_root/downloads"

mkdir -p "$download_dir"

for architecture in arm64 x86_64; do
  BUILD_ARCHS="$architecture" bash "$project_root/Scripts/package-app.sh"
  REQUIRED_ARCHS="$architecture" bash "$project_root/Scripts/verify-app.sh"
  bash "$project_root/Scripts/create-dmg.sh"

  output="$download_dir/Huri-$version-macos-$architecture.dmg"
  cp "$project_root/dist/Huri.dmg" "$output"
  hdiutil verify "$output" >/dev/null
  shasum -a 256 "$output"
done

echo "Téléchargements web créés dans $download_dir"
