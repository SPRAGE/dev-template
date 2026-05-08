# AI Instructions

## Purpose

`dev-template` builds Nix flake templates for AI-assisted development. The shared, provider-neutral context lives under `.ai/`; provider-specific settings stay in their own folders.

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
- `template/.ai/skills/` contains shared skill sources for all agents.
- `template/.agents/skills/` is the official Codex repo-scoped skill link.
- `template/.claude/skills/` is the Claude Code skill link.
- `template/.codex/` contains Codex project config, custom agents, and a compatibility skill link.

## Rules

- Treat `.ai/context/` as the shared project context source of truth.
- Treat `template/.ai/skills/` as the shared skill source of truth.
- Keep `template/.agents/skills/`, `template/.claude/skills/`, and `template/.codex/skills/` linked to `template/.ai/skills/`.
- Keep provider-specific runtime settings out of `.ai/`.
- Do not edit `.claude/settings.json` or other permission files unless the user explicitly asks for that settings change.
