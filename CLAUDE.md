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

Each template bundles:
- **Claude Code** — AI coding assistant (via `github:sadjow/claude-code-nix` flake input)
- **Ruflo** — AI agent orchestration (via `github:SPRAGE/ruflo-nix` flake input + MCP server)
- **project-brainstorm** skill — interactive planning (7 phases → project brief)
- **cc-project-setup** skill — generates CLAUDE.md, .mcp.json, rules from the brief

## Commands

- `nix flake check` — validate the flake
- `nix flake init -t .` — test default template
- `nix flake init -t .#rust` — test rust template
- `nix flake init -t .#python` — test python template

## Workflow (for new projects)

1. `nix flake init -t github:USER/dev-template#rust` (or `#python`, or default)
2. Replace `PROJECTNAME` in files
3. `direnv allow`
4. Open Claude Code → `/project-brainstorm` → `/cc-project-setup`

## Conventions

- All templates use `nixpkgs-unstable` + `flake-utils.eachDefaultSystem`
- `PROJECTNAME` is the placeholder token
- Claude Code + Ruflo included via overlay in every template's devShell
- Keep templates minimal — skills handle project-specific customization
