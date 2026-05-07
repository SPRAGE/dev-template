# Agent Guide

## Context

Read these provider-neutral files before non-trivial work:

1. `.ai/instructions.md`
2. `.ai/context/active-context.md`
3. `.ai/context/architecture-snapshot.md`
4. `.ai/context/conventions.md`
5. `.ai/context/decisions.md`

## Rust Workflow

- Expected checks are usually `cargo fmt --check`, `cargo clippy -- -D warnings`, and `cargo test`; confirm the project has a `Cargo.toml` before relying on them.
- Keep tests close to the code with `#[cfg(test)]` modules unless the project already uses integration tests.
- Preserve the stable Rust toolchain and Nix devShell conventions unless the project needs otherwise.

## Safety

- Treat `.env*`, key files, tokens, and credentials as sensitive.
- Do not overwrite local AI settings such as `.claude/settings.local.json`, `.codex/`, or `.agents/`.
- Do not run destructive git or filesystem operations unless the user explicitly asks.
