#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tag="${1:-${GITHUB_REF_NAME:-}}"
version="$(tr -d '[:space:]' < "$project_root/VERSION")"

[[ "$tag" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] || {
  echo "Release tag must follow vMAJOR.MINOR.PATCH (received: ${tag:-empty})." >&2
  exit 1
}
[[ "$tag" == "v$version" ]] || {
  echo "Tag $tag does not match VERSION ($version)." >&2
  exit 1
}

swift package --package-path "$project_root" dump-package >/dev/null
bash "$project_root/Scripts/check-secrets.sh"
echo "Release preflight passed for Huri $version."
