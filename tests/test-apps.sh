#!/usr/bin/env bash
# tests/test-apps.sh — smoke tests for nix app behavior
set -euo pipefail

REPO=${1:-$(git rev-parse --show-toplevel)}
REPO=$(cd "$REPO" && pwd)
TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT

run_app() {
  local app=$1
  shift || true
  nix run "path:$REPO#$app" -- "$@"
}

echo "=== App Test 1: onboard ==="
ONBOARD_WRAPPER="$TEST_DIR/onboard"
cat > "$ONBOARD_WRAPPER" <<EOF
#!/usr/bin/env bash
exec nix run "path:$REPO#onboard" -- "\$@"
EOF
chmod +x "$ONBOARD_WRAPPER"
bash "$REPO/tests/test-onboard.sh" "$ONBOARD_WRAPPER"

echo ""
echo "=== App Test 2: sync-skills ==="
mkdir -p "$TEST_DIR/sync-project"
cd "$TEST_DIR/sync-project"
git init -q
mkdir -p .claude
run_app sync-skills

for d in .claude/skills/cc-setup \
         .claude/skills/fresh-start \
         .claude/skills/skill-creator; do
  [ -d "$d" ] || { echo "FAIL: $d not synced"; exit 1; }
done

for f in .ai/instructions.md \
         .ai/context/active-context.md \
         .ai/context/architecture-snapshot.md \
         .ai/context/conventions.md \
         .ai/context/decisions.md \
         .ai/context/stale-log.md \
         .ai/context/.gitignore \
         AGENTS.md; do
  [ -f "$f" ] || { echo "FAIL: $f not synced"; exit 1; }
done
echo "PASS: sync-skills"

echo ""
echo "=== App Test 3: fresh-start ==="
mkdir -p "$TEST_DIR/fresh-project"
cd "$TEST_DIR/fresh-project"
git init -q
touch flake.nix
mkdir -p .claude/skills/old-skill .claude/knowledge
echo old > .claude/skills/old-skill/SKILL.md
echo old > .claude/knowledge/decisions.md
mkdir -p .ai/context
echo old > .ai/context/active-context.md
echo old > CLAUDE.md
echo old > AGENTS.md
echo '{}' > .mcp.json
echo local > .claude.local.md

TEST_HOME="$TEST_DIR/home"
mkdir -p "$TEST_HOME"
sanitized_cwd=$(echo "$PWD" | sed 's|/|-|g')
memory_dir="$TEST_HOME/.claude/projects/$sanitized_cwd"
mkdir -p "$memory_dir"
echo keep > "$memory_dir/memory.md"

printf 'y\n' | HOME="$TEST_HOME" nix run "path:$REPO#fresh-start" --

[ -f "$memory_dir/memory.md" ] || { echo "FAIL: auto-memory was deleted"; exit 1; }
[ ! -d .claude/skills/old-skill ] || { echo "FAIL: old skill survived fresh-start"; exit 1; }
[ ! -f .claude/knowledge/decisions.md ] || { echo "FAIL: legacy .claude/knowledge survived fresh-start"; exit 1; }
[ ! -f .claude.local.md ] || { echo "FAIL: .claude.local.md survived fresh-start"; exit 1; }

for d in .claude/skills/cc-setup \
         .claude/skills/fresh-start \
         .claude/skills/virtual-tech-org; do
  [ -d "$d" ] || { echo "FAIL: $d not restored"; exit 1; }
done

for f in .ai/instructions.md \
         .ai/context/active-context.md \
         .ai/context/architecture-snapshot.md \
         .ai/context/conventions.md \
         .ai/context/decisions.md \
         .ai/context/stale-log.md \
         .ai/context/.gitignore \
         .claude/settings.json \
         .mcp.json \
         CLAUDE.md \
         AGENTS.md; do
  [ -f "$f" ] || { echo "FAIL: $f not restored"; exit 1; }
done
echo "PASS: fresh-start"

echo ""
echo "=== App Test 4: ai-doctor ==="
nix run "path:$REPO#ai-doctor" --
echo "PASS: ai-doctor"

echo ""
echo "All app tests passed."
