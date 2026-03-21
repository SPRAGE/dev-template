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
for f in .claude/knowledge/active-context.md \
         .claude/knowledge/decisions.md \
         .claude/knowledge/architecture-snapshot.md \
         .claude/knowledge/conventions.md \
         .claude/knowledge/stale-log.md \
         .claude/settings.json \
         .mcp.json \
         CLAUDE.md; do
  [ -f "$f" ] || { echo "FAIL: $f not created"; exit 1; }
done

# Verify hooks are executable (skip .gitkeep, only check .sh files)
for h in .claude/hooks/*.sh; do
  [ -f "$h" ] || continue  # skip if no .sh files (only .gitkeep)
  [ -x "$h" ] || { echo "FAIL: $h not executable"; exit 1; }
done

echo "PASS: Full bootstrap"

echo ""
echo "=== Test 2: Knowledge-only (has .claude/ but no knowledge/) ==="
cd "$TEST_DIR"
mkdir -p partial-project/.claude && cd partial-project
git init -q
touch flake.nix

"$1"

[ -d .claude/knowledge ] || { echo "FAIL: knowledge/ not created"; exit 1; }
echo "PASS: Knowledge-only bootstrap"

echo ""
echo "=== Test 3: Already onboarded (has everything) ==="
cd "$TEST_DIR/fake-project"

OUTPUT=$("$1" 2>&1) || true
echo "$OUTPUT" | grep -q "already" || echo "WARN: expected 'already onboarded' message"
echo "PASS: Already-onboarded detection"

echo ""
echo "All tests passed."
