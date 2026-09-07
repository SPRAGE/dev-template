# Stale Log

## Log

- 2026-09-07: Removed the dormant twelve-skill catalog, activation CLI, archives, and unused root session-start hook. Retained agent-context, moved packaging/validation to maintainer tools, and corrected startup budgets to include discovery descriptions.
- 2026-09-07: Superseded the public-only Codex decision; `x86_64-linux` now uses the official release retained on the dataserver, with unstable nixpkgs retained as the ARM Linux and macOS fallback.
- 2026-07-22: Removed the private Codex input and its fallback description; Codex now comes from the public unstable nixpkgs pin.
- 2026-07-22: Replaced nine default skills with one default context skill. The reset workflow remains a tested CLI; planning/orchestration moved to methodology; private RAG assumptions were removed; three rewritten skills moved to the opt-in catalog.
- 2026-07-22: Replaced nine generated roles with scout, researcher, worker, and reviewer; planning, integration, routine tests, and documentation returned to the primary context.
- 2026-07-22: Removed placeholder context files from generated projects. Context files are created only when they contain repository evidence.
- 2026-07-22: Added a dormant twelve-skill catalog for domain-to-delivery work plus a safe activation tool; default discovery remains `agent-context` only.

## 2026-09-07 — V3 minimal project layout

Superseded the one-default-skill/four-role design with zero default profiles, inherited runtime models, ten project files, and maintainer-owned lifecycle tools. Current authoring paths and checks are in AI.md. V2 documents and compiler contracts remain only under compat/v2 for explicit legacy migration; earlier audit files describe historical states.
