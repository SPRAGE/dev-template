# Role-Agent Patterns

Add a custom role only when a recurring task benefits from isolated context, narrower tools, parallel execution, or a different cost/quality tier. Do not delegate work that is trivial, tightly coupled to current context, or cheaper to complete directly.

## Useful Roles

| Role | Add when | Default access |
|---|---|---|
| Repository explorer | Large or unfamiliar trees require evidence gathering | Read/search |
| Documentation researcher | Current external specifications affect decisions | Web/docs, no writes |
| Implementation worker | A plan has independent, bounded edit scopes | Scoped read/write and tests |
| Test verifier | Validation is substantial or can run in parallel | Read and command execution |
| Reviewer | Risk justifies independent correctness/security review | Read/search/tests |
| Documenter | User-facing or operational docs are a distinct deliverable | Scoped docs writes |
| Integrator | Multiple worker outputs need conflict-aware assembly | Read/write/tests |

Specialized security, performance, accessibility, migration, or dependency roles should be created only from repository evidence and a recurring need.

## Minimal Contract

Every role contract should state each requirement once:

```yaml
name: role_name
purpose: one bounded responsibility
profile: fast | balanced | deep
capabilities: [minimum, required, set]
constraints:
  - explicit file or subsystem boundary
output:
  - findings or changes with paths
  - evidence and validation
  - risks, blockers, and unresolved decisions
stop_when: success criterion or escalation condition
```

For delegated work, include the objective, known facts, current delivery stage, allowed file scope, preserved behavior, success criteria, required evidence, and stop condition. A worker reports when it cannot satisfy the contract; it does not silently broaden scope or redesign the plan.

## Tier And Tool Selection

- **Fast:** mechanical exploration, focused checks, and documentation extraction.
- **Balanced:** bounded implementation and routine analysis.
- **Deep:** architecture, ambiguous integration, and high-risk review.
- Start with the least privileged tools that can complete the role.
- Keep reviewers read-only unless they are explicitly assigned fixes.
- Parallelize only independent scopes; keep delegation flat unless a role owns a complete subsystem.

Use neutral profiles in `.ai/` and map them to current runtime models in capability bindings. Do not hard-code provider model aliases in shared role contracts.

## Runtime-Specific Bindings

| Runtime | Generated role location |
|---|---|
| Codex | `.codex/agents/*.toml` |
| Claude Code | `.claude/agents/*.md` |

Generate both from the same neutral contract. Runtime files may express native tools, permissions, model aliases, and turn limits; shared behavior remains in `.ai/`.
