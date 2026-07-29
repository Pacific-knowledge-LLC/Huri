#!/usr/bin/env bash
set -euo pipefail

dmg_path="${1:-dist/Huri.dmg}"

[[ -f "$dmg_path" ]] || {
  echo "Missing DMG: $dmg_path" >&2
  exit 1
}

if [[ -n "${NOTARY_KEYCHAIN_PROFILE:-}" ]]; then
  xcrun notarytool submit "$dmg_path" \
    --keychain-profile "$NOTARY_KEYCHAIN_PROFILE" \
    --wait
else
  : "${ASC_KEY_PATH:?ASC_KEY_PATH is required without NOTARY_KEYCHAIN_PROFILE}"
  : "${ASC_KEY_ID:?ASC_KEY_ID is required without NOTARY_KEYCHAIN_PROFILE}"
  : "${ASC_ISSUER_ID:?ASC_ISSUER_ID is required without NOTARY_KEYCHAIN_PROFILE}"
  xcrun notarytool submit "$dmg_path" \
    --key "$ASC_KEY_PATH" \
    --key-id "$ASC_KEY_ID" \
    --issuer "$ASC_ISSUER_ID" \
    --wait
fi

xcrun stapler staple "$dmg_path"
xcrun stapler validate "$dmg_path"
spctl --assess --type open --context context:primary-signature --verbose=2 "$dmg_path"
echo "Notarized and stapled: $dmg_path"
