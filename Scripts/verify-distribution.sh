#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
dmg_path="${1:-$project_root/dist/Huri.dmg}"
mount_root="$(mktemp -d)"

cleanup() {
  hdiutil detach "$mount_root" >/dev/null 2>&1 || true
  rm -rf "$mount_root"
}
trap cleanup EXIT INT TERM

fail() {
  echo "Distribution verification failed: $*" >&2
  exit 1
}

[[ -f "$dmg_path" ]] || fail "missing DMG at $dmg_path"
hdiutil verify "$dmg_path" >/dev/null
codesign --verify --verbose=2 "$dmg_path"
xcrun stapler validate "$dmg_path"
spctl --assess --type open --context context:primary-signature --verbose=2 "$dmg_path"

hdiutil attach -readonly -nobrowse -mountpoint "$mount_root" "$dmg_path" >/dev/null
app_path="$mount_root/Huri.app"
[[ -d "$app_path" ]] || fail "Huri.app is missing from the DMG"

REQUIRE_DEVELOPER_ID=1 \
REQUIRE_GATEKEEPER=1 \
REQUIRED_ARCHS="${REQUIRED_ARCHS:-arm64 x86_64}" \
  bash "$project_root/Scripts/verify-app.sh" "$app_path"

echo "Distribution verified: Developer ID, Hardened Runtime, notarization, stapling and architectures are valid."
