# AI.md

## Project

PROJECTNAME - TODO: replace with one-line description.

## Getting Started

1. Replace `PROJECTNAME` in `.ai/instructions.md`, `AI.md`, `AGENTS.md`, `CODEX.md`, and `flake.nix`
2. `cargo init` or `cargo new . --name your-crate`
3. `direnv allow` to enter the dev shell
4. Use `planner` to brainstorm, then `cc-setup` to generate config
   - OR use `virtual-tech-org` for autonomous staged delivery

## Stack

- Rust (stable via rust-overlay)
- Nix flake devShell

## Commands

- `cargo build` - build
- `cargo test` - test
- `cargo clippy -- -D warnings` - lint
- `cargo fmt --check` - check formatting
- `nix develop` - enter dev shell
- `nix run github:SPRAGE/dev-template#sync-skills` - pull latest shared skills, managed adapters, provider skill links, Codex config/custom agents, hooks, and AI context templates
- `nix run github:SPRAGE/dev-template#ai-doctor` - validate AI context files, shared skills, provider skill links, Codex config/custom agents, and hooks

## Conventions

- Error handling: `thiserror` for library errors, `anyhow` for binaries
- snake_case for functions, PascalCase for types
- Tests in `#[cfg(test)]` modules alongside the code

## Agent Workflow

- Start by inspecting the current tree and git status.
- Expected checks are usually `cargo fmt --check`, `cargo clippy -- -D warnings`, and `cargo test`; confirm the project has a `Cargo.toml` before relying on them.
- Keep tests close to the code with `#[cfg(test)]` modules unless the project already uses integration tests.
- Preserve the stable Rust toolchain and Nix devShell conventions unless the project needs otherwise.
- Update `.ai/context/active-context.md` when work spans sessions or changes project direction.

## Safety

- Treat `.env*`, key files, tokens, and credentials as sensitive.
- Do not overwrite local AI settings such as `.claude/settings.local.json`, `.agents/local/`, `.agents/tmp/`, `.codex/local/`, or `.codex/tmp/`.
- Do not run destructive git or filesystem operations unless the user explicitly asks.

## Shared AI Context & Skills

Provider-neutral context and skills live in `.ai/`. Read order, response style, rules, and the provider-adapter map are in `.ai/instructions.md`. Shared skills are in `.ai/skills/`; `.agents/skills/`, `.claude/skills/`, and `.codex/skills/` are symlinks to it — read `.ai/skills/<name>/SKILL.md` for a skill's source.
