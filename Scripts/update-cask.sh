#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
version="${1:?usage: update-cask.sh VERSION URL SHA256 [OUTPUT]}"
url="${2:?usage: update-cask.sh VERSION URL SHA256 [OUTPUT]}"
sha256="${3:?usage: update-cask.sh VERSION URL SHA256 [OUTPUT]}"
output="${4:-$project_root/Casks/huri.rb}"
template="$project_root/Casks/huri.rb.template"

mkdir -p "$(dirname "$output")"
sed \
  -e "s|@VERSION@|$version|g" \
  -e "s|@URL@|$url|g" \
  -e "s|@SHA256@|$sha256|g" \
  "$template" > "$output"

ruby -c "$output"
echo "Cask updated: $output"
