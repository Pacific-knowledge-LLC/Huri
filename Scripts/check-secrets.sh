#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$project_root"

patterns='AKIA[0-9A-Z]{16}|ASIA[0-9A-Z]{16}|gh[pousr]_[A-Za-z0-9_]{30,}|-----BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY-----|sk_live_[A-Za-z0-9]{16,}'

workspace_matches="$(rg --hidden -l -I "$patterns" . \
  --glob '!.git/**' \
  --glob '!.build/**' \
  --glob '!dist/**' \
  --glob '!Scripts/check-secrets.sh' || true)"

if [[ -n "$workspace_matches" ]]; then
  echo "Potential credential pattern detected in workspace files (values redacted):" >&2
  while IFS= read -r matched_file; do
    printf '  - %s\n' "$matched_file" >&2
  done <<< "$workspace_matches"
  exit 1
fi

history_matches="$(git grep -I -l -E "$patterns" $(git rev-list --all) \
  -- . ':(exclude)Scripts/check-secrets.sh' 2>/dev/null || true)"

if [[ -n "$history_matches" ]]; then
  echo "Potential credential pattern detected in Git history (details redacted)." >&2
  exit 1
fi

echo "No common credential pattern found in workspace files."
