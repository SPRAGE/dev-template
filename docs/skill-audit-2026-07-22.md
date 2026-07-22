# Skill Audit — 2026-07-22

## Standard

A default skill should provide recurring, judgment-heavy behavior that ordinary repository guidance, the delivery methodology, or a deterministic script cannot provide more cheaply. It also needs precise positive and negative triggers, progressive disclosure, provider-neutral language, bounded permissions, and evidence that it changes outcomes—not just a large instruction body.

The previous catalog had structural tests but no representative with/without-skill behavioral evaluation. Its nine discovery descriptions cost 380 static estimated tokens per session before any skill body was loaded; the new single default description estimates at 52. The verdicts below are therefore based on overlap, safety, portability, and static cost; performance claims remain provisional.

## Previous Default Skills

| Skill | Verdict | Honest assessment | Disposition |
|---|---|---|---|
| `cc-refresh` | Useful, but overlapping | Evidence-based context auditing is valuable; refresh mechanics and quality criteria overlapped `cc-setup`. | Merged into the default `agent-context` skill. |
| `cc-setup` | Useful, but overlapping | Repository onboarding, command discovery, and context routing are valuable; its connector catalog and role templates were too broad for default loading. | Merged into `agent-context`; connector guidance is conditional. |
| `fresh-start` | Not a skill | Resetting files is deterministic lifecycle behavior. A prose skill adds ambiguity to a destructive operation. | Removed from discovery; retained as the confirmed, tested `fresh-start` Nix app. |
| `frontend-design` | Useful for frontend projects | Domain judgment can improve hierarchy and interaction quality, but it should honor an existing design system and verify accessibility/performance instead of enforcing stylistic novelty. | Rewritten as an opt-in skill. |
| `knowledge-base` | Not reusable in this template | It encoded one private stack and exact infrastructure assumptions. That is deployment configuration, not a provider-neutral general procedure. | Removed; projects should add a local skill or connector contract for their actual knowledge system. |
| `planner` | Redundant | Planning is route-level behavior for any complex task. Making it a skill duplicates core methodology and risks conflicting triggers. | Merged into `.ai/methodology.md`. |
| `playground` | Occasionally useful | A self-contained interactive decision tool is valuable when the artifact itself is requested. The previous breadth encouraged unnecessary playgrounds and included unsafe HTML patterns. | Narrowed and rewritten as opt-in `interactive-playground` with offline, safe-DOM, keyboard, and accessibility requirements. |
| `skill-creator` | Useful only to maintainers | Skill design and packaging are specialized, but the previous package was about 196 KB, included provider-specific live evaluation machinery, and mixed deterministic packaging with model orchestration. | Rewritten as opt-in `skill-authoring` with a small deterministic validator and packager. |
| `virtual-tech-org` | Harmful as a default | It duplicated planning, implementation, review, documentation, and integration policy while adding theatrical roles and ceremony. It could make a small task slower without evidence of better outcomes. | Removed; bounded delegation now lives in methodology and four runtime roles. |

## Current Catalog

`agent-context` is the only default because accurate repository guidance benefits nearly every long-lived project. The twelve specialist skills remain dormant under `.ai/catalog/`; a Planned or Hard task can select at most two, and only recurring procedures are activated into provider discovery.

| Skill | Honest utility | Keep conditional because |
|---|---|---|
| `domain-modeling` | High for unfamiliar or rule-heavy products. It prevents architecture from being built on assumed workflows or vocabulary. | Familiar, already-evidenced domains do not need a separate modeling pass. |
| `knowledge-integration` | High when a knowledge base, document corpus, or retrieval layer materially informs decisions. It adds provenance, freshness, permission, and retrieval-quality discipline. | Repository search or supplied context is cheaper for ordinary coding questions; infrastructure bindings must stay project-local. |
| `api-contracts` | High for public or cross-service boundaries, especially retries, compatibility, pagination, and failure semantics. | Internal settled function changes rarely merit a full contract exercise. |
| `performance-engineering` | High whenever latency or resource use is an acceptance criterion. It prevents speculative optimization and requires comparable evidence. | It adds measurement work and should not trigger for vague “make it cleaner” requests. |
| `data-visualization` | High for analytical dashboards because data semantics, uncertainty, accessibility, and streaming behavior are easy to get subtly wrong. | General page styling is covered more cheaply by normal frontend work. |
| `frontend-design` | Useful for production-facing interaction and visual hierarchy while honoring an existing design system. | Mechanical UI changes and design-system-prescribed components need little additional judgment. |
| `migration-safety` | High for schema, data, protocol, and configuration transitions with mixed versions or irreversible stages. | Disposable local state and compatibility-free changes do not need rollout ceremony. |
| `incident-debugging` | High for intermittent or production failures where timelines, telemetry, mitigation, and competing hypotheses matter. | Deterministic local defects with an obvious reproduction need a simpler debug loop. |
| `test-design` | Medium to high for risky multi-boundary changes; it maps failures to the cheapest reliable layer and exposes untested risk. | It would be redundant for one focused regression test or a mature existing test plan. |
| `agent-evaluation` | Essential for maintainers making claims about prompts, roles, tools, or skills; it demands paired trials and blinded or deterministic grading. | Product implementation should use normal acceptance tests, not meta-evaluation machinery. |
| `interactive-playground` | Valuable when the requested artifact is itself a standalone exploratory or decision tool. | It is a poor detour when the user asked for the production feature directly. |
| `skill-authoring` | Useful for maintainers who need precise triggers, progressive disclosure, validation, and deterministic archives. | Ordinary product work should follow existing guidance, not create a new skill. |

Each skill has an explicit package allowlist, entry and total token budgets, at least five positive and five negative trigger cases, and provider/infrastructure-neutral entry text. Archives are deterministic. The catalog index itself is capped at 700 static estimated tokens. These checks improve maintainability and trigger hygiene; none of the new skills has yet earned a claim of better outcomes without the representative evaluation below.

## Recommended Evaluation

Build a small blinded task set for each retained skill. Compare outcomes with and without the skill using the same model and repository state. Grade task success, unnecessary actions, clarification count, tokens, latency, and regressions. Keep a default skill only when the outcome gain is repeatable and exceeds its discovery and maintenance cost.
