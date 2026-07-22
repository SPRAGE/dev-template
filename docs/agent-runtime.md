# Agent Runtime Architecture

## Objective

Preserve user intent and integration state in one primary context while loading specialized instructions, project facts, roles, and tools only when they improve the task.

## Layers

- `AI.md` contains frequent project facts and exact commands.
- `.ai/instructions.md` is the compact, always-relevant safety and delivery contract.
- `.ai/methodology.md` loads only for Planned or Hard work.
- `.ai/context/` contains evidence-backed architecture, conventions, decisions, or active work only when those files are useful.
- `.ai/skills/` contains recurring judgment-heavy procedures; provider paths are discovery links.
- `.ai/catalog/` contains dormant provider-neutral specialist procedures and a compact routing index.
- `.ai/tools/skillctl.py` activates recurring catalog procedures without replacing project-owned skills.
- `.ai/policy.yaml`, capabilities, agents, and evals are versioned neutral source specifications.
- `AGENTS.md`, `CODEX.md`, `CLAUDE.md`, `.codex/`, and `.claude/` are generated or provider-native views.

## Routing

Intent sets the authorization boundary before complexity selects a route. Explain, review, diagnose, and plan requests inspect and report. Build, change, and fix requests permit scoped local edits and non-destructive checks. Destructive actions, external mutations, privilege expansion, purchases, deployments, and material scope expansion require confirmation.

- **Direct:** bounded, reversible, low-risk work; the primary executes and runs focused verification.
- **Planned:** coupled or materially ambiguous work; the primary creates one inference-first plan, delegates only ready independent steps, and integrates the current diff.
- **Hard:** security-sensitive, destructive, regulated, or otherwise high-consequence work; the plan includes stop/rollback gates and receives independent deep review.

File count alone does not make work Planned.

## Autonomous Domain-To-Delivery Loop

For consequential work, the primary assembles the smallest evidenced domain brief: actors, goals, terms, workflows, invariants, boundaries, sources, and material unknowns. Repository facts and configured knowledge sources come first; current external research is isolated and returned as citations, freshness, and uncertainty rather than bulk context.

Planned and Hard routes consult the 699-token catalog index only when specialist guidance is material and load no more than two skill bodies. A procedure is activated into runtime discovery only when it will recur. The primary then owns the dependency-ordered plan, continues through safe reversible steps, integrates the live diff, runs risk-appropriate proof, and promotes only verified recurring facts into project context. It stops for missing knowledge only when the answer could change scope, architecture, safety, or acceptance.

## Roles

The primary owns planning, integration, routine testing, documentation, and final delivery. The runtime exposes four bounded helpers:

| Role | Contract |
|---|---|
| `scout` | Find targeted repository evidence without edits. |
| `researcher` | Verify version-sensitive claims against current primary sources. |
| `worker` | Implement one settled, disjoint scope and return proof. |
| `reviewer` | Independently identify correctness, security, regression, and verification risks. |

Every handoff contains an objective, file scope, success criteria, preserved invariants, and required evidence. Workers stop on contradictions, missing dependencies, unsafe actions, or scope conflict. The primary re-reads and integrates the current repository state; reports never substitute for that check.

Codex fast/balanced/deep role tiers map to Luna/Terra/Sol with low/medium/high role effort. Claude maps them to Haiku/Sonnet/Opus. The main model is inherited from the active runtime instead of being pinned by the project. External tools are limited to the role that needs them, and delegation depth is one.

## Compilation And Migration

The compiler validates schema version 2, exact fields, provider-neutral core files, profile parity, permission expansion, role routing, the conditional catalog, activated skill ownership, package allowlists, deterministic scenarios, and context budgets. It emits provider adapters and role files from neutral source.

Normal maintainer generation updates marked outputs. Lifecycle sync is conservative: missing generated outputs come from the target project's compiler, while existing compilers, specs, adapters, configuration, and roles are preserved. This big-bang release intentionally has no automatic v1-to-v2 transformer; older projects require a reviewed manual reconciliation or a confirmed `fresh-start`.

## Evidence

Deterministic tests prove routing, authorization, completion contracts, provider parity, source mirroring, archive reproducibility, lifecycle preservation, and Nix evaluation. Static token estimates prove only context-size reductions. Live representative tasks with blinded outcome grading are needed to claim better reasoning or delivery quality.

Using the compiler's byte/word estimator against the generated base template before and after this rewrite:

| Static surface | Before | After | Reduction |
|---|---:|---:|---:|
| Always-loaded route | 1,215 | 910 | 25% |
| Planned route including role catalog | 2,531 | 1,704 | 33% |
| Role discovery catalog | 635 | 165 | 74% |
| Skill discovery descriptions | 380 | 52 | 86% |
| Runtime roles | 9 | 4 | 56% |
| Individual generated role contract | 401–529 | 278–360 | 31–32% by range endpoint |
| Conditional specialist index | none | 699 | loaded only when specialist routing is material |

These are comparable static estimates from committed before/after files, not API billing tokens.

## Change Workflow

1. Edit `template/.ai/` or one documented language overlay.
2. Compile the base runtime.
3. Sync the language mirrors and compile them.
4. Repackage changed default or optional skills.
5. Run agent, mirror, skill, lifecycle, and all-system flake checks.
