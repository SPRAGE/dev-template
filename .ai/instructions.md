# Agent Instructions

<!-- Generated from .ai/ by .ai/generators/compile.py. Do not edit directly. -->

## Context Routing

- Always read `AI.md`, `.ai/instructions.md`.
- Read `.ai/context/architecture-snapshot.md` before architectural or cross-boundary work and `.ai/context/conventions.md` before edits or review.
- Read `.ai/context/decisions.md` only when the task touches a recorded choice; read `.ai/context/active-context.md` only when it exists and contains current work.
- Load a skill body only when its description matches the task or the user names it.

## Authorization

- For explain, review, diagnose, or plan requests, inspect and report only. Do not edit or advance into implementation unless asked.
- For change, build, or fix requests, make in-scope local changes and run non-destructive validation without repeated confirmation.
- Confirm immediately before destructive action, external write, purchase, permission expansion, or material scope expansion. Ask a question only when repository evidence cannot resolve a material choice, irreversible choice, or high risk choice.

## Repository Boundary

- Limit repository search, file reads, and version-control inspection to the current Git root.
- Inspect another repository only when the user explicitly names its path or explicitly authorizes cross-repository work. Limit access to the named or authorized repositories.
- If requested code is absent, report that it is outside the current repository boundary and request a path or authorization. Do not discover or search sibling directories.

## Delivery

1. Inspect the working state, relevant code, documented commands, and generated/source boundaries.
2. Execute a bounded, reversible, low-risk task directly with focused verification, even when the mechanical edit spans files.
3. Read `.ai/methodology.md` and use one deep plan when work involves dependent steps, architecture choice, material ambiguity, or cross boundary coordination.
4. Use the Hard route when work involves security sensitive, destructive, regulated, data migration, broadly ambiguous, or high consequence. Require deep planning, staged evidence, and independent deep risk review.
5. Reuse and update the accepted plan; do not restart discovery or silently change layers. Delegate only ready, bounded steps and parallelize only independent work.

## Preservation

Treat user-stated values and existing in-scope behavior as acceptance criteria. Preserve user provided values, unrelated changes, local runtime state, existing behavior not in scope, and routes schemas and outputs not in scope. Never remove behavior to make checks pass, weaken tests to hide a regression, or silently expand scope.

## Completion

Use lifecycle status complete, partial, or blocked. Complete requires evidence; partial requires blockers and next action; blocked requires blockers, stop reason, and next action. Report the outcome, evidence, material caveat, and next action. Never claim completion without evidence or an explicit verification limitation.
