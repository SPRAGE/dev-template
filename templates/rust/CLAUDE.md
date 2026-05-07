# CLAUDE.md

## Project

PROJECTNAME — TODO: replace with one-line description.

## Getting Started

1. Replace `PROJECTNAME` in `.ai/instructions.md`, this file, `AGENTS.md`, and `flake.nix`
2. `cargo init` or `cargo new . --name your-crate`
3. `direnv allow` to enter the dev shell
4. Run `/planner` to brainstorm, then `/cc-setup` to generate config
   - OR run `/virtual-tech-org` for full autonomous staged delivery

## Stack

- Rust (stable via rust-overlay)
- Nix flake devShell

## Commands

- `cargo build` — build
- `cargo test` — test
- `cargo clippy -- -D warnings` — lint
- `cargo fmt --check` — check formatting
- `nix develop` — enter dev shell
- `nix run github:SPRAGE/dev-template#ai-doctor` — validate AI context files and hooks

## Conventions

- Error handling: `thiserror` for library errors, `anyhow` for binaries
- snake_case for functions, PascalCase for types
- Tests in `#[cfg(test)]` modules alongside the code

## Shared AI Context

Project context is tracked in `.ai/` so Claude Code and Codex read the same base files:

- `instructions.md` — provider-neutral project instructions
- `active-context.md` — current work and next steps
- `architecture-snapshot.md` — stack, structure, and runtime map
- `conventions.md` — coding, testing, and review conventions
- `decisions.md` — active architectural decisions
- `stale-log.md` — audit trail for removed or superseded context

## Provider Adapters

`CLAUDE.md` is the Claude Code adapter. `AGENTS.md` is the Codex-compatible adapter. Provider-specific settings remain in provider-specific folders such as `.claude/`.
