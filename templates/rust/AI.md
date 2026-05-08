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

## Shared AI Context

Project context is tracked in `.ai/` so Claude Code, Codex, and future agents read the same base files:

- `instructions.md` - provider-neutral project instructions
- `active-context.md` - current work and next steps
- `architecture-snapshot.md` - stack, structure, and runtime map
- `conventions.md` - coding, testing, and review conventions
- `decisions.md` - active architectural decisions
- `stale-log.md` - audit trail for removed or superseded context

## Shared Skills

Shared skill sources live in `.ai/skills/`. Codex discovers repo-scoped skills from `.agents/skills/`; Claude Code uses `.claude/skills/` for slash commands; `.codex/skills/` remains a compatibility path. These provider paths are relative symlinks to `.ai/skills/`, so additions through any provider path update the same shared catalog. Agents should read `.ai/skills/<skill-name>/SKILL.md` when a provider-neutral source is needed.

## Provider Adapters

`AI.md` is the shared top-level guide. `AGENTS.md` is the Codex-compatible auto-load adapter. `CODEX.md` is a named Codex adapter alias. `CLAUDE.md` is the Claude Code compatibility adapter. Provider-specific settings remain in provider-specific folders such as `.agents/`, `.claude/`, and `.codex/`.
