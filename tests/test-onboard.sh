#!/usr/bin/env bash
# Exercise the actual Nix-built entrypoint supplied by test-apps.sh.
set -euo pipefail
fixture=$(mktemp -d)
trap 'rm -rf "$fixture"' EXIT
mkdir -p "$fixture/.git" "$fixture/.claude/skills/local" "$fixture/.codex/local"
printf '%s\n' 'Project-owned purpose' > "$fixture/AI.md"
printf '%s\n' 'Local skill' > "$fixture/.claude/skills/local/SKILL.md"
printf '%s\n' 'session state' > "$fixture/.codex/local/session"
"$1" --root "$fixture"
for file in AGENTS.md CLAUDE.md .ai/template.json .claude/settings.json .claude/hooks/statusline.sh; do
  test -f "$fixture/$file"
done
test ! -e "$fixture/.ai/project.yaml"
test ! -e "$fixture/.ai/skills"
test ! -e "$fixture/.codex/config.toml"
test ! -e "$fixture/.codex/agents"
test "$(cat "$fixture/AI.md")" = 'Project-owned purpose'
test "$(cat "$fixture/.claude/skills/local/SKILL.md")" = 'Local skill'
test "$(cat "$fixture/.codex/local/session")" = 'session state'
test -x "$fixture/.claude/hooks/statusline.sh"
"$1" --root "$fixture"
printf '%s\n' 'PASS: native onboard preserves existing project facts, skills, and local state'
