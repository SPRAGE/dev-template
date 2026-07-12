---
name: cc-refresh
description: Audit and refresh shared agent guidance, context, skills, generated runtime assets, and stale memory. Use for context cleanup, guidance quality, stale instructions, or agent workflow optimization; supports dry-run and sync-only requests.
---

# Agent Context Refresh

Keep every loaded token accurate, actionable, and in the cheapest correct layer.

## Modes

- **Full:** sync managed assets, audit, update, compile, and verify.
- **Dry run:** audit and report only.
- **Guidance only:** inspect `AI.md`, `.ai/`, and runtime adapters only.
- **Sync only:** run the managed sync app and stop.

## Audit

Inspect in parallel where supported:

1. **Guidance:** commands, architecture, conventions, adapters, duplication, and token budgets.
2. **Context:** stale active work, invalid decisions, outdated paths, and facts stored as procedures.
3. **Runtime:** neutral capability and role contracts, generated runtime assets, model tiers, provider-native bindings, MCP scope, and local overrides.
4. **Memory/rules:** stale references, duplicated linter behavior, oversized session history, and private state that must remain untouched.

Score guidance using `references/quality-criteria.md`. Findings must include severity, evidence, and a specific action. Load `references/update-guidelines.md` before relocating or pruning durable content.

## Update Rules

- Project facts belong in `AI.md` or `.ai/context/`.
- Durable execution behavior belongs in `.ai/policy.yaml`; compile its readable instruction and methodology views.
- Reusable procedures belong in skills; provider mechanics belong in runtime bindings.
- Delete placeholder rolling context rather than loading it forever.
- Preserve customized guidance, local settings, secrets, runtime state, and unrelated changes.
- Log pruned durable content to `.ai/context/stale-log.md` before removal.

A direct request to refresh or improve configuration authorizes scoped, non-destructive updates. Ask again only for destructive deletion, permission changes, or ambiguous changes with material impact.

## Execute

1. Apply evidence-backed updates.
2. Run `.ai/generators/compile.py` when the neutral spec changed.
3. Run the repository’s agent-system, template-sync, skill/archive, and app tests.
4. Report changes, token-budget effects, proof, and remaining risks.
