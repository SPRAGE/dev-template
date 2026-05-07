# CLAUDE.md

## Project

PROJECTNAME — TODO: replace with one-line description.

## Getting Started

1. Replace `PROJECTNAME` in `.ai/instructions.md`, this file, `AGENTS.md`, and `flake.nix`
2. `direnv allow` to enter the dev shell
3. Run `/planner` to brainstorm your project, then `/cc-setup` to generate config
   - OR run `/virtual-tech-org` for full autonomous staged delivery (discovery -> production)

## Stack

TODO: fill in after running `/cc-setup`.

## Commands

- `nix develop` — enter dev shell
- `nix run github:SPRAGE/dev-template#sync-skills` — pull latest skills, hooks, and AI context templates
- `nix run github:SPRAGE/dev-template#ai-doctor` — validate AI context files and hooks

## Architecture

TODO: fill in after running `/cc-setup` or manually.

## Conventions

TODO: fill in after running `/cc-setup` or manually.

## Shared AI Context

Project context is tracked in `.ai/` so Claude Code and Codex read the same base files:

- `instructions.md` — provider-neutral project instructions
- `active-context.md` — current work and next steps
- `architecture-snapshot.md` — stack, structure, and runtime map
- `conventions.md` — coding, testing, and review conventions
- `decisions.md` — active architectural decisions
- `stale-log.md` — audit trail for removed or superseded context

## Provider Adapters

`CLAUDE.md` is the Claude Code adapter. `AGENTS.md` is the Codex-compatible adapter. Provider-specific settings remain in provider-specific folders such as `.claude/`.
