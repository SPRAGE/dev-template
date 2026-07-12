# Shared Guidance Update Guidelines

## Core Principle

Only add verified information that changes a future agent's decisions. Every always-loaded line must earn its context cost.

## Choose The Cheapest Correct Layer

| Content | Owner |
|---|---|
| Project purpose, exact commands, architecture map, non-obvious facts | `AI.md` |
| Durable cross-task execution policy | `.ai/instructions.md` or `.ai/methodology.md` |
| Architecture detail, conventions, decisions, real active work | `.ai/context/` |
| Reusable on-demand procedure | `.ai/skills/` |
| Neutral capability, tier, or role contract | `.ai/capabilities/` or `.ai/agents/` |
| Native tools, permissions, model aliases, and local preferences | Generated or local runtime settings |

## Keep Or Prune

Keep verified commands, recurring gotchas, package relationships, working test patterns, configuration constraints, durable decisions, and architecture facts that are expensive to rediscover.

Prune or relocate:

- facts obvious from names or a nearby manifest;
- generic engineering advice;
- one-off fixes and narrative session history;
- examples that restate an instruction;
- stale active work and abandoned TODOs;
- repeated policy in generated adapters;
- secrets, personal preferences, and runtime state.

Prefer one dense statement over background explanation. For example: `API tests use factories from tests/factories/; inline mocks miss shared defaults.`

## Change Contract

For each suggested change, identify the owner file and section, show the concise diff, cite repository evidence, and state the decision or repeated discovery it improves. If content moves, remove the old copy in the same change. Log pruned durable information in the stale log before deletion.

## Validation Checklist

Before finalizing an update, verify:

- [ ] Each addition is project-specific
- [ ] No generic advice or obvious info
- [ ] Commands are tested and work
- [ ] File paths are accurate
- [ ] Does this change a future agent's decision or save repeated discovery?
- [ ] Is this the most concise way to express the info?
- [ ] Is it in the authoritative layer rather than duplicated in an adapter?
- [ ] Were neutral changes compiled and generated outputs checked?
