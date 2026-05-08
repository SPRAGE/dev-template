# Active Context

## Current Focus

- Refactoring the template so shared AI context and shared skills are provider-neutral.

## Recent Decisions

- `.ai/` is the shared base for project instructions and context.
- `template/.ai/skills/` is the shared skill catalog.
- `.agents/skills/` is the official Codex repo-scoped skill path linked to `.ai/skills/`.
- `.claude/` remains Claude Code-specific runtime configuration.
- `.codex/` carries Codex project config, custom agents, and a compatibility skill link.
- `AI.md` is the shared top-level guide.
- `AGENTS.md`, `CODEX.md`, and `CLAUDE.md` act as thin provider compatibility adapters.

## Key Files in Play

- `flake.nix`
- `template/.ai/`
- `template/.ai/skills/`
- `template/.agents/`
- `template/.claude/skills/`
- `template/.codex/`
- `template/AI.md`
- `template/AGENTS.md`
- `template/CODEX.md`
- `template/CLAUDE.md`
- `tests/test-apps.sh`
- `tests/test-onboard.sh`
- `tests/test-skills.sh`

## Blockers / Questions

- None currently.

## Next Steps

- Keep tests, provider skill links, Codex repo skills/config, and skill archives aligned with `.ai/context`.
