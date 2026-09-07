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
overlays = {"AI.md", "flake.nix", ".gitignore"}
local_roots = {".ai", ".agents", ".codex", ".claude"}
local_names = {"local", "tmp", "sessions", "logs"}

def is_local(path: Path) -> bool:
    return (
        len(path.parts) > 1 and path.parts[0] in local_roots and path.parts[1] in local_names
    ) or path.as_posix() == ".claude/settings.local.json"

def managed_files(directory: Path) -> set[str]:
    return {
        path.relative_to(directory).as_posix()
        for path in directory.rglob("*")
        if (path.is_file() or path.is_symlink()) and path.relative_to(directory).as_posix() not in overlays
        and not is_local(path.relative_to(directory))
    }

def safe_target(directory: Path, relative: str) -> Path:
    path = directory / relative
    if directory.is_symlink():
        raise SystemExit(f"refusing symlink mirror root: {directory}")
    for parent in path.parents:
        if parent == directory:
            break
        if parent.is_symlink():
            raise SystemExit(f"refusing symlink parent: {parent}")
    return path

base_files = managed_files(base)
for relative in base_files:
    if (base / relative).is_symlink():
        raise SystemExit(f"default templates cannot include symlinks: {relative}")
for language in ("python", "rust"):
    variant = root / "templates" / language
    variant_files = managed_files(variant)
    for relative in base_files | variant_files:
        safe_target(variant, relative)
    for relative in sorted(variant_files - base_files):
        target = variant / relative
        target.unlink()
        # Retiring a managed tree must not leave an empty, invalid catalog.
        parent = target.parent
        while parent != variant:
            try:
                parent.rmdir()
            except OSError:
                break
            parent = parent.parent
    for relative in sorted(base_files):
        source = base / relative
        target = variant / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        if target.is_symlink():
            target.unlink()
        shutil.copy2(source, target)
    for relative in overlays:
        if not (variant / relative).exists():
            raise SystemExit(f"templates/{language} is missing overlay {relative}")
    print(f"generated shared files -> templates/{language}")
PY

echo "Done. Verify with: bash tests/test-template-sync.sh"
