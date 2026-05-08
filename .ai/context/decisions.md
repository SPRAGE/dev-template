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
- **Decision:** Shared AI instructions and project context live in `AI.md` and under `.ai/`; provider-specific entry points and settings remain in `AGENTS.md`, `CODEX.md`, `CLAUDE.md`, `.claude/`, or other provider folders.
- **Why:** Codex and Claude Code should load the same base context without treating Claude Code's runtime folder as the shared source of truth.
- **Alternatives considered:** Keep `.claude/knowledge` as shared context; rename `.claude` entirely.

## Provider-Agnostic Top-Level Guide
- **Date:** 2026-05-07
- **Status:** active
- **Decision:** Generated projects include `AI.md` as the shared top-level guide. `AGENTS.md` remains as the Codex auto-load compatibility adapter, `CODEX.md` is a named Codex adapter alias, and `CLAUDE.md` remains as a small Claude Code compatibility adapter because Claude Code auto-loads that filename.
- **Why:** Human and agent-facing project guidance should not be branded to one provider, but Claude Code compatibility still matters for seamless use.
- **Alternatives considered:** Fully remove `CLAUDE.md`; keep all top-level guidance only in `.ai/instructions.md`.

## Shared Skill Catalog Links
- **Date:** 2026-05-07
- **Status:** active
- **Decision:** Shared skill sources live under `template/.ai/skills/`; Codex receives the official repo-scoped path under `template/.agents/skills/`; Claude Code receives the slash-command path under `template/.claude/skills/`; `.codex/skills/` remains a compatibility path. Provider skill paths are relative symlinks to `.ai/skills/`.
- **Why:** Codex officially scans `.agents/skills/` for repository skills, while Claude Code still needs `.claude/skills/` for slash-command ergonomics and `.ai/skills/` keeps the provider-neutral source intact. Symlinks remove duplicated skill trees and are preserved by `nix flake init`.
- **Alternatives considered:** Keep skills only under `.claude/skills/`; use only `.codex/skills/` for Codex; physically duplicate provider skill directories.

## Codex Project Config
- **Date:** 2026-05-08
- **Status:** active
- **Decision:** Generated projects include `.codex/config.toml` and `.codex/agents/*.toml` for trusted Codex project defaults and reusable custom subagents.
- **Why:** Codex supports project-scoped config after trust and custom agents under `.codex/agents/`, so templates can provide a consistent multi-agent baseline without making provider-neutral `.ai/` carry Codex-specific settings.
- **Alternatives considered:** Keep Codex config entirely user-global; document custom agents without seeding them.
