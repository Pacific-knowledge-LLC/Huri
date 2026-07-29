#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$project_root"

patterns='AKIA[0-9A-Z]{16}|ASIA[0-9A-Z]{16}|gh[pousr]_[A-Za-z0-9_]{30,}|-----BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY-----|sk_live_[A-Za-z0-9]{16,}'

if rg --hidden -n -I "$patterns" . \
  --glob '!.git/**' \
  --glob '!.build/**' \
  --glob '!dist/**' \
  --glob '!Scripts/check-secrets.sh' \
  --glob '!docs/RELEASE.md'
then
  echo "Potential secret detected in a tracked file." >&2
  exit 1
fi

echo "No common credential pattern found in workspace files."
