---
name: virtual-tech-org
description: Autonomously deliver a non-trivial product or feature from a small prompt. Use for “build it,” “ship it,” or requests for a team-style end-to-end implementation; use planner for planning-only work.
---

# Autonomous Delivery

Infer intent, scope, stack, domain, risk, and proof from the prompt and repository. Ask at most one batched question, only when the answer changes a material or high-risk outcome.

## Depth

- **Tiny:** defer to the normal direct workflow.
- **Standard:** compact brief, deep plan, bounded implementation, tests, and review.
- **Hard:** add explicit architecture, domain/security risks, staged integration, and broader proof.

Escalate depth for auth, payments, secrets, PII/PHI, destructive migrations, production deployment, multiple services, or regulated domains.

## Loop

1. **Infer:** inspect relevant project facts and settle reversible assumptions.
2. **Brief:** state the outcome, 3-5 requirements, non-goals, acceptance criteria, and top risks.
3. **Plan:** dispatch `plan` to the deep tier. Reject a plan without dependencies, file scopes, verification, or worker-ready steps.
4. **Build:** dispatch ready capabilities from `.ai/capabilities/map.md`. Use fast workers for `explore`, `research`, `test`, and `document`; balanced workers for bounded `implement`; deep agents for `integrate` and reviews.
5. **Prove:** integrate against the current diff, run checks, request code/security review as risk requires, and report evidence.

Keep the main context focused on requirements, decisions, plan state, and integrated results. Workers receive only the relevant step, facts, constraints, acceptance criteria, and output contract. Do not create fictional roles or process narration.

For a real-world regulated domain, apply `references/domain-checks.md`. Domain review flags assumptions and required expert review; it never certifies compliance.

## State

Record durable decisions in `.ai/context/decisions.md`. Create `.ai/context/active-context.md` only for genuine cross-session work and remove it when the work is closed.

## Completion

Return:

```text
Changed: <behavior and files>
Proof:   <commands and pass/fail>
Risks:   <remaining risks or none>
```
