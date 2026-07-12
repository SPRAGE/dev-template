# Codex Project Config

This directory contains Codex-facing runtime assets compiled from `.ai/`.

- `.codex/config.toml` defines trusted project-scoped Codex defaults.
- `.codex/agents/` contains generated custom agents. Model pins come from `.ai/capabilities/runtimes/codex.yaml`.
- `.codex/skills/` mirrors `.ai/skills/` for compatibility with agents and tools that look under `.codex/`.
- `.agents/skills/` is the official Codex repo-scoped skill link.
- `AGENTS.md` is the Codex-compatible auto-load adapter.
- `CODEX.md` is the named Codex adapter for humans and tools.
- `AI.md` and `.ai/` remain the shared source of truth.
- Edit neutral agent contracts under `.ai/agents/` and regenerate; do not edit generated TOML directly.

Local Codex runtime state should live under `.codex/local/`, `.codex/tmp/`, `.codex/sessions/`, or `.codex/logs/`, which are gitignored.
