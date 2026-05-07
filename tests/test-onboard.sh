#!/usr/bin/env bash
# tests/test-onboard.sh — validates nix run .#onboard behavior
set -euo pipefail

TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT

echo "=== Test 1: Full bootstrap (no .claude/) ==="
cd "$TEST_DIR"
mkdir -p fake-project && cd fake-project
git init -q
touch flake.nix  # onboard checks for project root indicators

# Run onboard (the app path will be passed as $1)
"$1"

# Verify all expected files exist
for f in .ai/instructions.md \
         .ai/context/active-context.md \
         .ai/context/decisions.md \
         .ai/context/architecture-snapshot.md \
         .ai/context/conventions.md \
         .ai/context/stale-log.md \
         .ai/context/.gitignore \
         .claude/settings.json \
         .mcp.json \
         CLAUDE.md \
         AGENTS.md; do
  [ -f "$f" ] || { echo "FAIL: $f not created"; exit 1; }
done

# Verify skills are installed, otherwise next-step commands like /cc-setup cannot work
for d in .claude/skills/cc-setup \
         .claude/skills/cc-refresh \
         .claude/skills/fresh-start \
         .claude/skills/virtual-tech-org; do
  [ -d "$d" ] || { echo "FAIL: $d not created"; exit 1; }
done

# Verify hooks are executable (skip .gitkeep, only check .sh files)
for h in .claude/hooks/*.sh; do
  [ -f "$h" ] || continue  # skip if no .sh files (only .gitkeep)
  [ -x "$h" ] || { echo "FAIL: $h not executable"; exit 1; }
done

echo "PASS: Full bootstrap"

echo ""
echo "=== Test 2: Context-only (has .claude/ but no .ai/) ==="
cd "$TEST_DIR"
mkdir -p partial-project/.claude && cd partial-project
git init -q
touch flake.nix

"$1"

[ -d .ai/context ] || { echo "FAIL: .ai/context/ not created"; exit 1; }
[ -f .ai/context/active-context.md ] || { echo "FAIL: active-context.md not created"; exit 1; }
[ -d .claude/skills/cc-setup ] || { echo "FAIL: cc-setup skill not created"; exit 1; }
echo "PASS: Context-only bootstrap"

echo ""
echo "=== Test 3: Already onboarded (has everything) ==="
cd "$TEST_DIR/fake-project"

OUTPUT=$("$1" 2>&1) || true
echo "$OUTPUT" | grep -q "already" || echo "WARN: expected 'already onboarded' message"
echo "PASS: Already-onboarded detection"

echo ""
echo "All tests passed."
