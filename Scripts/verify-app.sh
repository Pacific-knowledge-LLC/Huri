#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
app_path="${1:-$project_root/dist/Huri.app}"
plist="$app_path/Contents/Info.plist"
executable="$app_path/Contents/MacOS/Huri"
resources="$app_path/Contents/Resources/Huri_HuriCore.bundle"
expected_version="$(tr -d '[:space:]' < "$project_root/VERSION")"

fail() {
  echo "Verification failed: $*" >&2
  exit 1
}

[[ -d "$app_path" ]] || fail "missing app at $app_path"
[[ -x "$executable" ]] || fail "missing executable"
[[ -f "$plist" ]] || fail "missing Info.plist"
[[ -f "$resources/fr.lproj/Localizable.strings" ]] || fail "missing French localization"
[[ -f "$resources/en.lproj/Localizable.strings" ]] || fail "missing English localization"
[[ -f "$app_path/Contents/Resources/AppIcon.icns" ]] || fail "missing application icon"
[[ -f "$app_path/Contents/Resources/LICENSE.txt" ]] || fail "missing open-source license"
[[ -f "$app_path/Contents/Resources/THIRD_PARTY_NOTICES.md" ]] \
  || fail "missing third-party notices"

bundle_id="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$plist")"
version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$plist")"
minimum_system="$(/usr/libexec/PlistBuddy -c 'Print :LSMinimumSystemVersion' "$plist")"

[[ "$bundle_id" == "dev.pacificknowledge.huri" ]] || fail "unexpected bundle identifier: $bundle_id"
[[ "$version" == "$expected_version" ]] || fail "version $version does not match VERSION $expected_version"
[[ "$minimum_system" == "14.0" ]] || fail "unexpected minimum macOS version: $minimum_system"

plutil -lint "$plist" >/dev/null
codesign --verify --deep --strict --verbose=2 "$app_path"

if [[ -n "${REQUIRED_ARCHS:-}" ]]; then
  actual_archs="$(lipo -archs "$executable")"
  for required_arch in $REQUIRED_ARCHS; do
    grep -qw "$required_arch" <<< "$actual_archs" \
      || fail "missing architecture $required_arch (found: $actual_archs)"
  done
fi

signature_details="$(codesign -dv "$app_path" 2>&1)"
if grep -q 'Signature=adhoc' <<< "$signature_details"; then
  echo "Gatekeeper assessment skipped for the local ad-hoc build."
else
  spctl --assess --type execute --verbose=2 "$app_path"
fi

echo "Verified Huri $version ($bundle_id): executable, icon, FR/EN resources and signature are valid."
