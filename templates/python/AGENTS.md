# Agent Guide

## Context

Read these provider-neutral files before non-trivial work:

1. `.ai/instructions.md`
2. `.ai/context/active-context.md`
3. `.ai/context/architecture-snapshot.md`
4. `.ai/context/conventions.md`
5. `.ai/context/decisions.md`

## Python Workflow

- Use `uv` for package and command execution.
- Expected checks are usually `uv run pytest`, `uv run ruff check .`, and `uv run ruff format .`; confirm the project has those tools before relying on them.
- Prefer type hints on function signatures and tests under `tests/`.

## Safety

- Treat `.env*`, key files, tokens, and credentials as sensitive.
- Do not overwrite local AI settings such as `.claude/settings.local.json`, `.codex/`, or `.agents/`.
- Do not run destructive git or filesystem operations unless the user explicitly asks.
