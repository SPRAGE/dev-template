# AI.md

## Project

PROJECTNAME - TODO: replace with one-line description.

## Getting Started

1. Replace `PROJECTNAME` in `.ai/instructions.md`, `AI.md`, `AGENTS.md`, `CODEX.md`, and `flake.nix`
2. `uv init` to set up the Python project
3. `direnv allow` to enter the dev shell
4. Use `planner` to brainstorm, then `cc-setup` to generate config
   - OR use `virtual-tech-org` for autonomous staged delivery

## Stack

- Python 3.13
- uv (package manager)

## Commands

- `uv run python main.py` - run
- `uv run pytest` - test
- `uv run ruff check .` - lint
- `uv run ruff format .` - format
- `nix develop` - enter dev shell
- `nix run github:SPRAGE/dev-template#sync-skills` - pull latest shared skills, managed adapters, provider skill links, Codex config/custom agents, hooks, and AI context templates
- `nix run github:SPRAGE/dev-template#ai-doctor` - validate AI context files, shared skills, provider skill links, Codex config/custom agents, and hooks

## Conventions

- Type hints on all function signatures
- snake_case for functions/variables, PascalCase for classes
- Tests in `tests/` mirroring `src/` structure

## Agent Workflow

- Start by inspecting the current tree and git status.
- Use `uv` for package and command execution.
- Confirm `pytest` and `ruff` are installed before relying on their commands.
- Keep edits scoped to the requested behavior and existing project style.
- Update `.ai/context/active-context.md` when work spans sessions or changes project direction.

## Safety

- Treat `.env*`, key files, tokens, and credentials as sensitive.
- Do not overwrite local AI settings such as `.claude/settings.local.json`, `.agents/local/`, `.agents/tmp/`, `.codex/local/`, or `.codex/tmp/`.
- Do not run destructive git or filesystem operations unless the user explicitly asks.

## Shared AI Context & Skills

Provider-neutral context and skills live in `.ai/`. Read order, response style, rules, and the provider-adapter map are in `.ai/instructions.md`. Shared skills are in `.ai/skills/`; `.agents/skills/`, `.claude/skills/`, and `.codex/skills/` are symlinks to it — read `.ai/skills/<name>/SKILL.md` for a skill's source.
