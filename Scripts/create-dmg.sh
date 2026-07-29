#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
app_path="$project_root/dist/Huri.app"
dmg_path="$project_root/dist/Huri.dmg"
staging_dir="$(mktemp -d)"

cleanup() {
  rm -rf "$staging_dir"
}
trap cleanup EXIT

if [[ ! -d "$app_path" ]]; then
  "$project_root/Scripts/package-app.sh"
fi

cp -R "$app_path" "$staging_dir/Huri.app"
ln -s /Applications "$staging_dir/Applications"
rm -f "$dmg_path"
hdiutil create -volname Huri -srcfolder "$staging_dir" -ov -format UDZO "$dmg_path"

if [[ -n "${DMG_SIGNING_IDENTITY:-}" ]]; then
  codesign --force --timestamp --sign "$DMG_SIGNING_IDENTITY" "$dmg_path"
  codesign --verify --verbose=2 "$dmg_path"
fi

echo "Image disque créée : $dmg_path"
