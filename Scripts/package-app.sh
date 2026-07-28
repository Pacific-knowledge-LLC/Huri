#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
app_dir="$project_root/dist/Huri.app"
contents_dir="$app_dir/Contents"
iconset_dir="$project_root/.build/Huri.iconset"

cd "$project_root"
swift build -c release --product HuriApp
build_dir="$(swift build -c release --show-bin-path)"

rm -rf "$app_dir"
mkdir -p "$contents_dir/MacOS" "$contents_dir/Resources"
cp "$build_dir/HuriApp" "$contents_dir/MacOS/Huri"

rm -rf "$iconset_dir"
mkdir -p "$iconset_dir"
sips -s format png -z 16 16 "$project_root/Assets/AppIcon.png" --out "$iconset_dir/icon_16x16.png" >/dev/null
sips -s format png -z 32 32 "$project_root/Assets/AppIcon.png" --out "$iconset_dir/icon_16x16@2x.png" >/dev/null
sips -s format png -z 32 32 "$project_root/Assets/AppIcon.png" --out "$iconset_dir/icon_32x32.png" >/dev/null
sips -s format png -z 64 64 "$project_root/Assets/AppIcon.png" --out "$iconset_dir/icon_32x32@2x.png" >/dev/null
sips -s format png -z 128 128 "$project_root/Assets/AppIcon.png" --out "$iconset_dir/icon_128x128.png" >/dev/null
sips -s format png -z 256 256 "$project_root/Assets/AppIcon.png" --out "$iconset_dir/icon_128x128@2x.png" >/dev/null
sips -s format png -z 256 256 "$project_root/Assets/AppIcon.png" --out "$iconset_dir/icon_256x256.png" >/dev/null
sips -s format png -z 512 512 "$project_root/Assets/AppIcon.png" --out "$iconset_dir/icon_256x256@2x.png" >/dev/null
sips -s format png -z 512 512 "$project_root/Assets/AppIcon.png" --out "$iconset_dir/icon_512x512.png" >/dev/null
sips -s format png -z 1024 1024 "$project_root/Assets/AppIcon.png" --out "$iconset_dir/icon_512x512@2x.png" >/dev/null
iconutil -c icns "$iconset_dir" -o "$contents_dir/Resources/AppIcon.icns"

sed \
  -e "s/@VERSION@/1.0.0/g" \
  "$project_root/Scripts/Info.plist.template" \
  > "$contents_dir/Info.plist"

chmod +x "$contents_dir/MacOS/Huri"
codesign --force --sign - "$app_dir"
echo "Application créée : $app_dir"
