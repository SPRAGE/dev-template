# Design: `nix run .#fresh-start`

## Goal

A flake app that nukes all Claude Code configuration and re-syncs the template scaffolding, leaving the project ready for `/cc-setup` brownfield onboarding. Ensures zero contamination from stale config.

## Behavior

### Step 1: Safety Gate

Prompt the user with a summary of what will be removed. Require explicit `y` confirmation. Default to abort.

### Step 2: Nuke Phase

Remove all Claude Code artifacts in this order:

1. `.claude/` — entire directory (skills, hooks, knowledge, settings, rules, archive)
2. `CLAUDE.md` — project root
3. `.mcp.json` — project root
4. `.claude.local.md` — if exists
5. `~/.claude/projects/<sanitized-cwd>/` — auto-memory and session history

**CWD sanitization**: Claude Code converts `/home/user/project` → `-home-user-project`. The script replicates this by replacing `/` with `-` and prepending `-` if needed.

For each target, print what was removed. Skip silently if target doesn't exist (idempotent).

### Step 3: Restore Phase

Re-sync template scaffolding from the flake's Nix store paths (same sources as `onboard`):

1. `.claude/settings.json` — from `template/.claude/settings.json`
2. `.claude/knowledge/*` — empty templates from `template/.claude/knowledge/`
3. `.claude/hooks/*` — all hook scripts from `template/.claude/hooks/`, made executable
4. `.claude/skills/*` — all skills from `template/.claude/skills/`
5. `.mcp.json` — from `template/.mcp.json`
6. `CLAUDE.md` — template stub from `template/CLAUDE.md`

Print each restored item.

### Step 4: Report

Print summary and next steps:
```
Fresh start complete. Open Claude Code and run /cc-setup to generate config from your codebase.
```

## Edge Cases

- **No project root**: Error if no `flake.nix`, `.git`, `package.json`, `Cargo.toml`, `pyproject.toml`, or `go.mod` found.
- **Idempotent**: Safe to run multiple times. Missing targets are skipped.
- **Auto-memory path not found**: Skip with message (user may not have run Claude Code here before).

## Implementation

Add `apps.fresh-start` to `flake.nix` alongside existing `apps.sync-skills` and `apps.onboard`. Reuses the same `let` bindings (`skills-src`, `hooks-src`, `knowledge-src`, `settings-src`, `mcp-src`, `claude-md-src`).

## Non-Goals

- No backup/archive of removed files (this is intentional — the user wants a clean slate)
- No automatic invocation of `/cc-setup` (requires interactive Claude Code session)
- No git commit of the changes (user decides when to commit)
