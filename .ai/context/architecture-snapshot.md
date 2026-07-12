# Architecture Snapshot

## Stack

- Nix flakes package templates, development shells, and lifecycle apps.
- Bash implements app orchestration and integration tests.
- Python/PyYAML validates the neutral agent specification and generates provider artifacts.

## Structure

- `template/.ai/` contains authored policy, capabilities, profiles, model bindings, agents, context, skills, eval fixtures, and compiler; instructions and methodology are compiled readable views.
- `template/.codex/agents/`, `template/.claude/agents/`, and top-level adapters are generated.
- `templates/python` and `templates/rust` mirror the base except for four explicit overlays.
- `flake.nix` exposes templates plus `onboard`, `sync-skills`, `fresh-start`, and `ai-doctor`.
- `skills/*.skill` are deterministic archives of `template/.ai/skills/*`.

## Data Flow

1. Edit neutral source or a language overlay.
2. Compile provider artifacts.
3. Generate language mirrors.
4. Package changed skills.
5. CI compares sources, generated files, budgets, archives, and lifecycle behavior.

## Runtime

- Codex: Sol deep, Terra balanced, Luna fast.
- Claude: Opus deep, Sonnet balanced, Haiku fast.
- The primary retains requirements and integration state; flat subagents execute bounded work and return structured reports.

## Known Constraint

- The user-selected private Codex input currently replaces the public GitHub source. Unsupported systems fall back to `nixpkgs#codex`, but external consumers still need access to evaluate the private input URL.
