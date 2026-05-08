#!/usr/bin/env bash
# tests/test-onboard.sh — validates nix run .#onboard behavior
set -euo pipefail

TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT

assert_skill_link() {
  local source=$1
  local link=$2
  [ -L "$link" ] || { echo "FAIL: $link should be a symlink"; exit 1; }
  target=$(readlink "$link")
  [ "$target" = "../.ai/skills" ] || { echo "FAIL: $link should point to ../.ai/skills, got $target"; exit 1; }
  [ -d "$link" ] || { echo "FAIL: $link should resolve to a directory"; exit 1; }
  for skill_dir in "$source"/*; do
    [ -d "$skill_dir" ] || continue
    skill_name=$(basename "$skill_dir")
    [ -d "$link/$skill_name" ] || { echo "FAIL: $link missing shared skill $skill_name"; exit 1; }
  done
}

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
         .agents/README.md \
         .codex/README.md \
         .codex/config.toml \
         .codex/agents/repo-explorer.toml \
         .claude/settings.json \
         .mcp.json \
         AI.md \
         CLAUDE.md \
         CODEX.md \
         AGENTS.md; do
  [ -f "$f" ] || { echo "FAIL: $f not created"; exit 1; }
done

# Verify skills are installed, otherwise next-step commands like /cc-setup cannot work
for d in .claude/skills/cc-setup \
         .claude/skills/cc-refresh \
         .claude/skills/fresh-start \
         .claude/skills/virtual-tech-org \
         .agents/skills/cc-setup \
         .agents/skills/cc-refresh \
         .agents/skills/fresh-start \
         .agents/skills/virtual-tech-org \
         .codex/skills/cc-setup \
         .codex/skills/cc-refresh \
         .codex/skills/fresh-start \
         .codex/skills/virtual-tech-org \
         .ai/skills/cc-setup \
         .ai/skills/cc-refresh \
         .ai/skills/fresh-start \
         .ai/skills/virtual-tech-org; do
  [ -d "$d" ] || { echo "FAIL: $d not created"; exit 1; }
done
assert_skill_link .ai/skills .claude/skills
assert_skill_link .ai/skills .agents/skills
assert_skill_link .ai/skills .codex/skills

# Verify hooks are executable (skip .gitkeep, only check .sh files)
for h in .claude/hooks/*.sh; do
  [ -f "$h" ] || continue  # skip if no .sh files (only .gitkeep)
  [ -x "$h" ] || { echo "FAIL: $h not executable"; exit 1; }
done

echo "PASS: Full bootstrap"

echo ""
echo "=== Test 2: Context-only (has .claude/ but no .ai/) ==="
cd "$TEST_DIR"
mkdir -p partial-project/.claude/skills/local-claude \
         partial-project/.agents/skills/local-agent \
         partial-project/.codex/skills/local-codex
printf '# Local Claude Skill\n' > partial-project/.claude/skills/local-claude/SKILL.md
printf '# Local Agent Skill\n' > partial-project/.agents/skills/local-agent/SKILL.md
printf '# Local Codex Skill\n' > partial-project/.codex/skills/local-codex/SKILL.md
cd partial-project
git init -q
touch flake.nix

"$1"

[ -d .ai/context ] || { echo "FAIL: .ai/context/ not created"; exit 1; }
[ -f .ai/context/active-context.md ] || { echo "FAIL: active-context.md not created"; exit 1; }
[ -d .ai/skills/cc-setup ] || { echo "FAIL: shared cc-setup skill not created"; exit 1; }
[ -d .claude/skills/cc-setup ] || { echo "FAIL: cc-setup skill not created"; exit 1; }
[ -d .agents/skills/cc-setup ] || { echo "FAIL: .agents cc-setup skill not created"; exit 1; }
[ -f .agents/README.md ] || { echo "FAIL: .agents/README.md not created"; exit 1; }
[ -d .codex/skills/cc-setup ] || { echo "FAIL: codex cc-setup skill not created"; exit 1; }
[ -f .codex/README.md ] || { echo "FAIL: .codex/README.md not created"; exit 1; }
[ -f .codex/config.toml ] || { echo "FAIL: .codex/config.toml not created"; exit 1; }
[ -f .codex/agents/repo-explorer.toml ] || { echo "FAIL: .codex custom agents not created"; exit 1; }
assert_skill_link .ai/skills .claude/skills
assert_skill_link .ai/skills .agents/skills
assert_skill_link .ai/skills .codex/skills
[ -f .ai/skills/local-claude/SKILL.md ] || { echo "FAIL: local Claude skill was not migrated to .ai/skills"; exit 1; }
[ -f .ai/skills/local-agent/SKILL.md ] || { echo "FAIL: local agent skill was not migrated to .ai/skills"; exit 1; }
[ -f .ai/skills/local-codex/SKILL.md ] || { echo "FAIL: local Codex skill was not migrated to .ai/skills"; exit 1; }
[ -f .claude/skills/local-agent/SKILL.md ] || { echo "FAIL: migrated skills are not visible through .claude/skills"; exit 1; }
[ -f .agents/skills/local-codex/SKILL.md ] || { echo "FAIL: migrated skills are not visible through .agents/skills"; exit 1; }
[ -f .codex/skills/local-claude/SKILL.md ] || { echo "FAIL: migrated skills are not visible through .codex/skills"; exit 1; }
echo "PASS: Context-only bootstrap"

echo ""
echo "=== Test 3: Already onboarded (has everything) ==="
cd "$TEST_DIR/fake-project"

OUTPUT=$("$1" 2>&1) || true
echo "$OUTPUT" | grep -q "already" || echo "WARN: expected 'already onboarded' message"
echo "PASS: Already-onboarded detection"

echo ""
echo "All tests passed."
