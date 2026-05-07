# AI Instructions

## Project

PROJECTNAME - TODO: replace with one-line description.

## Read Order

1. `.ai/instructions.md`
2. `.ai/context/active-context.md`
3. `.ai/context/architecture-snapshot.md`
4. `.ai/context/conventions.md`
5. `.ai/context/decisions.md`

## Provider Adapters

- `AGENTS.md` is the Codex-compatible entry point.
- `CLAUDE.md` is the Claude Code entry point.
- `.claude/` contains Claude Code settings, hooks, and skills.

## Rust Commands

- `cargo build` - build.
- `cargo test` - test.
- `cargo clippy -- -D warnings` - lint.
- `cargo fmt --check` - check formatting.
- `nix develop` - enter dev shell.
- `nix run github:SPRAGE/dev-template#ai-doctor` - validate AI context files and provider-specific settings layout.

## Rules

- Treat `.ai/context/` as the shared project context source of truth.
- Keep tests close to code with `#[cfg(test)]` modules unless the project already uses integration tests.
- Preserve the stable Rust toolchain and Nix devShell conventions unless the project needs otherwise.
- Keep provider-specific runtime settings out of `.ai/`.
