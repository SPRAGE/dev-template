#!/usr/bin/env bash
set -euo pipefail

REPO=${1:-$(git rev-parse --show-toplevel)}
REPO=$(cd "$REPO" && pwd)
export PYTHONDONTWRITEBYTECODE=1

AUTHORING_ROOT="$REPO/skill-catalog/skill-authoring"

echo "=== Skill Test 1: validate default and optional sources ==="
cd "$AUTHORING_ROOT"
for source_root in "$REPO/template/.ai/skills" "$REPO/skill-catalog"; do
  for skill in "$source_root"/*; do
    [ -d "$skill" ] || continue
    [ -f "$skill/SKILL.md" ] || continue
    python -m scripts.quick_validate "$skill"
  done
done

default_skills=$(find "$REPO/template/.ai/skills" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort)
[ "$default_skills" = "agent-context" ] || {
  echo "FAIL: default discovery catalog must contain only agent-context; got: $default_skills"
  exit 1
}

echo ""
echo "=== Skill Test 2: conditional activation is safe and compiler-valid ==="
ACTIVE_PROJECT=$(mktemp -d)
trap 'rm -rf "$ACTIVE_PROJECT"' EXIT
cp -a "$REPO/template/." "$ACTIVE_PROJECT/"

python "$ACTIVE_PROJECT/.ai/tools/skillctl.py" --root "$ACTIVE_PROJECT" activate performance-engineering
[ -L "$ACTIVE_PROJECT/.ai/skills/performance-engineering" ] || {
  echo "FAIL: activation did not create a skill link"
  exit 1
}
[ "$(readlink "$ACTIVE_PROJECT/.ai/skills/performance-engineering")" = "../catalog/performance-engineering" ] || {
  echo "FAIL: activation link is not project-relative"
  exit 1
}
python "$ACTIVE_PROJECT/.ai/tools/skillctl.py" --root "$ACTIVE_PROJECT" activate performance-engineering
python "$ACTIVE_PROJECT/.ai/tools/skillctl.py" --root "$ACTIVE_PROJECT" active | grep -q '^performance-engineering[[:space:]]'
python "$ACTIVE_PROJECT/.ai/generators/compile.py" --root "$ACTIVE_PROJECT" --check
python "$ACTIVE_PROJECT/.ai/tools/skillctl.py" --root "$ACTIVE_PROJECT" deactivate performance-engineering
[ ! -e "$ACTIVE_PROJECT/.ai/skills/performance-engineering" ] || {
  echo "FAIL: deactivation left a catalog link"
  exit 1
}

mkdir "$ACTIVE_PROJECT/.ai/skills/performance-engineering"
printf 'keep\n' > "$ACTIVE_PROJECT/.ai/skills/performance-engineering/local.txt"
if python "$ACTIVE_PROJECT/.ai/tools/skillctl.py" --root "$ACTIVE_PROJECT" activate performance-engineering 2>/dev/null; then
  echo "FAIL: activation replaced a custom collision"
  exit 1
fi
[ "$(cat "$ACTIVE_PROJECT/.ai/skills/performance-engineering/local.txt")" = "keep" ] || {
  echo "FAIL: custom collision was modified"
  exit 1
}

echo ""
echo "=== Skill Test 3: provider discovery links ==="
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
  [ "$target" = "../.ai/skills" ] || { echo "FAIL: $link points to $target"; exit 1; }
  [ -d "$REPO/$link" ] || { echo "FAIL: $link is broken"; exit 1; }
done

for copy in templates/python/.ai/skills templates/rust/.ai/skills; do
  diff -rq "$REPO/template/.ai/skills" "$REPO/$copy"
done

echo ""
echo "=== Skill Test 4: deterministic archive contents ==="
REPO="$REPO" PYTHONPATH="$AUTHORING_ROOT" python - <<'PY'
import fnmatch
import os
import sys
import zipfile
from pathlib import Path

import yaml

root = Path(os.environ["REPO"])
source_roots = [root / "template/.ai/skills", root / "skill-catalog"]
skills = {
    path.name: path
    for source_root in source_roots
    for path in source_root.iterdir()
    if path.is_dir() and (path / "SKILL.md").is_file()
}
expected_archives = {f"{name}.skill" for name in skills}
actual_archives = {path.name for path in (root / "skills").glob("*.skill")}
failures = []

for name in sorted(actual_archives - expected_archives):
    failures.append(f"stale archive: {name}")
for name in sorted(expected_archives - actual_archives):
    failures.append(f"missing archive: {name}")

for name, skill_dir in sorted(skills.items()):
    archive = root / "skills" / f"{name}.skill"
    if not archive.is_file():
        continue
    manifest = yaml.safe_load((skill_dir / "manifest.yaml").read_text())
    files = [path for path in skill_dir.rglob("*") if path.is_file()]
    selected = {
        path.relative_to(skill_dir)
        for path in files
        if any(fnmatch.fnmatch(path.relative_to(skill_dir).as_posix(), pattern) for pattern in manifest["package"])
    }
    expected = {f"{name}/{path.as_posix()}": (skill_dir / path).read_bytes() for path in selected}
    with zipfile.ZipFile(archive) as handle:
        infos = [info for info in handle.infolist() if not info.is_dir()]
        actual = {info.filename: handle.read(info.filename) for info in infos}
        if actual != expected:
            failures.append(f"{archive.name}: content differs from package allowlist")
        if any(info.date_time != (1980, 1, 1, 0, 0, 0) for info in infos):
            failures.append(f"{archive.name}: non-deterministic timestamp")

if failures:
    for failure in failures:
        print("FAIL:", failure)
    sys.exit(1)
print("All archives match explicit source allowlists.")
PY

echo ""
echo "=== Skill Test 5: shared procedures are provider and infrastructure neutral ==="
REPO="$REPO" python - <<'PY'
import os
import re
import sys
from pathlib import Path

root = Path(os.environ["REPO"])
source_roots = [root / "template/.ai/skills", root / "skill-catalog"]
terms = re.compile(r"\b(?:Anthropic|Claude|Codex|OpenAI|Qdrant|Ollama|dataserver|rag-kb)\b", re.I)
failures = []
for source_root in source_roots:
    for skill in source_root.iterdir():
        if not skill.is_dir() or not (skill / "SKILL.md").is_file():
            continue
        paths = [skill / "SKILL.md", *skill.glob("references/*.md")]
        for path in paths:
            match = terms.search(path.read_text())
            if match:
                failures.append(f"{path.relative_to(root)}: provider/infrastructure term {match.group(0)!r}")
if failures:
    print("\n".join(f"FAIL: {failure}" for failure in failures))
    sys.exit(1)
print("All skill entry points and references are provider and infrastructure neutral.")
PY

echo ""
echo "All skill tests passed."
