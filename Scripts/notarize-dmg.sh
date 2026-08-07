#!/usr/bin/env bash
set -euo pipefail

dmg_path="${1:-dist/Huri.dmg}"
submission_json="$(mktemp)"
notary_log="$(mktemp)"

cleanup() {
  rm -f "$submission_json" "$notary_log"
}
trap cleanup EXIT

[[ -f "$dmg_path" ]] || {
  echo "Missing DMG: $dmg_path" >&2
  exit 1
}

if [[ -n "${NOTARY_KEYCHAIN_PROFILE:-}" ]]; then
  credential_args=(--keychain-profile "$NOTARY_KEYCHAIN_PROFILE")
else
  : "${ASC_KEY_PATH:?ASC_KEY_PATH is required without NOTARY_KEYCHAIN_PROFILE}"
  : "${ASC_KEY_ID:?ASC_KEY_ID is required without NOTARY_KEYCHAIN_PROFILE}"
  : "${ASC_ISSUER_ID:?ASC_ISSUER_ID is required without NOTARY_KEYCHAIN_PROFILE}"
  credential_args=(
    --key "$ASC_KEY_PATH"
    --key-id "$ASC_KEY_ID"
    --issuer "$ASC_ISSUER_ID"
  )
fi

xcrun notarytool submit "$dmg_path" \
  "${credential_args[@]}" \
  --wait \
  --output-format json > "$submission_json"

submission_id="$(plutil -extract id raw -o - "$submission_json")"
status="$(plutil -extract status raw -o - "$submission_json")"
xcrun notarytool log "$submission_id" "${credential_args[@]}" > "$notary_log"

if [[ "$status" != "Accepted" ]]; then
  echo "Apple notarization failed with status: $status" >&2
  cat "$notary_log" >&2
  exit 1
fi

echo "Apple notarization accepted (submission $submission_id)."

xcrun stapler staple "$dmg_path"
xcrun stapler validate "$dmg_path"
spctl --assess --type open --context context:primary-signature --verbose=2 "$dmg_path"
echo "Notarized and stapled: $dmg_path"
