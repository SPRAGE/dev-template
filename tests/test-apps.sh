#!/usr/bin/env bash
# tests/test-apps.sh — smoke tests for nix app behavior
set -euo pipefail
export PYTHONDONTWRITEBYTECODE=1

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

write_test_skill() {
  local skill_dir=$1
  local skill_name=$2
  mkdir -p "$skill_dir"
  printf '%s\n' \
    '---' \
    "name: $skill_name" \
    'description: Local lifecycle test skill.' \
    '---' \
    '' \
    "# $skill_name" > "$skill_dir/SKILL.md"
  printf '%s\n' \
    'version: 1' \
    "name: $skill_name" \
    'managed_by: local-test' \
    'audience: default' \
    'requires_capabilities: []' \
    'budgets: {entry_tokens: 700, total_tokens: 900}' \
    'references: []' \
    'package: [SKILL.md, manifest.yaml]' \
    'triggers:' \
    '  positive: [one, two, three, four, five]' \
    '  negative: [six, seven, eight, nine, ten]' > "$skill_dir/manifest.yaml"
}

for manifest in "$REPO"/template/.ai/skills/*/manifest.yaml; do
  grep -Eq '^managed_by:[[:space:]]*dev-template[[:space:]]*$' "$manifest" || {
    echo "FAIL: $manifest is missing dev-template ownership"
    exit 1
  }
done

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
mkdir -p .claude/hooks
printf '# Agent Guide\n\nRead these provider-neutral files before non-trivial work:\n' > AGENTS.md
printf '# Codex Adapter\n\nold adapter\n' > CODEX.md
printf '# Claude Code Adapter\n\nRead `AI.md` first.\nold adapter\n' > CLAUDE.md
printf 'PROJECTNAME - old template stub\n' > AI.md
write_test_skill .ai/skills/local-shared local-shared
write_test_skill .ai/skills/planner planner
write_test_skill .claude/skills/local-claude local-claude
write_test_skill .agents/skills/local-agent local-agent
write_test_skill .codex/skills/local-codex local-codex

# These are exact retired dev-template defaults and should be migrated.
cat > .claude/settings.json <<'EOF'
{
  "enabledPlugins": {
    "superpowers@claude-plugins-official": true,
    "code-simplifier@claude-plugins-official": true
  },
  "permissions": {
    "allow": [
      "Bash(git:*)",
      "Bash(nix:*)",
      "Bash(npx:*)",
      "Bash(cargo:*)",
      "Bash(uv:*)",
      "mcp__context7__resolve-library-id",
      "mcp__context7__query-docs"
    ],
    "deny": [
      "Edit(//.env)",
      "Edit(//.env.*)",
      "Read(//.env)",
      "Read(//.env.*)",
      "Edit(//.git/**)",
      "Bash(git push --force:*)",
      "Bash(sudo:*)",
      "Bash(curl:*)",
      "Bash(wget:*)",
      "Bash(ssh:*)",
      "Bash(scp:*)",
      "Bash(nix-store --delete:*)"
    ]
  },
  "hooks": {
    "SessionStart": [
      {
        "hooks": [
          {
            "type": "command",
            "command": ".claude/hooks/session-start.sh"
          }
        ]
      }
    ]
  },
  "statusLine": {
    "type": "command",
    "command": ".claude/hooks/statusline.sh"
  }
}
EOF
cat > .mcp.json <<'EOF'
{
  "mcpServers": {
    "context7": {
      "type": "stdio",
      "command": "npx",
      "args": ["-y", "@upstash/context7-mcp@latest"]
    }
  }
}
EOF
cat > .claude/hooks/session-start.sh <<'EOF'
#!/usr/bin/env bash
# session-start.sh — surfaces active architectural decisions at session start
# Event: SessionStart
set -euo pipefail

DECISIONS_FILE=".ai/context/decisions.md"

# Skip if no decisions file or it's empty/template
[ -f "$DECISIONS_FILE" ] || exit 0
grep -q "^## " "$DECISIONS_FILE" 2>/dev/null || exit 0

ACTIVE_DECISIONS=$(grep -B1 -A3 "active" "$DECISIONS_FILE" 2>/dev/null | grep -v "^--$" || true)
if [ -n "$ACTIVE_DECISIONS" ]; then
  echo "=== Active Decisions ==="
  echo "$ACTIVE_DECISIONS"
  echo ""
fi
EOF
printf 'custom statusline\n' > .claude/hooks/statusline.sh
printf 'custom hook\n' > .claude/hooks/custom-hook.sh
run_app sync-skills

cmp -s .claude/settings.json "$REPO/template/.claude/settings.json" || { echo "FAIL: retired managed Claude settings were not migrated"; exit 1; }
cmp -s .mcp.json "$REPO/template/.mcp.json" || { echo "FAIL: retired managed Context7 config was not migrated"; exit 1; }
[ ! -f .claude/hooks/session-start.sh ] || { echo "FAIL: retired managed session-start hook was not removed"; exit 1; }
grep -qx 'custom statusline' .claude/hooks/statusline.sh || { echo "FAIL: customized statusline hook was overwritten"; exit 1; }
grep -qx 'custom hook' .claude/hooks/custom-hook.sh || { echo "FAIL: custom hook was removed"; exit 1; }
grep -qx '# planner' .ai/skills/planner/SKILL.md || { echo "FAIL: unmarked same-name skill collision was overwritten"; exit 1; }

for d in .claude/skills/agent-context \
         .agents/skills/agent-context \
         .codex/skills/agent-context \
         .ai/skills/agent-context; do
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
         .ai/project.yaml \
         .ai/policy.yaml \
         .ai/methodology.md \
         .ai/capabilities/map.yaml \
         .ai/agents/scout.yaml \
         .ai/evals/contract-scenarios.yaml \
         .ai/catalog/index.yaml \
         .ai/tools/skillctl.py \
         .ai/context/.gitignore \
         .agents/README.md \
         .codex/README.md \
         .codex/config.toml \
         .claude/agents/scout.md \
         .codex/agents/scout.toml \
         AI.md \
         CLAUDE.md \
         CODEX.md \
         AGENTS.md; do
  [ -f "$f" ] || { echo "FAIL: $f not synced"; exit 1; }
done
[ -z "$(find .ai/context -maxdepth 1 -type f ! -name .gitignore -print)" ] || { echo "FAIL: sync should not seed placeholder project facts"; exit 1; }

# Missing generated outputs must come from the target v2 spec, not template defaults.
sed -i 's/id: gpt-5.6-terra/id: gpt-5.6-terra-lifecycle-test/' .ai/capabilities/runtimes/codex.yaml
sed -i 's/max_threads: 4/max_threads: 3/' .ai/capabilities/runtimes/codex.yaml
rm .codex/config.toml .codex/agents/researcher.toml .claude/agents/researcher.md
run_app sync-skills
grep -q 'model = "gpt-5.6-terra-lifecycle-test"' .codex/agents/researcher.toml || { echo "FAIL: missing Codex role was copied from template instead of compiled from target spec"; exit 1; }
grep -q 'max_threads = 3' .codex/config.toml || { echo "FAIL: missing Codex config was copied from template instead of compiled from target spec"; exit 1; }
[ -f .claude/agents/researcher.md ] || { echo "FAIL: target compiler did not restore missing Claude role"; exit 1; }

# Existing neutral configuration and provider outputs are authoritative during sync.
printf '\n# stale managed compiler fixture\n' >> .ai/generators/compile.py
printf '\n# stale managed skill fixture\n' >> .ai/skills/agent-context/SKILL.md
sed -i 's/Running ordinary tests or a one-off review\./Ordinary tests./' .ai/catalog/index.yaml
printf '\n# customized activation tool fixture\n' >> .ai/tools/skillctl.py
printf '\n# customized provider config\n' >> .codex/config.toml
printf '\n# customized provider role\n' >> .codex/agents/reviewer.toml
printf '{"custom":true}\n' > .claude/settings.json
printf '{"mcpServers":{"custom":{"type":"stdio","command":"custom-mcp"}}}\n' > .mcp.json
run_app sync-skills
grep -q '# stale managed compiler fixture' .ai/generators/compile.py || { echo "FAIL: sync-skills replaced the target compiler without migration"; exit 1; }
cmp -s .ai/skills/agent-context/SKILL.md "$REPO/template/.ai/skills/agent-context/SKILL.md" || { echo "FAIL: marked managed skill was not refreshed"; exit 1; }
grep -q 'avoid_when: Ordinary tests\.' .ai/catalog/index.yaml || { echo "FAIL: sync-skills replaced the project catalog"; exit 1; }
grep -q '# customized activation tool fixture' .ai/tools/skillctl.py || { echo "FAIL: sync-skills replaced the project activation tool"; exit 1; }
grep -q '# customized provider config' .codex/config.toml || { echo "FAIL: customized Codex config was overwritten"; exit 1; }
grep -q '# customized provider role' .codex/agents/reviewer.toml || { echo "FAIL: customized Codex role was overwritten"; exit 1; }
grep -qx '# planner' .ai/skills/planner/SKILL.md || { echo "FAIL: customized skill collision was not preserved on refresh"; exit 1; }
grep -qx '{"custom":true}' .claude/settings.json || { echo "FAIL: customized Claude settings were not preserved"; exit 1; }
grep -q 'custom-mcp' .mcp.json || { echo "FAIL: customized MCP config was not preserved"; exit 1; }
grep -qx 'custom statusline' .claude/hooks/statusline.sh || { echo "FAIL: customized statusline hook was not preserved on refresh"; exit 1; }
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
printf '{"keep":true}\n' > .claude/settings.local.json
mkdir -p .codex/skills/old-skill
echo old > .codex/skills/old-skill/SKILL.md
mkdir -p .agents/skills/old-skill
echo old > .agents/skills/old-skill/SKILL.md
mkdir -p .ai/context .ai/skills/old-skill
echo old > .ai/context/active-context.md
echo old > .ai/skills/old-skill/SKILL.md
for state_root in .ai .agents .codex; do
  for state_dir in local tmp sessions logs; do
    mkdir -p "$state_root/$state_dir"
    printf 'keep %s/%s\n' "$state_root" "$state_dir" > "$state_root/$state_dir/state.txt"
  done
done
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
[ -f .claude/settings.local.json ] || { echo "FAIL: .claude/settings.local.json was not preserved"; exit 1; }
grep -q '"keep":true' .claude/settings.local.json || { echo "FAIL: .claude/settings.local.json content changed"; exit 1; }
for state_root in .ai .agents .codex; do
  for state_dir in local tmp sessions logs; do
    [ -f "$state_root/$state_dir/state.txt" ] || { echo "FAIL: $state_root/$state_dir was not preserved"; exit 1; }
    grep -qx "keep $state_root/$state_dir" "$state_root/$state_dir/state.txt" || { echo "FAIL: $state_root/$state_dir content changed"; exit 1; }
  done
done

for d in .claude/skills/agent-context \
         .agents/skills/agent-context \
         .codex/skills/agent-context \
         .ai/skills/agent-context; do
  [ -d "$d" ] || { echo "FAIL: $d not restored"; exit 1; }
done
assert_skill_link .ai/skills .claude/skills
assert_skill_link .ai/skills .agents/skills
assert_skill_link .ai/skills .codex/skills

for f in .ai/instructions.md \
         .ai/project.yaml \
         .ai/policy.yaml \
         .ai/methodology.md \
         .ai/capabilities/map.yaml \
         .ai/agents/scout.yaml \
         .ai/evals/contract-scenarios.yaml \
         .ai/catalog/index.yaml \
         .ai/tools/skillctl.py \
         .ai/context/.gitignore \
         .agents/README.md \
         .codex/README.md \
         .codex/config.toml \
         .claude/agents/scout.md \
         .codex/agents/scout.toml \
         .claude/settings.json \
         .mcp.json \
         flake.nix \
         AI.md \
         CLAUDE.md \
         CODEX.md \
         AGENTS.md; do
  [ -f "$f" ] || { echo "FAIL: $f not restored"; exit 1; }
done
[ ! -f .ai/context/active-context.md ] || { echo "FAIL: placeholder active-context.md should not be restored"; exit 1; }
[ -z "$(find .ai/context -maxdepth 1 -type f ! -name .gitignore -print)" ] || { echo "FAIL: fresh-start should not restore placeholder project facts"; exit 1; }
grep -q 'model = "gpt-5.6-sol"' .codex/agents/reviewer.toml || { echo "FAIL: deep reviewer pin missing"; exit 1; }
grep -q 'model = "gpt-5.6-terra"' .codex/agents/worker.toml || { echo "FAIL: balanced worker pin missing"; exit 1; }
grep -q 'model = "gpt-5.6-luna"' .codex/agents/scout.toml || { echo "FAIL: fast scout pin missing"; exit 1; }
jq -e '.permissions.allow | index("Bash(git status:*)") != null' .claude/settings.json >/dev/null || { echo "FAIL: safe git inspection is not allowed"; exit 1; }
jq -e '.permissions.allow | index("Bash(cargo test:*)") != null' .claude/settings.json >/dev/null || { echo "FAIL: focused validation is not allowed"; exit 1; }
jq -e '([.permissions.allow[], .permissions.deny[]] | index("Bash(npx:*)")) == null' .claude/settings.json >/dev/null || { echo "FAIL: npx should require normal confirmation"; exit 1; }
jq -e '([.permissions.allow[], .permissions.deny[]] | index("Bash(curl:*)")) == null' .claude/settings.json >/dev/null || { echo "FAIL: direct external commands should require normal confirmation"; exit 1; }
jq -e '([.permissions.allow[], .permissions.deny[]] | index("Bash(git push --force:*)")) == null' .claude/settings.json >/dev/null || { echo "FAIL: destructive commands should require normal confirmation"; exit 1; }
echo "PASS: fresh-start"

echo ""
echo "=== App Test 3b: fresh-start preserves language flavor ==="
for flavor in python rust; do
  project="$TEST_DIR/fresh-$flavor-project"
  mkdir -p "$project"
  cd "$project"
  git init -q
  if [ "$flavor" = rust ]; then
    printf '{ inputs.rust-overlay.url = "github:oxalica/rust-overlay"; }\n' > flake.nix
  else
    printf '{ packages = [ pkgs.python313 pkgs.uv ]; }\n' > flake.nix
  fi
  printf 'old\n' > AI.md
  printf 'y\n' | HOME="$TEST_HOME" nix run "path:$REPO#fresh-start" --
  cmp -s flake.nix "$REPO/templates/$flavor/flake.nix" || { echo "FAIL: $flavor flake flavor was not preserved"; exit 1; }
  cmp -s AI.md "$REPO/templates/$flavor/AI.md" || { echo "FAIL: $flavor AI overlay was not preserved"; exit 1; }
  cmp -s .ai/project.yaml "$REPO/templates/$flavor/.ai/project.yaml" || { echo "FAIL: $flavor project spec overlay was not preserved"; exit 1; }
done
echo "PASS: fresh-start language flavors"

echo ""
echo "=== App Test 4: template shells can compile their agent specs ==="
for template_root in template templates/python templates/rust; do
  nix develop --no-write-lock-file "path:$REPO/$template_root" -c python "$REPO/$template_root/.ai/generators/compile.py" --root "$REPO/$template_root" --check
done
echo "PASS: template compiler dependencies"

echo ""
echo "=== App Test 5: migrate-v2 dry run and recovery contracts ==="
cd "$REPO"
run_app migrate-v2 --check | grep -q 'migration status: already-v2'
nix develop --no-write-lock-file "path:$REPO" -c python "$REPO/tests/test-migrate-v2.py"
echo "PASS: migrate-v2"

echo ""
echo "=== App Test 6: ai-doctor ==="
nix run "path:$REPO#ai-doctor" --
echo "PASS: ai-doctor"

echo ""
echo "All app tests passed."
