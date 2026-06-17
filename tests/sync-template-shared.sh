#!/usr/bin/env bash
# tests/sync-template-shared.sh — mirror shared files from the canonical template/ into
# templates/python and templates/rust. template/ is the single source of truth; the language
# variants are mirrors plus a few per-language overlays.
#
# Left untouched:
#   - per-language overlays: AI.md, .ai/instructions.md, flake.nix, .gitignore
#   - .ai/skills/ (kept in sync by the skill tooling; archives rebuilt separately)
#
# Run after editing any shared file in template/, then verify with tests/test-template-sync.sh.
set -euo pipefail

REPO=${1:-$(git rev-parse --show-toplevel)}
REPO=$(cd "$REPO" && pwd)

overlays=(AI.md .ai/instructions.md flake.nix .gitignore)
is_overlay() { local r="$1"; for o in "${overlays[@]}"; do [ "$r" = "$o" ] && return 0; done; return 1; }

for lang in python rust; do
  variant="$REPO/templates/$lang"
  while IFS= read -r rel; do
    case "$rel" in .ai/skills/*) continue ;; esac
    is_overlay "$rel" && continue
    mkdir -p "$variant/$(dirname "$rel")"
    command cp -f "$REPO/template/$rel" "$variant/$rel"
  done < <(cd "$REPO/template" && find . -type f -not -path './.ai/skills/*' | sed 's#^\./##')
  echo "synced shared files -> templates/$lang"
done

echo "Done. Verify with: bash tests/test-template-sync.sh"
