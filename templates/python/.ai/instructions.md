# AI Instructions

## Project

PROJECTNAME - TODO: replace with one-line description.

## Read Order

1. `.ai/instructions.md`
2. `.ai/context/active-context.md`
3. `.ai/context/architecture-snapshot.md`
4. `.ai/context/conventions.md`
5. `.ai/context/decisions.md`

## Provider Adapters

- `AGENTS.md` is the Codex-compatible entry point.
- `CLAUDE.md` is the Claude Code entry point.
- `.claude/` contains Claude Code settings, hooks, and skills.

## Python Commands

- `uv run python main.py` - run.
- `uv run pytest` - test.
- `uv run ruff check .` - lint.
- `uv run ruff format .` - format.
- `nix develop` - enter dev shell.
- `nix run github:SPRAGE/dev-template#ai-doctor` - validate AI context files and provider-specific settings layout.

## Rules

- Treat `.ai/context/` as the shared project context source of truth.
- Use `uv` for package and command execution.
- Prefer type hints on function signatures and tests under `tests/`.
- Keep provider-specific runtime settings out of `.ai/`.
