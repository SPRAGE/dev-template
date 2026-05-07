# AI Instructions

## Purpose

`dev-template` builds Nix flake templates for AI-assisted development. The shared, provider-neutral context lives under `.ai/`; provider-specific settings stay in their own folders.

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

## Rules

- Treat `.ai/context/` as the shared project context source of truth.
- Keep provider-specific runtime settings out of `.ai/`.
- Do not edit `.claude/settings.json` or other permission files unless the user explicitly asks for that settings change.
