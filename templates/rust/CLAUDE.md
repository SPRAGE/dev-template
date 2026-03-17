# CLAUDE.md

## Project

PROJECTNAME — TODO: replace with one-line description.

## Getting Started

This project was scaffolded from dev-template (Rust variant). To set up:

1. Replace `PROJECTNAME` in this file and `flake.nix`
2. `cargo init` or `cargo new . --name your-crate`
3. `direnv allow` to enter the dev shell (includes rust toolchain + ruflo)
4. Run `/project-brainstorm` to plan the project interactively
5. Run `/cc-project-setup` to generate real CLAUDE.md, .mcp.json, and rules from the plan

## Stack

- Rust (stable via rust-overlay)
- Nix flake devShell
- Ruflo (AI agent orchestration)

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
