#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
app_path="${1:-$project_root/dist/Huri.app}"
executable="$app_path/Contents/MacOS/Huri"
isolated_root="$(mktemp -d)"
isolated_app="$isolated_root/Huri.app"
build_dir="$project_root/.build"
held_build_dir="$project_root/.build.packaged-smoke.$$"
build_was_moved=0

cleanup() {
  if [[ "$build_was_moved" == "1" && -d "$held_build_dir" && ! -e "$build_dir" ]]; then
    mv "$held_build_dir" "$build_dir"
  fi
  rm -rf "$isolated_root"
}
trap cleanup EXIT INT TERM

[[ -x "$executable" ]] || {
  echo "Packaged smoke test failed: missing executable at $executable" >&2
  exit 1
}

ditto "$app_path" "$isolated_app"

# SwiftPM generates an absolute development fallback for Bundle.module. Hide
# the build directory so this test behaves like a different user's Mac.
if [[ -d "$build_dir" ]]; then
  mv "$build_dir" "$held_build_dir"
  build_was_moved=1
fi

set +e
output="$("$isolated_app/Contents/MacOS/Huri" --verify-packaged-resources 2>&1)"
status=$?
set -e

if [[ "$status" -ne 0 ]]; then
  echo "Packaged smoke test failed with exit code $status:" >&2
  echo "$output" >&2
  exit "$status"
fi

grep -Fxq 'fr=Vos fichiers, transformés.' <<< "$output" \
  || { echo "Packaged smoke test failed: French resources were not loaded." >&2; exit 1; }
grep -Fxq 'en=Your files, transformed.' <<< "$output" \
  || { echo "Packaged smoke test failed: English resources were not loaded." >&2; exit 1; }

echo "Packaged app smoke test passed outside the repository build context."
