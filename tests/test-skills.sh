#!/usr/bin/env bash
set -euo pipefail

REPO=${1:-$(git rev-parse --show-toplevel)}
REPO=$(cd "$REPO" && pwd)
export PYTHONDONTWRITEBYTECODE=1
AUTHORING_ROOT="$REPO/tools/skills"

echo "=== Skill Test 1: default templates contain no discovered procedures ==="
for tree in template templates/python templates/rust; do
  for retired in .ai/skills .ai/catalog .ai/generators .ai/agents .ai/capabilities .ai/evals .ai/project.yaml .ai/policy.yaml .ai/instructions.md .ai/methodology.md .codex/agents .claude/agents .agents; do
    [ ! -e "$REPO/$tree/$retired" ] || { echo "FAIL: $tree still ships $retired"; exit 1; }
  done
done

echo ""
echo "=== Skill Test 2: optional sources validate and package deterministically ==="
for skill in "$REPO/optional/skills"/*; do
  [ -d "$skill" ] || continue
  python "$AUTHORING_ROOT/quick_validate.py" "$skill"
done

REPO="$REPO" PYTHONPATH="$AUTHORING_ROOT" python - <<'PY2'
import fnmatch
import os
import subprocess
import sys
import tempfile
import zipfile
from pathlib import Path

import yaml

root = Path(os.environ["REPO"])
source_root = root / "optional/skills"
skills = {path.name: path for path in source_root.iterdir() if path.is_dir() and (path / "SKILL.md").is_file()}
expected_archives = {f"{name}.skill" for name in skills}
actual_archives = {path.name for path in (root / "skills").glob("*.skill")}
failures = []
for name in sorted(actual_archives - expected_archives):
    failures.append(f"stale archive: {name}")
for name in sorted(expected_archives - actual_archives):
    failures.append(f"missing archive: {name}")

with tempfile.TemporaryDirectory() as temporary:
    output = Path(temporary)
    for name, skill_dir in sorted(skills.items()):
        archive = root / "skills" / f"{name}.skill"
        manifest = yaml.safe_load((skill_dir / "manifest.yaml").read_text())
        selected = {
            path.relative_to(skill_dir)
            for path in skill_dir.rglob("*") if path.is_file()
            and any(fnmatch.fnmatch(path.relative_to(skill_dir).as_posix(), pattern) for pattern in manifest["package"])
        }
        expected = {f"{name}/{path.as_posix()}": (skill_dir / path).read_bytes() for path in selected}
        with zipfile.ZipFile(archive) as handle:
            infos = [info for info in handle.infolist() if not info.is_dir()]
            actual = {info.filename: handle.read(info.filename) for info in infos}
            if actual != expected:
                failures.append(f"{archive.name}: content differs from package allowlist")
            if any(info.date_time != (1980, 1, 1, 0, 0, 0) for info in infos):
                failures.append(f"{archive.name}: non-deterministic timestamp")
        subprocess.run([sys.executable, str(root / "tools/skills/package_skill.py"), str(skill_dir), str(output)], check=True)
        if (output / archive.name).read_bytes() != archive.read_bytes():
            failures.append(f"{archive.name}: deterministic rebuild differs")

if failures:
    print("\n".join(f"FAIL: {failure}" for failure in failures))
    sys.exit(1)
print("Optional sources, allowlisted archives, and deterministic rebuilds match.")
PY2

echo ""
echo "=== Skill Test 3: distributable optional procedures stay provider neutral ==="
REPO="$REPO" python - <<'PY2'
import os
import re
import sys
from pathlib import Path

import yaml

root = Path(os.environ["REPO"])
terms = re.compile(r"\b(?:Anthropic|Claude|Codex|OpenAI|Qdrant|Ollama|dataserver|rag-kb)\b", re.I)
failures = []
for skill in (root / "optional/skills").iterdir():
    if not skill.is_dir():
        continue
    manifest = yaml.safe_load((skill / "manifest.yaml").read_text())
    if manifest["audience"] == "maintainer":
        continue
    for path in (skill / "SKILL.md", *(skill / "references").glob("*.md")):
        match = terms.search(path.read_text())
        if match:
            failures.append(f"{path.relative_to(root)}: provider/infrastructure term {match.group(0)!r}")
if failures:
    print("\n".join(f"FAIL: {failure}" for failure in failures))
    sys.exit(1)
print("Distributable optional procedures are provider and infrastructure neutral.")
PY2

echo ""
echo "=== Skill Test 4: optional discovery is profile-controlled ==="
ACTIVE_PROJECT=$(mktemp -d)
trap 'rm -rf "$ACTIVE_PROJECT"' EXIT
mkdir "$ACTIVE_PROJECT/.git"
python "$REPO/tools/template.py" --repo "$REPO" onboard --root "$ACTIVE_PROJECT"
[ ! -e "$ACTIVE_PROJECT/.ai/skills" ] || { echo "FAIL: onboard enabled a skill by default"; exit 1; }
python "$REPO/tools/template.py" --repo "$REPO" profile --root "$ACTIVE_PROJECT" list | grep -qx 'skill:frontend-design'
python "$REPO/tools/template.py" --repo "$REPO" profile --root "$ACTIVE_PROJECT" enable skill:frontend-design
[ -f "$ACTIVE_PROJECT/.ai/skills/frontend-design/SKILL.md" ] || { echo "FAIL: profile did not install the optional source"; exit 1; }
[ -L "$ACTIVE_PROJECT/.agents/skills/frontend-design" ] || { echo "FAIL: profile did not create the native Codex discovery link"; exit 1; }
[ -L "$ACTIVE_PROJECT/.claude/skills/frontend-design" ] || { echo "FAIL: profile did not create the native Claude discovery link"; exit 1; }
python "$REPO/tools/template.py" --repo "$REPO" doctor --root "$ACTIVE_PROJECT"

echo ""
echo "All skill tests passed."
