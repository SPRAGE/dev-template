# AI.md

## Project

PROJECTNAME - TODO: replace with one-line description.

## Getting Started

1. Replace `PROJECTNAME` in `.ai/instructions.md`, `AI.md`, `AGENTS.md`, `CODEX.md`, and `flake.nix`
2. `direnv allow` to enter the dev shell
3. Use `planner` to brainstorm your project, then `cc-setup` to generate config
   - OR use `virtual-tech-org` for autonomous staged delivery (discovery -> production)

## Stack

TODO: fill in after running `cc-setup`.

## Commands

- `nix develop` - enter dev shell
- `nix run github:SPRAGE/dev-template#sync-skills` - pull latest shared skills, managed adapters, provider skill links, Codex config/custom agents, hooks, and AI context templates
- `nix run github:SPRAGE/dev-template#ai-doctor` - validate AI context files, shared skills, provider skill links, Codex config/custom agents, and hooks

## Architecture

TODO: fill in after running `cc-setup` or manually.

## Conventions

TODO: fill in after running `cc-setup` or manually.

## Agent Workflow

- Start by inspecting the current tree and git status.
- Prefer `rg`, `fd`, and `jq` for codebase exploration when available.
- Keep edits scoped to the requested behavior and existing project style.
- Update `.ai/context/active-context.md` when work spans sessions or changes project direction.
- Run the relevant build, test, lint, or format checks listed above before finishing.

## Safety

- Treat `.env*`, key files, tokens, and credentials as sensitive.
- Do not overwrite local AI settings such as `.claude/settings.local.json`, `.agents/local/`, `.agents/tmp/`, `.codex/local/`, or `.codex/tmp/`.
- Do not run destructive git or filesystem operations unless the user explicitly asks.

## Shared AI Context & Skills

Provider-neutral context and skills live in `.ai/`. Read order, response style, rules, and the provider-adapter map are in `.ai/instructions.md`. Shared skills are in `.ai/skills/`; `.agents/skills/`, `.claude/skills/`, and `.codex/skills/` are symlinks to it — read `.ai/skills/<name>/SKILL.md` for a skill's source.
