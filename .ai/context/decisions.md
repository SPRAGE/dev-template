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
- **Status:** superseded by Zero Default Workflows And Maintainer-Owned Tooling
- **Decision:** Generated projects include `AI.md` as the shared top-level guide. `AGENTS.md` remains as the Codex auto-load compatibility adapter, `CODEX.md` is a named Codex adapter alias, and `CLAUDE.md` remains as a small Claude Code compatibility adapter because Claude Code auto-loads that filename.
- **Why:** Human and agent-facing project guidance should not be branded to one provider, but Claude Code compatibility still matters for seamless use.
- **Alternatives considered:** Fully remove `CLAUDE.md`; keep all top-level guidance only in `.ai/instructions.md`.

## Shared Skill Catalog Links
- **Date:** 2026-05-07
- **Status:** superseded by Zero Default Workflows And Maintainer-Owned Tooling
- **Decision:** Shared skill sources live under `template/.ai/skills/`; Codex receives the official repo-scoped path under `template/.agents/skills/`; Claude Code receives the slash-command path under `template/.claude/skills/`; `.codex/skills/` remains a compatibility path. Provider skill paths are relative symlinks to `.ai/skills/`.
- **Why:** Codex officially scans `.agents/skills/` for repository skills, while Claude Code still needs `.claude/skills/` for slash-command ergonomics and `.ai/skills/` keeps the provider-neutral source intact. Symlinks remove duplicated skill trees and are preserved by `nix flake init`.
- **Alternatives considered:** Keep skills only under `.claude/skills/`; use only `.codex/skills/` for Codex; physically duplicate provider skill directories.

## Codex Project Config
- **Date:** 2026-05-08
- **Status:** superseded by Zero Default Workflows And Maintainer-Owned Tooling
- **Decision:** Generated projects include `.codex/config.toml` and `.codex/agents/*.toml` for trusted Codex project defaults and reusable custom subagents.
- **Why:** Codex supports project-scoped config after trust and custom agents under `.codex/agents/`, so templates can provide a consistent multi-agent baseline without making provider-neutral `.ai/` carry Codex-specific settings.
- **Alternatives considered:** Keep Codex config entirely user-global; document custom agents without seeding them.

## Compiled Agent Specification And Tiered Execution
- **Date:** 2026-07-12
- **Status:** superseded by Lean Runtime Contracts And Explicit Skill Discovery
- **Decision:** `.ai/` is a validated source specification. Provider adapters and agents are generated from neutral policy, capability, and agent contracts. Coordinated or high-risk work is planned on the deep tier, bounded implementation and routine review run on the balanced tier, and read-heavy/support work runs on the fast tier.
- **Why:** Minimal prompts should trigger deep analysis while execution cost scales with task complexity; generated views and CI budgets prevent provider drift and context bloat.
- **Alternatives considered:** Keep handwritten provider agents; run every subagent on the parent model; encode orchestration only in an optional skill.

## Conditional Context And Tools
- **Date:** 2026-07-12
- **Status:** active
- **Decision:** Do not seed placeholder active context, global MCP servers, or optional Claude plugins. Load architecture, conventions, decisions, skills, references, and external tools only when the task needs them.
- **Why:** Empty context and global tool schemas impose recurring token cost without improving most tasks.
- **Alternatives considered:** Session-start decision injection; Context7 in every session; always-loaded full project context.

## Dataserver Codex Release With Portable Fallback
- **Date:** 2026-09-07
- **Status:** active
- **Decision:** Use the prebuilt official `codex-release` retained on the dataserver for `x86_64-linux`. Fall back to `pkgs.codex` from locked unstable nixpkgs on `aarch64-linux` and `aarch64-darwin`.
- **Why:** Development shells on the primary Linux architecture should share the retained Codex release without rebuilding upstream Rust, while the other advertised systems must continue to evaluate.
- **Alternatives considered:** Use unstable nixpkgs everywhere; expose only `x86_64-linux`; require the dataserver release to publish packages for every system.

