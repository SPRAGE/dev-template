#!/usr/bin/env bash
# tests/test-apps.sh — smoke tests for nix app behavior
set -euo pipefail

REPO=${1:-$(git rev-parse --show-toplevel)}
REPO=$(cd "$REPO" && pwd)
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
printf '# Agent Guide\n\nRead these provider-neutral files before non-trivial work:\n' > AGENTS.md
printf '# Codex Adapter\n\nold adapter\n' > CODEX.md
printf '# Claude Code Adapter\n\nRead `AI.md` first.\nold adapter\n' > CLAUDE.md
printf 'PROJECTNAME - old template stub\n' > AI.md
mkdir -p .ai/skills/local-shared \
         .claude/skills/local-claude \
         .agents/skills/local-agent \
         .codex/skills/local-codex
printf '# Local Shared Skill\n' > .ai/skills/local-shared/SKILL.md
printf '# Local Claude Skill\n' > .claude/skills/local-claude/SKILL.md
printf '# Local Agent Skill\n' > .agents/skills/local-agent/SKILL.md
printf '# Local Codex Skill\n' > .codex/skills/local-codex/SKILL.md
run_app sync-skills

for d in .claude/skills/cc-setup \
         .claude/skills/fresh-start \
         .claude/skills/skill-creator \
         .agents/skills/cc-setup \
         .agents/skills/fresh-start \
         .agents/skills/skill-creator \
         .codex/skills/cc-setup \
         .codex/skills/fresh-start \
         .codex/skills/skill-creator \
         .ai/skills/cc-setup \
         .ai/skills/fresh-start \
         .ai/skills/skill-creator; do
  [ -d "$d" ] || { echo "FAIL: $d not synced"; exit 1; }
done
assert_skill_link .ai/skills .claude/skills
assert_skill_link .ai/skills .agents/skills
assert_skill_link .ai/skills .codex/skills
[ -f .ai/skills/local-shared/SKILL.md ] || { echo "FAIL: local shared skill was not preserved"; exit 1; }
[ -f .ai/skills/local-claude/SKILL.md ] || { echo "FAIL: local Claude skill was not migrated to .ai/skills"; exit 1; }
[ -f .ai/skills/local-agent/SKILL.md ] || { echo "FAIL: local agent skill was not migrated to .ai/skills"; exit 1; }
[ -f .ai/skills/local-codex/SKILL.md ] || { echo "FAIL: local Codex skill was not migrated to .ai/skills"; exit 1; }
[ -f .claude/skills/local-agent/SKILL.md ] || { echo "FAIL: migrated skills are not visible through .claude/skills"; exit 1; }
[ -f .agents/skills/local-codex/SKILL.md ] || { echo "FAIL: migrated skills are not visible through .agents/skills"; exit 1; }
[ -f .codex/skills/local-claude/SKILL.md ] || { echo "FAIL: migrated skills are not visible through .codex/skills"; exit 1; }
cmp -s AI.md "$REPO/template/AI.md" || { echo "FAIL: AI.md template stub was not refreshed"; exit 1; }
cmp -s AGENTS.md "$REPO/template/AGENTS.md" || { echo "FAIL: managed AGENTS.md adapter was not refreshed"; exit 1; }
cmp -s CODEX.md "$REPO/template/CODEX.md" || { echo "FAIL: managed CODEX.md adapter was not refreshed"; exit 1; }
cmp -s CLAUDE.md "$REPO/template/CLAUDE.md" || { echo "FAIL: managed CLAUDE.md adapter was not refreshed"; exit 1; }

for f in .ai/instructions.md \
         .ai/context/active-context.md \
         .ai/context/architecture-snapshot.md \
         .ai/context/conventions.md \
         .ai/context/decisions.md \
         .ai/context/stale-log.md \
         .ai/context/.gitignore \
         .agents/README.md \
         .codex/README.md \
         .codex/config.toml \
         .codex/agents/repo-explorer.toml \
         AI.md \
         CLAUDE.md \
         CODEX.md \
         AGENTS.md; do
  [ -f "$f" ] || { echo "FAIL: $f not synced"; exit 1; }
done
echo "PASS: sync-skills"

echo ""
echo "=== App Test 3: fresh-start ==="
mkdir -p "$TEST_DIR/fresh-project"
cd "$TEST_DIR/fresh-project"
git init -q
echo old > flake.nix
echo old > flake.lock
mkdir -p .claude/skills/old-skill .claude/knowledge
echo old > .claude/skills/old-skill/SKILL.md
echo old > .claude/knowledge/decisions.md
mkdir -p .codex/skills/old-skill .codex/local
echo old > .codex/skills/old-skill/SKILL.md
echo keep > .codex/local/state.json
mkdir -p .agents/skills/old-skill .agents/local
echo old > .agents/skills/old-skill/SKILL.md
echo keep > .agents/local/state.json
mkdir -p .ai/context .ai/skills/old-skill
echo old > .ai/context/active-context.md
echo old > .ai/skills/old-skill/SKILL.md
echo old > AI.md
echo old > CLAUDE.md
echo old > CODEX.md
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
[ ! -d .agents/skills/old-skill ] || { echo "FAIL: old Codex repo skill survived fresh-start"; exit 1; }
[ ! -d .codex/skills/old-skill ] || { echo "FAIL: old codex skill survived fresh-start"; exit 1; }
[ ! -d .ai/skills/old-skill ] || { echo "FAIL: old shared skill survived fresh-start"; exit 1; }
[ ! -f .claude/knowledge/decisions.md ] || { echo "FAIL: legacy .claude/knowledge survived fresh-start"; exit 1; }
[ ! -f .claude.local.md ] || { echo "FAIL: .claude.local.md survived fresh-start"; exit 1; }
[ ! -f flake.lock ] || { echo "FAIL: stale flake.lock survived fresh-start"; exit 1; }
cmp -s flake.nix "$REPO/template/flake.nix" || { echo "FAIL: flake.nix was not replaced from template"; exit 1; }
[ -f .agents/local/state.json ] || { echo "FAIL: .agents/local was not preserved"; exit 1; }
[ -f .codex/local/state.json ] || { echo "FAIL: .codex/local was not preserved"; exit 1; }

for d in .claude/skills/cc-setup \
         .claude/skills/fresh-start \
         .claude/skills/virtual-tech-org \
         .agents/skills/cc-setup \
         .agents/skills/fresh-start \
         .agents/skills/virtual-tech-org \
         .codex/skills/cc-setup \
         .codex/skills/fresh-start \
         .codex/skills/virtual-tech-org \
         .ai/skills/cc-setup \
         .ai/skills/fresh-start \
         .ai/skills/virtual-tech-org; do
  [ -d "$d" ] || { echo "FAIL: $d not restored"; exit 1; }
done
assert_skill_link .ai/skills .claude/skills
assert_skill_link .ai/skills .agents/skills
assert_skill_link .ai/skills .codex/skills

for f in .ai/instructions.md \
         .ai/context/active-context.md \
         .ai/context/architecture-snapshot.md \
         .ai/context/conventions.md \
         .ai/context/decisions.md \
         .ai/context/stale-log.md \
         .ai/context/.gitignore \
         .agents/README.md \
         .codex/README.md \
         .codex/config.toml \
         .codex/agents/repo-explorer.toml \
         .claude/settings.json \
         .mcp.json \
         flake.nix \
         AI.md \
         CLAUDE.md \
         CODEX.md \
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
