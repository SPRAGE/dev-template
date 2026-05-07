# Agent Guide

## Context

Read these provider-neutral files before non-trivial work:

1. `.ai/instructions.md`
2. `.ai/context/active-context.md`
3. `.ai/context/architecture-snapshot.md`
4. `.ai/context/conventions.md`
5. `.ai/context/decisions.md`

## Workflow

- Start by inspecting the current tree and git status.
- Prefer `rg`, `fd`, and `jq` for codebase exploration when available.
- Keep edits scoped to the requested behavior and existing project style.
- Update `.ai/context/active-context.md` when work spans sessions or changes project direction.
- Run the relevant build, test, lint, or format checks listed in `CLAUDE.md` before finishing.

## Safety

- Treat `.env*`, key files, tokens, and credentials as sensitive.
- Do not overwrite local AI settings such as `.claude/settings.local.json`, `.codex/`, or `.agents/`.
- Do not run destructive git or filesystem operations unless the user explicitly asks.
