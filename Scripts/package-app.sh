#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
app_dir="$project_root/dist/Huri.app"
dsym_path="$project_root/dist/Huri.dSYM"
contents_dir="$app_dir/Contents"
iconset_dir="$project_root/.build/Huri.iconset"
version="${VERSION:-$(tr -d '[:space:]' < "$project_root/VERSION")}"
build_number="${BUILD_NUMBER:-$(git -C "$project_root" rev-list --count HEAD)}"
bundle_identifier="${BUNDLE_IDENTIFIER:-dev.pacificknowledge.huri}"
signing_identity="${SIGNING_IDENTITY:--}"
distribution="${DISTRIBUTION:-local}"
build_archs="${BUILD_ARCHS:-}"

cd "$project_root"
binary_sources=()
resource_bundle=""
if [[ -n "$build_archs" ]]; then
  for architecture in $build_archs; do
    scratch_path="$project_root/.build/distribution-$architecture"
    build_arguments=(
      -c release
      --arch "$architecture"
      --scratch-path "$scratch_path"
    )
    swift build "${build_arguments[@]}" --product HuriApp
    architecture_build_dir="$(swift build "${build_arguments[@]}" --show-bin-path)"
    binary_sources+=("$architecture_build_dir/HuriApp")
    if [[ -z "$resource_bundle" ]]; then
      resource_bundle="$architecture_build_dir/Huri_HuriCore.bundle"
    fi
  done
else
  swift build -c release --product HuriApp
  build_dir="$(swift build -c release --show-bin-path)"
  binary_sources+=("$build_dir/HuriApp")
  resource_bundle="$build_dir/Huri_HuriCore.bundle"
fi

rm -rf "$app_dir"
mkdir -p "$contents_dir/MacOS" "$contents_dir/Resources"
if [[ "${#binary_sources[@]}" -eq 1 ]]; then
  cp "${binary_sources[0]}" "$contents_dir/MacOS/Huri"
else
  lipo -create "${binary_sources[@]}" -output "$contents_dir/MacOS/Huri"
fi

if [[ ! -d "$resource_bundle" ]]; then
  echo "Missing localized resource bundle: $resource_bundle" >&2
  exit 1
fi
cp -R "$resource_bundle" "$contents_dir/Resources/Huri_HuriCore.bundle"
cp "$project_root/LICENSE" "$contents_dir/Resources/LICENSE.txt"
cp "$project_root/THIRD_PARTY_NOTICES.md" "$contents_dir/Resources/THIRD_PARTY_NOTICES.md"

if [[ "$distribution" == "appstore" ]]; then
  provisioning_profile="${PROVISIONING_PROFILE_PATH:-}"
  [[ -f "$provisioning_profile" ]] || {
    echo "PROVISIONING_PROFILE_PATH is required for App Store distribution." >&2
    exit 1
  }
  cp "$provisioning_profile" "$contents_dir/embedded.provisionprofile"
fi

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
  -e "s/@VERSION@/$version/g" \
  -e "s/@BUILD_NUMBER@/$build_number/g" \
  -e "s/@BUNDLE_IDENTIFIER@/$bundle_identifier/g" \
  "$project_root/Scripts/Info.plist.template" \
  > "$contents_dir/Info.plist"

chmod +x "$contents_dir/MacOS/Huri"

rm -rf "$dsym_path"
dsymutil "$contents_dir/MacOS/Huri" -o "$dsym_path"

if [[ "$signing_identity" == "-" ]]; then
  codesign --force --sign - "$app_dir"
else
  entitlements="${ENTITLEMENTS:-$project_root/Config/Huri.Homebrew.entitlements}"
  codesign_args=(
    --force
    --sign "$signing_identity"
    --entitlements "$entitlements"
    --timestamp
  )
  if [[ "$distribution" == "homebrew" ]]; then
    codesign_args+=(--options runtime)
  fi
  codesign "${codesign_args[@]}" "$app_dir"
fi

codesign --verify --deep --strict --verbose=2 "$app_dir"
echo "Application created: $app_dir ($version build $build_number, $distribution)"
echo "Debug symbols created: $dsym_path"
