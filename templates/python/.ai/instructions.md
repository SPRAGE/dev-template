# AI Instructions

## Project

PROJECTNAME - TODO: replace with one-line description.

## Read Order

1. `AI.md`
2. `.ai/instructions.md`
3. `.ai/context/active-context.md`
4. `.ai/context/architecture-snapshot.md`
5. `.ai/context/conventions.md`
6. `.ai/context/decisions.md`

## Provider Adapters

- `AI.md` is the shared top-level guide for all agents.
- `AGENTS.md` is the Codex-compatible entry point.
- `CODEX.md` is a named Codex adapter alias for humans and tools.
- `CLAUDE.md` is the Claude Code compatibility entry point.
- `.ai/skills/` contains shared skills for all agents.
- `.agents/skills/` is the official Codex repo-scoped skill link.
- `.claude/` contains Claude Code settings, hooks, and the Claude skill link.
- `.codex/` contains Codex project config, custom agents, the compatibility skill link, and local Codex runtime state.

## Python Commands

- `uv run python main.py` - run.
- `uv run pytest` - test.
- `uv run ruff check .` - lint.
- `uv run ruff format .` - format.
- `nix develop` - enter dev shell.
- `nix run github:SPRAGE/dev-template#sync-skills` - pull latest skills, Codex repo skills/config/custom agents, provider links, hooks, and AI context templates.
- `nix run github:SPRAGE/dev-template#ai-doctor` - validate AI context files, shared skills, provider links, Codex config/custom agents, and provider-specific settings layout.

## Rules

- Treat `.ai/context/` as the shared project context source of truth.
- Treat `.ai/skills/` as the shared skill source of truth.
- Keep `.agents/skills/`, `.claude/skills/`, and `.codex/skills/` linked to `.ai/skills/`, preserving local provider-specific skills.
- Use `uv` for package and command execution.
- Prefer type hints on function signatures and tests under `tests/`.
- Keep provider-specific runtime settings out of `.ai/`.
