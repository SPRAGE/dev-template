# Decisions

<!-- Add decisions that are still in effect below.

Entry format:

## [Decision Title]
- **Date:** YYYY-MM-DD
- **Status:** active | superseded by [other decision]
- **Decision:** [What was decided]
- **Why:** [Reasoning]
- **Alternatives considered:** [What else was on the table]
-->

## Provider-Neutral AI Context
- **Date:** 2026-05-07
- **Status:** active
- **Decision:** Shared AI instructions and project context live under `.ai/`; provider-specific entry points and settings remain in `AGENTS.md`, `CLAUDE.md`, `.claude/`, or other provider folders.
- **Why:** Codex and Claude Code should load the same base context without treating Claude Code's runtime folder as the shared source of truth.
- **Alternatives considered:** Keep `.claude/knowledge` as shared context; rename `.claude` entirely.
