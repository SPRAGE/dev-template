#!/usr/bin/env bash
# tests/test-template-sync.sh — enforce that template/ is the single source of truth for
# shared (provider/runtime) files. templates/python and templates/rust are mirrors: only
# genuinely per-language overlays may differ. Everything else must be byte-identical, so a
# fix made once in template/ cannot silently drift across the language variants.
#
# Generated copies are committed because Nix templates are static paths. This test makes
# template/ the only authored source for all non-overlay files.
set -euo pipefail
export PYTHONDONTWRITEBYTECODE=1

REPO=${1:-$(git rev-parse --show-toplevel)}
REPO=$(cd "$REPO" && pwd)

echo "=== Template sync: shared files must match template/ ==="
REPO="$REPO" python - <<'PY'
import os, sys
from pathlib import Path

root = Path(os.environ["REPO"])
base = root / "template"

# Per-language overlays (allowed to differ between template/ and templates/<lang>/).
overlays = {"AI.md", "flake.nix", ".gitignore"}
local_roots = {".ai", ".agents", ".codex", ".claude"}
local_names = {"local", "tmp", "sessions", "logs"}

def is_local(path: Path) -> bool:
    return (
        len(path.parts) > 1 and path.parts[0] in local_roots and path.parts[1] in local_names
    ) or path.as_posix() == ".claude/settings.local.json"

def shared_files(d: Path):
    for p in d.rglob("*"):
        if not (p.is_file() or p.is_symlink()):
            continue
        rel = p.relative_to(d).as_posix()
        if rel in overlays or is_local(p.relative_to(d)):
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
        if (base / rel).is_symlink() or (variant / rel).is_symlink():
            failures.append(f"{lang}: unexpected shared symlink {rel}")
            continue
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

# Used by the preservation fixture below to run the same parity check without recursion.
[ "${2:-}" != "--parity-only" ] || exit 0

echo "=== Regeneration preserves local state and removes empty retired trees ==="
REPO="$REPO" python - <<'PY'
import os
import shutil
import subprocess
import tempfile
from pathlib import Path

repo = Path(os.environ["REPO"])
with tempfile.TemporaryDirectory() as temporary:
    root = Path(temporary)
    for relative in ("template", "templates/python", "templates/rust"):
        shutil.copytree(repo / relative, root / relative, symlinks=True)
    variant = root / "templates/python"
    preserved = (
        ".codex/local/state", ".codex/tmp/state", ".agents/local/state",
        ".ai/local/state", ".claude/settings.local.json",
    )
    for relative in preserved:
        path = variant / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text("keep local state\n")
    retired = variant / ".ai/catalog/retired/SKILL.md"
    retired.parent.mkdir(parents=True)
    retired.write_text("retired managed fixture\n")
    subprocess.run(["bash", str(repo / "tests/sync-template-shared.sh"), str(root)], check=True, stdout=subprocess.DEVNULL)
    assert not (variant / ".ai/catalog").exists(), "empty retired catalog survived regeneration"
    for relative in preserved:
        assert (variant / relative).read_text() == "keep local state\n", relative
    subprocess.run(["bash", str(repo / "tests/test-template-sync.sh"), str(root), "--parity-only"], check=True, stdout=subprocess.DEVNULL)
    outside = root / "outside"
    outside.mkdir()
    (outside / "settings.json").write_text("outside data")
    shutil.rmtree(variant / ".claude")
    (variant / ".claude").symlink_to(outside)
    result = subprocess.run(["bash", str(repo / "tests/sync-template-shared.sh"), str(root)], capture_output=True, text=True)
    assert result.returncode != 0 and "symlink parent" in result.stderr + result.stdout
    assert (outside / "settings.json").read_text() == "outside data"
print("PASS: regeneration preserves local state, retires empty trees, and refuses external symlink parents")
PY

echo "=== Flake runtime source and supported-system contract ==="
REPO="$REPO" python - <<'PY'
import os
import re
from pathlib import Path

root = Path(os.environ["REPO"])
flakes = [root / "flake.nix", root / "template/flake.nix", root / "templates/python/flake.nix", root / "templates/rust/flake.nix"]
required_systems = {'"x86_64-linux"', '"aarch64-linux"', '"aarch64-darwin"'}
forbidden_values = ('custom-codex-release', 'codex-redesign', 'eachDefaultSystem')
for path in flakes:
    text = path.read_text()
    assert 'github:NixOS/nixpkgs/nixpkgs-unstable' in text, path
    assert 'git+ssh://pai@192.168.0.7/srv/git/codex-release.git?ref=latest' in text, path
    assert 'codex-release.packages.${system}.default' in text, path
    assert 'pkgs.codex' in text, path
    assert 'codexPackage' in text, path
    assert 'flake-utils.lib.eachSystem' in text, path
    assert all(system in text for system in required_systems), path
    for forbidden in forbidden_values:
        assert forbidden not in text, f"{path}: stale {forbidden}"
    print("PASS:", path.relative_to(root))
lock = (root / "flake.lock").read_text()
assert 'ssh://pai@192.168.0.7/srv/git/codex-release.git' in lock
assert '"codex-release"' in lock
for forbidden in forbidden_values:
    assert forbidden not in lock, f"flake.lock: stale {forbidden}"
print("PASS: flake.lock pins the dataserver Codex release")

workflow = (root / ".github/workflows/ci.yml").read_text()
uses = re.findall(r"^\s*- uses: ([^\s#]+)", workflow, re.MULTILINE)
assert uses and all(re.fullmatch(r"[^@]+@[0-9a-f]{40}", value) for value in uses), "CI actions must use full commit SHAs"
print("PASS: CI actions use immutable revisions")

for template_root in (root / "template", root / "templates/python", root / "templates/rust"):
    envrc = (template_root / ".envrc").read_text()
    assert "dotenv" not in envrc, f"{template_root}: .envrc must not auto-load secrets"
print("PASS: generated shells do not auto-load secret files")
PY

python "$REPO/tools/template.py" --repo "$REPO" check

echo ""
echo "Template-sync checks passed."
