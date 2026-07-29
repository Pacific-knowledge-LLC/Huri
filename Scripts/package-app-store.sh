#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
application_identity="${APP_STORE_APPLICATION_IDENTITY:-}"
installer_identity="${APP_STORE_INSTALLER_IDENTITY:-}"
pkg_path="$project_root/dist/Huri-AppStore.pkg"

[[ -n "$application_identity" ]] || {
  echo "APP_STORE_APPLICATION_IDENTITY is required." >&2
  exit 1
}
[[ -n "$installer_identity" ]] || {
  echo "APP_STORE_INSTALLER_IDENTITY is required." >&2
  exit 1
}

DISTRIBUTION=appstore \
SIGNING_IDENTITY="$application_identity" \
ENTITLEMENTS="$project_root/Config/Huri.AppStore.entitlements" \
  "$project_root/Scripts/package-app.sh"

rm -f "$pkg_path"
productbuild \
  --component "$project_root/dist/Huri.app" /Applications \
  --sign "$installer_identity" \
  "$pkg_path"

pkgutil --check-signature "$pkg_path"
echo "Mac App Store package created: $pkg_path"
