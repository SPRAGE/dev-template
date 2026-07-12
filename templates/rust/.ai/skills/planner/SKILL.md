---
name: planner
description: Produce an implementation-ready project or feature plan without writing code. Use for planning, scoping, architecture, requirements, milestones, or “help me think this through.”
---

# Planner

Turn the smallest useful prompt plus available repository evidence into a decision-ready plan. Default to inference-first planning; use an interview only when the user explicitly asks to brainstorm interactively.

## Intake

1. Detect **Project** mode for a new system and **Feature** mode for an existing system.
2. Read the relevant project facts and inspect existing code before asking about anything discoverable.
3. Infer reversible preferences from conventions and current architecture.
4. Ask at most one batched question when unresolved answers materially change scope, architecture, risk, or cost. Offer a recommended default.

## Required Plan

Produce:

- problem and target users;
- goals, non-goals, and measurable acceptance criteria;
- current-state evidence for existing repositories;
- proposed architecture and data flow;
- dependency-ordered steps with IDs, file/module scope, and owner capability;
- tests and validation for each behavioral step;
- migration, rollout, security, and operational concerns when relevant;
- assumptions, decisions, risks, and deferred work.

Every implementation step must be executable by a worker that receives only that step, its dependencies, relevant context, file scope, and acceptance criteria. Separate independent steps so they can run in parallel; mark integration gates explicitly.

## Output

Write the plan to `docs/plans/YYYY-MM-DD-<topic>.md` when the user asks for a durable artifact or when implementation will span sessions. Otherwise return it in the conversation. Do not implement unless the user also requested delivery; in that case hand the completed plan to the normal execution workflow or `virtual-tech-org`.
