# Delivery Method

<!-- Generated from .ai/ by .ai/generators/compile.py. Do not edit directly. -->

Use the smallest route that can produce evidence without losing the user's intent.

## Routes

- **Direct:** bounded scope, reversible, low risk, and no unresolved dependency. The primary agent executes and runs a focused check; no formal plan or independent review is required.
- **Planned:** any of dependent steps, architecture choice, material ambiguity, or cross boundary coordination. The deep tier creates one implementation-ready plan, the balanced tier executes bounded code steps, and the balanced tier performs routine independent review.
- **Hard:** any of security sensitive, destructive, regulated, data migration, broadly ambiguous, or high consequence. The deep tier owns planning and the deep tier performs independent risk review. Use staged gates when a later action is destructive or external.

File count alone does not select Planned. Prefer Direct for mechanical, reversible changes whose dependencies and success criteria are already clear.

## Plan Contract

The planner stays in the planning layer. It returns the objective, task mode, material assumptions, success criteria, preserved invariants, dependency-ordered steps with file ownership, risks, required verification, and stop conditions. A small prompt should be expanded from repository evidence, not from invented requirements.

Reuse the accepted plan. Update only the affected steps when evidence changes; do not make workers rediscover the repository or silently move from explanation/planning into implementation.

## Handoff Contract

Every worker handoff supplies `objective`, `task_mode`, `current_layer`, `plan_step`, `repository_facts`, `file_scope`, `success_criteria`, `preserved_invariants`, `required_evidence`, `stop_conditions`. If repository evidence cannot safely fill a missing item, return blocked. Stop on scope conflict, missing dependency, unsafe action, or contradicted assumption; never redesign silently or expand the approved scope.

Route exploration and primary-source research to the fast/fast tiers, bounded implementation and integration to the balanced/balanced tiers, tests and documentation to the fast/fast tiers, routine review to the balanced tier, and high-consequence review to the deep tier. Expose network and MCP tools only to the research role that needs them.

## Integrate And Prove

Use an integrator only for multiple worker results, conflicts, or material integration risk. Re-read the current diff, reconcile results against success criteria and preserved invariants, run risk-appropriate checks, and request the routed independent review. Return distilled evidence rather than raw logs.
