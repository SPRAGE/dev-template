#!/usr/bin/env bash
# Regenerate language templates from template/ plus their explicit overlays.
set -euo pipefail
export PYTHONDONTWRITEBYTECODE=1

REPO=${1:-$(git rev-parse --show-toplevel)}
REPO=$(cd "$REPO" && pwd)

REPO="$REPO" python - <<'PY'
import os
import shutil
from pathlib import Path

root = Path(os.environ["REPO"])
base = root / "template"
overlays = {"AI.md", ".ai/project.yaml", "flake.nix", ".gitignore"}

def managed_files(directory: Path) -> set[str]:
    return {
        path.relative_to(directory).as_posix()
        for path in directory.rglob("*")
        if path.is_file() and path.relative_to(directory).as_posix() not in overlays
    }

base_files = managed_files(base)
for language in ("python", "rust"):
    variant = root / "templates" / language
    variant_files = managed_files(variant)
    for relative in sorted(variant_files - base_files):
        (variant / relative).unlink()
    for relative in sorted(base_files):
        source = base / relative
        target = variant / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, target)
    for relative in overlays:
        if not (variant / relative).exists():
            raise SystemExit(f"templates/{language} is missing overlay {relative}")
    print(f"generated shared files -> templates/{language}")
PY

for language in python rust; do
  python "$REPO/templates/$language/.ai/generators/compile.py" --root "$REPO/templates/$language"
done

echo "Done. Verify with: bash tests/test-template-sync.sh"