## Lean Runtime Contracts And Explicit Skill Discovery
- **Date:** 2026-07-22
- **Status:** superseded by Minimal Skill Surface And Complete Startup Budgets
- **Decision:** Keep planning and integration in the primary context; expose only scout, researcher, worker, and reviewer roles. Discover one default `agent-context` skill and keep domain/maintainer skills in an opt-in catalog.
- **Why:** Nine roles and nine default skill descriptions repeated policy, created trigger conflicts, and added context without behavioral evidence. Four roles preserve meaningful isolation while route-level budgets make the static cost visible.
- **Alternatives considered:** Preserve all specialist roles; remove custom roles entirely; keep all skills discoverable with lower entry budgets.

## Explicit Runtime Schema Migration
- **Date:** 2026-07-22
- **Status:** superseded by Zero Default Workflows And Maintainer-Owned Tooling
- **Decision:** Runtime schema version 2 is validated. Sync never upgrades an existing compiler and compiles only schema-v2 projects in preserve-existing mode; older projects require an explicit migration.
- **Why:** Updating the compiler while retaining older strict-schema inputs could break refresh, and normal compilation overwrote provider files that lifecycle messages claimed to preserve.
- **Alternatives considered:** Treat every marker-bearing file as replaceable; silently rewrite all managed neutral sources during sync.

## Autonomous Domain Grounding And Conditional Specialists
- **Date:** 2026-07-22
- **Status:** superseded by Minimal Skill Surface And Complete Startup Budgets
- **Decision:** Planned and Hard work begins with a minimal evidence-backed domain brief. A compact catalog routes at most two specialist procedures per task; only recurring procedures are activated into provider discovery through a collision-safe relative link.
- **Why:** Domain, knowledge, visualization, performance, migration, and testing guidance can materially improve complex delivery, but loading all of it in every session would waste context and create trigger conflicts.
- **Alternatives considered:** Discover all specialist skills by default; keep only generic methodology; restore a large virtual organization skill.

## Minimal Skill Surface And Complete Startup Budgets
- **Date:** 2026-09-07
- **Status:** superseded by Zero Default Workflows And Maintainer-Owned Tooling
- **Decision:** Ship one concise maintenance skill, remove twelve generic or maintainer catalog skills and their activation CLI, and retain deterministic utilities under `tools/`. Keep project facts and conditional execution rules short. Count role and skill descriptions in startup budgets.
- **Why:** The catalog duplicated general engineering knowledge without comparative outcome evidence; routing and starter boilerplate imposed measurable context overhead. Existing catalogs and tools remain project-owned during sync and migration.

## Zero Default Workflows And Maintainer-Owned Tooling
- **Date:** 2026-09-07
- **Status:** active
- **Decision:** V3 generated projects contain ten files, no default skills/roles/model pins, and no compiler or capability schema. Keep concise shared guidance, three language overlays, optional agent-context/frontend-design/roles, and concrete runbook templates. File fingerprints govern safe sync; upgrades are explicit and recoverable. Frozen v2 sources support legacy migration.
- **Why:** Current models need project facts and concrete procedures, while generic process and model-tier ceremony add context and maintenance. Optional workflows must earn their place through project evidence. Preserve all pre-existing Codex packaging and downstream customization boundaries.

## Portable Autonomous Delegation Policy
- **Date:** 2026-09-07
- **Status:** active
- **Decision:** All generated provider guides direct the primary to delegate suitable bounded implementation in parallel, prefer available models explicitly identified as cheaper, and retain architecture, integration, and final review. Model IDs stay runtime-owned; native capabilities and permissions govern execution, with unavailable delegation or cost information reported.
- **Why:** The user will use this template across downstream projects, so delegation behavior must travel in the shared guidance instead of relying on this session's tools. The policy keeps the ten-file, zero-default-skill/role layout.
