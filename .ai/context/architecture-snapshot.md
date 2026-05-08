# Architecture Snapshot

## Stack

- Nix flakes for template and app packaging.
- Bash for app smoke tests and generated app scripts.
- Markdown skill files and AI guidance files.
- Python helpers inside the skill-creator skill.

## Project Structure

- `template/` - base scaffold for generic projects.
- `templates/python/` - Python-specific scaffold.
- `templates/rust/` - Rust-specific scaffold.
- `.ai/` - shared provider-neutral context for this repository.
- `template/.ai/` - shared provider-neutral context seeded into generated projects.
- `template/.ai/skills/` - shared skill catalog seeded into generated projects.
- `template/.agents/` - official Codex repo-scoped skill link seeded into generated projects.
- `template/.claude/` - Claude Code-specific settings, hooks, and skill link.
- `template/.codex/` - Codex project config, custom agents, compatibility skill link, and README seeded into generated projects.
- `template/AI.md` - shared top-level agent guide seeded into generated projects.
- `tests/` - smoke tests for apps, onboarding, and skill archives.

## Entry Points

- `nix flake check --all-systems`
- `nix run .#onboard`
- `nix run .#sync-skills`
- `nix run .#fresh-start`
- `nix run .#ai-doctor`

## Data Flow

- Template files are copied by `nix flake init`.
- Flake apps seed or refresh AI context, shared skills, provider skill links, Codex config/custom agents, Claude Code settings, and hooks.
- `skills/*.skill` archives are generated from `template/.ai/skills/`.

## Deployment / Runtime

- Consumers initialize projects through Nix flake templates.
- All agents read `AI.md` and `.ai/` shared context.
- Claude Code reads `CLAUDE.md` and `.claude/` runtime files as a compatibility layer.
- Codex reads `AGENTS.md` as an auto-load compatibility layer; `CODEX.md` is a named adapter alias for humans and tools.
- Codex discovers repo-scoped skills from `.agents/skills/`; `.ai/skills/` remains the shared source and `.codex/skills/` remains a compatibility link.
- Both provider adapters point agents to `.ai/`.

## Known Gaps

- Some shared skills still reference Claude Code-only features; non-Claude agents should adapt the workflow where possible and state limitations.
