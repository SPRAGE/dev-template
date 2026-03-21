# CLAUDE.md

## Project

PROJECTNAME — TODO: replace with one-line description.

## Getting Started

This project was scaffolded from dev-template. To set up:

1. Replace `PROJECTNAME` in this file and `flake.nix`
2. `direnv allow` to enter the dev shell (includes ruflo)
3. Run `/virtual-tech-org` to spin up a full virtual tech company that builds your project through staged delivery (discovery → architecture → prototype → MVP → production)
   - OR use individual skills: `/project-brainstorm` → `/cc-project-setup` → `/feature-planner`
4. OR if onboarding an existing project: run `/cc-onboard` to scan your codebase and generate config

## Stack

TODO: filled in by `/cc-project-setup` after brainstorm.

## Knowledge Store

Project context persists in `.claude/knowledge/`:
- `active-context.md` — current focus, recent decisions, blockers
- `decisions.md` — architectural decisions in effect
- `architecture-snapshot.md` — codebase structure (auto-generated)
- `conventions.md` — coding patterns (auto-generated)
- `stale-log.md` — audit trail of removed items

Hooks automatically maintain this store. Run `/cc-refresh` to audit and clean up.

## Commands

- `nix develop` — enter dev shell
- `ruflo mcp start` — start ruflo MCP server (auto-configured in .mcp.json)
- `nix run github:USER/dev-template#sync-skills` — pull latest skills from template

## Conventions

TODO: filled in by `/cc-project-setup` after brainstorm.
