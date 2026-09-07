#!/usr/bin/env bash
# Build each Nix wrapper once, then exercise real CLI lifecycle behavior in fixtures.
set -euo pipefail
export PYTHONDONTWRITEBYTECODE=1
REPO=${1:-$(git rev-parse --show-toplevel)}
REPO=$(cd "$REPO" && pwd)
TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT
# NIX_TEST_OFFLINE=1 uses only the existing lock/store for local verification.
nix_flags=()
if [ "${NIX_TEST_OFFLINE:-0}" = 1 ]; then nix_flags+=(--offline); fi
app_names=(onboard sync-skills fresh-start ai-doctor migrate-v2 migrate agent-profile agent-restore)
refs=()
for app in "${app_names[@]}"; do refs+=("path:$REPO#$app"); done
nix build "${nix_flags[@]}" --no-link "${refs[@]}"
for app in "${app_names[@]}"; do
  out=$(nix eval "${nix_flags[@]}" --raw "path:$REPO#packages.$(nix eval --impure --raw --expr builtins.currentSystem).$app.outPath")
  ln -s "$out/bin/$app" "$TEST_DIR/$app"
  "$TEST_DIR/$app" --help >/dev/null
done
bash "$REPO/tests/test-onboard.sh" "$TEST_DIR/onboard"

project="$TEST_DIR/project"
mkdir -p "$project/.git"
"$TEST_DIR/onboard" --root "$project"
"$TEST_DIR/agent-profile" --root "$project" list
"$TEST_DIR/agent-profile" --root "$project" enable roles
"$TEST_DIR/agent-profile" --root "$project" enable skill:frontend-design
"$TEST_DIR/sync-skills" --root "$project"
"$TEST_DIR/ai-doctor" --root "$project"
test -f "$project/.agents/skills/frontend-design/SKILL.md"
test -f "$project/.codex/agents/reviewer.toml"
"$TEST_DIR/agent-profile" --root "$project" disable roles
"$TEST_DIR/agent-profile" --root "$project" disable skill:frontend-design
test ! -e "$project/.codex/agents"
test ! -e "$project/.ai/skills"

# Reset chooses the application language, preserves local state, and restores exactly.
printf '%s\n' '[project]' > "$project/pyproject.toml"
printf '%s\n' 'old flake' > "$project/flake.nix"
printf '%s\n' 'old lock' > "$project/flake.lock"
mkdir -p "$project/.codex/local" "$project/.ai/local"
printf '%s\n' 'keep runtime' > "$project/.codex/local/state"
"$TEST_DIR/fresh-start" --root "$project" --yes
rg -q 'pkgs.uv' "$project/flake.nix"
test ! -e "$project/flake.lock"
test "$(cat "$project/.codex/local/state")" = 'keep runtime'
backup=$(python - "$project" <<'PY'
import sys
from pathlib import Path
print(sorted((Path(sys.argv[1])/'.ai/local/dev-template/backups').glob('*/backup.json'))[-1])
PY
)
"$TEST_DIR/agent-restore" --root "$project" "$backup"
test "$(cat "$project/flake.nix")" = 'old flake'
test "$(cat "$project/flake.lock")" = 'old lock'

# Exercise the new migration wrapper from a real, compiled v2 fixture.
legacy="$TEST_DIR/legacy"
mkdir -p "$legacy/.git"
cp -R "$REPO/compat/v2/." "$legacy/"
chmod -R u+w "$legacy"
python "$legacy/.ai/generators/compile.py" --root "$legacy" >/dev/null
if "$TEST_DIR/sync-skills" --root "$legacy"; then
  echo 'FAIL: sync upgraded a legacy schema' >&2
  exit 1
fi
"$TEST_DIR/migrate" --root "$legacy" >/dev/null
test -f "$legacy/.ai/project.yaml"
"$TEST_DIR/migrate" --root "$legacy" --apply
"$TEST_DIR/ai-doctor" --root "$legacy"
test ! -e "$legacy/.ai/project.yaml"
test -f "$legacy/.ai/context/legacy-project.yaml"
printf '%s\n' 'PASS: all eight Nix apps and v3 lifecycle contracts'
