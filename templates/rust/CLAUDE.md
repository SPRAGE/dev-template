# CLAUDE.md

## Project

PROJECTNAME — TODO: replace with one-line description.

## Getting Started

1. Replace `PROJECTNAME` in this file and `flake.nix`
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

## Conventions

- Error handling: `thiserror` for library errors, `anyhow` for binaries
- snake_case for functions, PascalCase for types
- Tests in `#[cfg(test)]` modules alongside the code

## Decisions

Architectural decisions are tracked in `.claude/knowledge/decisions.md`.
