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
- `template/.claude/` - Claude Code-specific settings, hooks, and skills.
- `tests/` - smoke tests for apps, onboarding, and skill archives.

## Entry Points

- `nix flake check --all-systems`
- `nix run .#onboard`
- `nix run .#sync-skills`
- `nix run .#fresh-start`
- `nix run .#ai-doctor`

## Data Flow

- Template files are copied by `nix flake init`.
- Flake apps seed or refresh AI context, Claude Code settings, hooks, and skills.
- Root `*.skill` archives are generated from `template/.claude/skills/`.

## Deployment / Runtime

- Consumers initialize projects through Nix flake templates.
- Claude Code reads `CLAUDE.md` and `.claude/` runtime files.
- Codex reads `AGENTS.md`.
- Both provider adapters point agents to `.ai/`.

## Known Gaps

- Some existing skill wording still uses Claude Code terminology because the skills are Claude Code-specific.
