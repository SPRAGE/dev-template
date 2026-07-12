# Shared Guidance Quality Criteria

## Scoring Rubric

Score the authoritative shared guidance (`AI.md`, `.ai/`, and generated adapters) against repository evidence. Runtime-native files are checked for faithful bindings, not treated as additional policy sources.

| Criterion | Points | Full-credit evidence |
|---|---:|---|
| Commands and workflows | 20 | Essential setup, build, test, lint, and delivery commands are exact, contextualized, and verified. |
| Architecture clarity | 20 | Entry points, meaningful directories, module boundaries, and relevant data flow are clear. |
| Non-obvious patterns | 15 | Recurring gotchas, ordering constraints, workarounds, and unusual rationale are captured. |
| Concision | 15 | Every loaded line changes a decision or saves repeated discovery; no obvious or duplicated content. |
| Currency | 15 | Commands, paths, stack facts, decisions, and generated outputs match the current repository. |
| Actionability | 15 | Instructions have concrete paths, scopes, success criteria, and runnable validation. |

Award full points when all material signals are proven, half when guidance is useful but incomplete, and zero when absent or misleading. Use an intermediate score only with cited evidence.

## Assessment Process

1. Identify always-loaded, conditional, generated, and local-only layers.
2. Cross-reference claims with manifests, source, CI, and working commands.
3. Score each criterion; do not reward repeated content in multiple layers.
4. Report each issue with severity, evidence, owner file, and action.
5. Recompile and verify runtime outputs after neutral sources change.

## Red Flags

- Commands that fail or require undocumented prerequisites
- References to deleted files/folders
- Outdated tech versions
- Copy-paste from templates without customization
- Generic advice not specific to the project
- Abandoned TODO items presented as active work
- Duplicate policy across shared sources and generated adapters
- Placeholder or stale rolling context loaded every session
- Provider-native syntax in neutral source files
- Secrets, personal permissions, or local state in checked-in guidance
