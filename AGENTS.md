# dev-template Agent Guide

## Purpose

This repository builds Nix flake templates for AI-assisted development with provider-neutral context, Claude Code settings/skills, and Codex-compatible guidance.

## Source of Truth

- `.ai/` is the shared AI context for this repository.
- `template/.ai/` is the provider-neutral context seeded into generated projects.
- `template/` is the base template. Keep common AI assets here first.
- `templates/python/` and `templates/rust/` are language-specific templates. Keep shared files aligned with `template/` unless the stack needs different guidance.
- `template/.claude/skills/` is the source for skills. Root `*.skill` archives must match those directories.
- `tests/` protects app behavior, template sync, and skill archive freshness.

## Context

Before non-trivial work, read:

1. `.ai/instructions.md`
2. `.ai/context/active-context.md`
3. `.ai/context/architecture-snapshot.md`
4. `.ai/context/conventions.md`
5. `.ai/context/decisions.md`

## Commands

- `nix flake check --all-systems` - validate flake outputs.
- `nix develop -c bash tests/test-apps.sh` - smoke test flake apps.
- `nix develop -c bash tests/test-skills.sh` - validate skill sources and archives.
- `nix run .#ai-doctor` - inspect AI context files in the current project.

## Working Rules

- Preserve user-local files such as `.claude/settings.local.json`, `.env*`, `.codex/`, and `.agents/`.
- Keep shared project context in `.ai/`; keep provider-specific settings in provider-specific folders.
- If you change a skill source, regenerate its root `.skill` archive and run `tests/test-skills.sh`.
- If you change an app in `flake.nix`, add or update coverage in `tests/test-apps.sh` or `tests/test-onboard.sh`.
- Do not hardcode secrets, tokens, local absolute paths, or organization-private values into templates.
- Prefer exact, copy-paste-ready commands in docs and generated guidance.
