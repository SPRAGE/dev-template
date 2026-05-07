# Active Context

## Current Focus

- Refactoring the template so shared AI context is provider-neutral.

## Recent Decisions

- `.ai/` is the shared base for project instructions and context.
- `.claude/` remains Claude Code-specific runtime configuration.
- `AGENTS.md` and `CLAUDE.md` act as thin provider adapters.

## Key Files in Play

- `flake.nix`
- `template/.ai/`
- `template/AGENTS.md`
- `template/CLAUDE.md`
- `tests/test-apps.sh`
- `tests/test-onboard.sh`

## Blockers / Questions

- None currently.

## Next Steps

- Keep tests and skill archives aligned with `.ai/context`.
