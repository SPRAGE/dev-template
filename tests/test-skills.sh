#!/usr/bin/env bash
# tests/test-skills.sh — validate skill sources and distributable archives
set -euo pipefail

REPO=${1:-$(git rev-parse --show-toplevel)}
REPO=$(cd "$REPO" && pwd)
export PYTHONDONTWRITEBYTECODE=1

echo "=== Skill Test 1: validate source skills ==="
cd "$REPO/template/.claude/skills/skill-creator"
for skill in ../*; do
  [ -d "$skill" ] || continue
  printf '%s: ' "${skill##*/}"
  python -m scripts.quick_validate "$skill"
done

echo ""
echo "=== Skill Test 2: archive freshness ==="
REPO="$REPO" python - <<'PY'
import fnmatch
import os
import sys
import zipfile
from pathlib import Path

root = Path(os.environ["REPO"])
skills_root = root / "template" / ".claude" / "skills"

exclude_dirs = {"__pycache__", "node_modules"}
exclude_globs = {"*.pyc"}
exclude_files = {".DS_Store"}
root_exclude_dirs = {"evals"}


def should_exclude(rel_path: Path) -> bool:
    parts = rel_path.parts
    if any(part in exclude_dirs for part in parts):
        return True
    if len(parts) > 1 and parts[1] in root_exclude_dirs:
        return True
    if rel_path.name in exclude_files:
        return True
    return any(fnmatch.fnmatch(rel_path.name, pat) for pat in exclude_globs)


failures = []
for skill_dir in sorted(p for p in skills_root.iterdir() if p.is_dir()):
    archive = root / f"{skill_dir.name}.skill"
    if not archive.exists():
        failures.append(f"missing archive: {archive.name}")
        continue

    expected = {}
    for path in skill_dir.rglob("*"):
        if not path.is_file():
            continue
        rel = path.relative_to(skill_dir.parent)
        if not should_exclude(rel):
            expected[str(rel)] = path.read_bytes()

    with zipfile.ZipFile(archive) as zf:
        archived_names = {
            info.filename
            for info in zf.infolist()
            if not info.is_dir() and not should_exclude(Path(info.filename))
        }
        expected_names = set(expected)

        missing = sorted(expected_names - archived_names)
        extra = sorted(archived_names - expected_names)
        changed = []
        for name in sorted(expected_names & archived_names):
            if zf.read(name) != expected[name]:
                changed.append(name)

    if missing or extra or changed:
        details = []
        if missing:
            details.append("missing " + ", ".join(missing[:5]))
        if extra:
            details.append("extra " + ", ".join(extra[:5]))
        if changed:
            details.append("changed " + ", ".join(changed[:5]))
        failures.append(f"{archive.name}: {'; '.join(details)}")

if failures:
    for failure in failures:
        print(f"FAIL: {failure}")
    sys.exit(1)

print("All skill archives match source directories.")
PY

echo ""
echo "All skill tests passed."
