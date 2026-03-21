# CLAUDE.md

## Project

dev-template — Nix flake templates for scaffolding new projects with Claude Code + Ruflo baked in.

## Prerequisites

- Nix with flakes enabled
- direnv (optional but recommended)

## Structure

- `template/` — base template (language-agnostic devShell)
- `templates/rust/` — Rust template with rust-overlay, cargo tools
- `templates/python/` — Python template with uv
- `*.skill` — distributable skill archives for manual installation
- `template/.claude/knowledge/` — knowledge store templates (active-context, decisions, architecture, conventions, stale-log)
- `template/.claude/hooks/` — hook scripts (session-start, context-watchdog, post-commit-persist, session-end, ruflo-sync)

Each template bundles:
- **Claude Code** — AI coding assistant (via `github:sadjow/claude-code-nix` flake input)
- **Ruflo** — AI agent orchestration (via `github:SPRAGE/ruflo-nix` flake input + MCP server)
- **virtual-tech-org** skill — simulates a full tech company (CEO + CTO + engineering team) that builds software via ruflo hive-mind swarm orchestration. Language/stack-agnostic, supports any project archetype (web app, API, CLI, library, data pipeline, etc.). Subsumes brainstorming, architecture, and staged delivery (prototype → MVP → production).
- **project-brainstorm** skill — interactive planning (7 phases → project brief)
- **cc-project-setup** skill — generates CLAUDE.md, .mcp.json, rules from the brief
- **feature-planner** skill — interactive feature spec builder (8 steps → feature spec file)
- **frontend-design** skill — production-grade frontend interfaces with distinctive aesthetics
- **claude-automation-recommender** skill — analyzes codebase, recommends hooks/skills/MCP/subagents
- **claude-md-improver** skill — audits and improves CLAUDE.md files
- **skill-creator** skill — create, test, and iterate on new skills with eval framework
- **writing-rules** skill — create hookify rules for automated guardrails
- **playground** skill — interactive HTML playgrounds for visual exploration

## Commands

- `nix flake check` — validate the flake
- `nix flake init -t .` — test default template
- `nix flake init -t .#rust` — test rust template
- `nix flake init -t .#python` — test python template
- `nix run .#sync-skills` — sync skills into current project from template
- `nix run .#onboard` — bootstrap Claude Code onto an existing project

## Workflow (for new projects)

1. `nix flake init -t github:USER/dev-template#rust` (or `#python`, or default)
2. Replace `PROJECTNAME` in files
3. `direnv allow`
4. Open Claude Code → `/virtual-tech-org` to spin up the full org and build through staged delivery
   - OR use individual skills: `/project-brainstorm` → `/cc-project-setup` → `/feature-planner`
5. OR run `nix run .#onboard` to bootstrap Claude Code onto an existing repo, then `/cc-onboard` to scan and configure
6. Use `/cc-refresh` periodically to clean up stale context, memory, and session history
7. Use `/ruflo-builder` to scaffold custom ruflo agents and workflows from the knowledge store

## Conventions

- All templates use `nixpkgs-unstable` + `flake-utils.eachDefaultSystem`
- `PROJECTNAME` is the placeholder token
- Claude Code + Ruflo included via overlay in every template's devShell
- Keep templates minimal — skills handle project-specific customization
