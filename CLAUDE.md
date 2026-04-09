# CLAUDE.md

## Project

dev-template — Nix flake templates for scaffolding new projects with Claude Code baked in.

## Prerequisites

- Nix with flakes enabled
- direnv (optional but recommended)

## Structure

- `template/` — base template (language-agnostic devShell)
- `templates/rust/` — Rust template with rust-overlay, cargo tools
- `templates/python/` — Python template with uv
- `*.skill` — distributable skill archives for manual installation
- `template/.claude/knowledge/decisions.md` — architectural decision record template
- `template/.claude/hooks/` — hook scripts (session-start, statusline)

Each template bundles:
- **Claude Code** — AI coding assistant (via `github:sadjow/claude-code-nix` flake input)
- **virtual-tech-org** skill — simulates a full tech company (CEO + CTO + engineering team) that builds software via Claude Code's native agent system (parallel subagents, git worktrees, background agents). Integrates superpowers for disciplined engineering (TDD, code review, verification). Language/stack-agnostic, supports any project archetype.
- **planner** skill — interactive planning companion (project mode: 7 phases -> project brief; feature mode: 8 steps -> feature spec)
- **cc-setup** skill — set up Claude Code for any project (greenfield from brief, brownfield from codebase scan, or recommend automations)
- **cc-refresh** skill — audit and refresh Claude Code context with CLAUDE.md quality scoring (A-F grades)
- **frontend-design** skill — production-grade frontend interfaces with distinctive aesthetics
- **fresh-start** skill — nuke all Claude Code config and restore from dev-template defaults (preserves auto-memory)
- **skill-creator** skill — create, test, and iterate on skills with eval framework
- **playground** skill — interactive HTML playgrounds for visual exploration

## Commands

- `nix flake check` — validate the flake
- `nix flake init -t .` — test default template
- `nix flake init -t .#rust` — test rust template
- `nix flake init -t .#python` — test python template
- `nix run .#sync-skills` — sync skills into current project from template
- `nix run .#onboard` — bootstrap Claude Code onto an existing project
- `nix run .#fresh-start` — nuke all Claude Code config and re-sync from template (clean slate)

## Workflow (for new projects)

1. `nix flake init -t github:USER/dev-template#rust` (or `#python`, or default)
2. Replace `PROJECTNAME` in files
3. `direnv allow`
4. Open Claude Code -> `/virtual-tech-org` to spin up the full org and build through staged delivery
   - OR use individual skills: `/planner` -> `/cc-setup` -> `/planner` (feature mode)
5. OR run `nix run .#onboard` to bootstrap Claude Code onto an existing repo, then `/cc-setup` to scan and configure
6. Use `/cc-refresh` periodically to clean up stale context

## Conventions

- All templates use `nixpkgs-unstable` + `flake-utils.eachDefaultSystem`
- `PROJECTNAME` is the placeholder token
- Claude Code included via overlay in every template's devShell
- Keep templates minimal — skills handle project-specific customization
- Skills are the single source of truth in `template/.claude/skills/` — all templates sync from there
