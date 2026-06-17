#!/usr/bin/env bash
# tests/test-template-sync.sh — enforce that template/ is the single source of truth for
# shared (provider/runtime) files. templates/python and templates/rust are mirrors: only
# genuinely per-language overlays may differ. Everything else must be byte-identical, so a
# fix made once in template/ cannot silently drift across the language variants.
#
# .ai/skills/ parity is enforced separately in tests/test-skills.sh (Test 2).
set -euo pipefail

REPO=${1:-$(git rev-parse --show-toplevel)}
REPO=$(cd "$REPO" && pwd)

echo "=== Template sync: shared files must match template/ ==="
REPO="$REPO" python - <<'PY'
import os, sys
from pathlib import Path

root = Path(os.environ["REPO"])
base = root / "template"

# Per-language overlays (allowed to differ between template/ and templates/<lang>/).
overlays = {"AI.md", ".ai/instructions.md", "flake.nix", ".gitignore"}

def shared_files(d: Path):
    for p in d.rglob("*"):
        if not p.is_file():            # skips dirs and symlinks (provider skill links)
            continue
        rel = p.relative_to(d).as_posix()
        if rel.startswith(".ai/skills/") or rel in overlays:
            continue
        yield rel

failures = []
for lang in ("python", "rust"):
    variant = root / "templates" / lang
    base_set = set(shared_files(base))
    var_set = set(shared_files(variant))
    for rel in sorted(base_set - var_set):
        failures.append(f"{lang}: missing shared file {rel}")
    for rel in sorted(var_set - base_set):
        failures.append(f"{lang}: unexpected extra file {rel}")
    for rel in sorted(base_set & var_set):
        if (base / rel).read_bytes() != (variant / rel).read_bytes():
            failures.append(f"{lang}: drifted from template/: {rel}")
    for o in overlays:
        if not (variant / o).exists():
            failures.append(f"{lang}: missing overlay {o}")

if failures:
    for f in failures:
        print("FAIL:", f)
    print("\nFix: edit template/, then run tests/sync-template-shared.sh (rebuild skill archives if skills changed).")
    sys.exit(1)

print("PASS: shared files identical across template/, templates/python, templates/rust")
print("      per-language overlays:", ", ".join(sorted(overlays)))
PY

echo ""
echo "Template-sync checks passed."
