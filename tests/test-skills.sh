#!/usr/bin/env bash
# tests/test-skills.sh — validate skill sources and distributable archives
set -euo pipefail

REPO=${1:-$(git rev-parse --show-toplevel)}
REPO=$(cd "$REPO" && pwd)
export PYTHONDONTWRITEBYTECODE=1

echo "=== Skill Test 1: validate source skills ==="
cd "$REPO/template/.ai/skills/skill-creator"
for skill in ../*; do
  [ -d "$skill" ] || continue
  printf '%s: ' "${skill##*/}"
  python -m scripts.quick_validate "$skill"
done

echo ""
echo "=== Skill Test 2: template skill links ==="
for link in template/.agents/skills \
            template/.claude/skills \
            template/.codex/skills \
            templates/python/.agents/skills \
            templates/python/.claude/skills \
            templates/python/.codex/skills \
            templates/rust/.agents/skills \
            templates/rust/.claude/skills \
            templates/rust/.codex/skills; do
  [ -L "$REPO/$link" ] || { echo "FAIL: $link should be a symlink to .ai/skills"; exit 1; }
  target=$(readlink "$REPO/$link")
  [ "$target" = "../.ai/skills" ] || { echo "FAIL: $link should point to ../.ai/skills, got $target"; exit 1; }
  [ -d "$REPO/$link" ] || { echo "FAIL: $link should resolve to a directory"; exit 1; }
  echo "PASS: $link links to shared skills"
done

for copy in templates/python/.ai/skills \
            templates/rust/.ai/skills; do
  if diff -rq "$REPO/template/.ai/skills" "$REPO/$copy" >/dev/null 2>&1; then
    echo "PASS: $copy matches template/.ai/skills"
  else
    echo "FAIL: $copy differs from template/.ai/skills"
    diff -rq "$REPO/template/.ai/skills" "$REPO/$copy" || true
    exit 1
  fi
done

echo ""
echo "=== Skill Test 3: archive freshness ==="
REPO="$REPO" python - <<'PY'
import fnmatch
import os
import sys
import zipfile
from pathlib import Path

root = Path(os.environ["REPO"])
skills_root = root / "template" / ".ai" / "skills"

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
expected_archives = {f"{path.name}.skill" for path in skills_root.iterdir() if path.is_dir()}
actual_archives = {path.name for path in (root / "skills").glob("*.skill")}
for archive_name in sorted(actual_archives - expected_archives):
    failures.append(f"stale extra archive: {archive_name}")
for skill_dir in sorted(p for p in skills_root.iterdir() if p.is_dir()):
    archive = root / "skills" / f"{skill_dir.name}.skill"
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
        infos = [info for info in zf.infolist() if not info.is_dir() and not should_exclude(Path(info.filename))]
        archived_names = {
            info.filename
            for info in infos
        }
        expected_names = set(expected)

        missing = sorted(expected_names - archived_names)
        extra = sorted(archived_names - expected_names)
        changed = []
        metadata = []
        for name in sorted(expected_names & archived_names):
            if zf.read(name) != expected[name]:
                changed.append(name)
        for info in infos:
            if info.date_time != (1980, 1, 1, 0, 0, 0):
                metadata.append(info.filename)

    if missing or extra or changed or metadata:
        details = []
        if missing:
            details.append("missing " + ", ".join(missing[:5]))
        if extra:
            details.append("extra " + ", ".join(extra[:5]))
        if changed:
            details.append("changed " + ", ".join(changed[:5]))
        if metadata:
            details.append("non-deterministic metadata " + ", ".join(metadata[:5]))
        failures.append(f"{archive.name}: {'; '.join(details)}")

if failures:
    for failure in failures:
        print(f"FAIL: {failure}")
    sys.exit(1)

print("All skill archives match source directories.")
PY

echo ""
echo "=== Skill Test 4: provider neutrality ==="
REPO="$REPO" python - <<'PY'
import os, re, sys
from pathlib import Path

root = Path(os.environ["REPO"])
skills_root = root / "template" / ".ai" / "skills"

# A shared skill must not frame itself around one provider. If its description or H1 title
# names exactly one provider (Claude Code / Codex), that is a neutrality leak — name both
# (balanced) or neither (neutral). Provider-specific guidance belongs in clearly marked
# sections, tables, columns, or runtime notes inside the body, not in the framing.
def skewed(text: str) -> bool:
    has_claude = re.search(r"Claude Code|\bClaude\b", text) is not None
    has_codex = re.search(r"\bCodex\b", text) is not None
    return has_claude != has_codex

failures = []
for skill_dir in sorted(p for p in skills_root.iterdir() if p.is_dir()):
    md = (skill_dir / "SKILL.md").read_text()
    fm = re.match(r"^---\n(.*?)\n---\n(.*)$", md, re.DOTALL)
    front = fm.group(1) if fm else ""
    body = fm.group(2) if fm else md
    dm = re.search(r"description:\s*>?-?\s*\n?(.*?)(?:\n[A-Za-z_-]+:\s|\Z)", front, re.DOTALL)
    description = dm.group(1) if dm else front
    if skewed(description):
        failures.append(f"{skill_dir.name}: description names one provider but not the other")
    h1 = re.search(r"(?m)^#\s+(.+)$", body)
    if h1 and skewed(h1.group(1)):
        failures.append(f"{skill_dir.name}: title '{h1.group(1).strip()}' is provider-skewed")

if failures:
    for f in failures:
        print("FAIL:", f)
    sys.exit(1)

print("All shared skill descriptions/titles are provider-neutral (balanced or neutral).")
PY

echo ""
echo "All skill tests passed."
