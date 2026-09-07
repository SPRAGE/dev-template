# Template Efficiency Redesign — 2026-09-07

The final v3 template contains **ten files, zero default skills, zero custom roles, and no model or reasoning-effort pins**. Generic skill procedures and execution ceremony have been removed from new projects. Useful maintenance tools, optional workflows, and compatibility fixtures remain in this repository.

## Final structure

| Surface | Final decision |
|---|---|
| Startup guidance | One selected provider entrypoint plus `AI.md`; concise shared instructions |
| Direct/Planned/Hard routes and handoff schema | Removed; proportional planning and independent review remain plain instructions |
| Context | Create only real project facts; load architecture, conventions, decisions, and knowledge when relevant |
| Skills | None by default; opt-in `agent-context` and rewritten `frontend-design` |
| Roles | Opt-in scout/researcher/worker/reviewer with native access boundaries |
| Models | Inherit runtime choices; optional explicit project overrides |
| Compiler and capability framework | Removed from generated projects; maintainer `tools/template.py` generates the small shared surface |
| Validation, packaging, evaluations | Maintainer tools and tests; no per-project copies |
| Language mirrors | Three overlays: `AI.md`, `flake.nix`, `.gitignore` |
| Lifecycle | Owned-file sync, explicit legacy upgrades, private backups, checked restoration |

The primary context keeps planning, architecture, integration, and final review. Shared guidance now carries autonomous parallel delegation and a preference for available models explicitly identified as cheaper into all downstream projects. Actual model selection and delegation depend on the runtime; unsupported capabilities or unavailable cost information must be reported. Custom roles help only when bounded delegation or independent review is useful. Skills must contribute a concrete recurring procedure, project-specific evidence, or a verified tool workflow; ordinary engineering knowledge does not justify another skill.

## Skill disposition

| Original skill | Final disposition |
|---|---|
| agent-context | Rewritten optional maintainer workflow; explicitly selected only in this checkout |
| frontend-design | Rewritten optional workflow driven by a real design brief, project examples, and browser checks |
| agent-evaluation | Removed; concrete benchmark and offline evaluation tooling remain |
| skill-authoring | Removed; deterministic validation and packaging remain in `tools/skills/` |
| domain-modeling | Removed; project domain facts belong in project documentation |
| api-contracts | Removed; application contracts belong with the application |
| test-design | Removed; meaningful verification remains a delivery requirement |
| data-visualization | Removed; no universal project-specific workflow |
| interactive-playground | Removed; specialized output format needs no default procedure |
| incident-debugging | Removed; project-owned incident runbook template remains |
| migration-safety | Removed; actual migration recovery code/tests and a project runbook template remain |
| performance-engineering | Removed; measurement-focused project runbook template remains |
| knowledge-integration | Removed; optional registry documentation and standalone validator remain |

Eleven original skills are no longer offered. Two are available only on request. Frozen legacy payloads under compatibility/test fixtures support migration checks and are never installed in v3 projects. The original twelve catalog bodies were dormant; removing them is a packaging/routing reduction, not a claim that their entire contents previously loaded on every task.

## Static measurements

The original baseline includes the Codex packaging edits already present when the task began. Each surface uses `ceil(max(UTF-8 bytes / 4, whitespace words * 1.3))`. Startup includes routed guidance and native role/skill discovery descriptions. Current measurements include discoverable names too, and do not sum duplicate provider views.

| Surface | Original startup | First pass | Final startup | Original reduction |
|---|---:|---:|---:|---:|
| Maintainer checkout | 1306 | 1088 | 807 | 38.2% |
| Base template | 1148 | 830 | 448 | 61.0% |
| Python template | 1130 | 855 | 472 | 58.2% |
| Rust template | 1135 | 849 | 466 | 58.9% |

- Regular files per generated project: **77 → 41 → 10**.
- Default discoverable skills: **1 → 0**; optional catalog index: **553 → 0** estimated tokens.
- Default discoverable roles: **4 → 0**.
- Base startup reduction from the first pass: **46.0%**.
- No separate methodology load; dependent tasks use the same short shared guidance.

The retained optional entrypoints are 355 estimated tokens for agent-context and 297 for frontend-design; their bodies load only when selected. New project startup budgets are 900 estimated tokens, configurable in `.ai/template.json`. Runtime wrappers, tool schemas, loaded context/bodies, and conversation history are additional costs. No paired live-model evaluation was run; these numbers establish static size reductions, not better reasoning, API bills, or latency.

The initial minimal v3 base used 378 estimated startup tokens; the downstream delegation policy adds 70 tokens while retaining ten files and zero default profiles.

Raw original, first-pass, initial minimal v3, and final values are in [context-cost-2026-09-07.json](context-cost-2026-09-07.json). Reproduce current measurements with `python tools/template.py stats --root template`, replacing the root for other variants.

## Preservation and verification

The pre-existing Codex packaging changes remain: the retained official release serves primary Linux, and locked unstable nixpkgs serves ARM Linux/macOS. No downstream checkout was modified and no deployment, remote publication, or model call was performed.

Sync preserves customized files and cannot silently upgrade older schemas. Explicit migration rejects unknown core changes before edits. A complete unchanged dormant catalog and its known activation CLI are retired; customized catalogs/tools or canonical/native activations keep the catalog and tool together to preserve their dependencies. Custom skills are preserved as complete trees. Project identity/context and provider-local state survive. V1-to-v2 migration still uses a frozen compatibility source, then v2-to-v3 uses the new explicit route.

Independent review found recovery and preservation edges, now covered by regression checks: corrupt backup assets; dangling canonical discovery after profile removal; legacy compiler caches; old dormant catalogs versus custom/active units; external provider-directory symlinks; and broken legacy specification links. Mirror regeneration also refuses symlink parents.

All 42 v3 lifecycle tests, 6 standalone knowledge tests, 9 v1 migration tests, and 11 evaluation-record tests passed. Legacy provider/budget/registry contracts, mirror preservation and parity, optional skills and deterministic archives, all eight actual Nix app entrypoints, local CLI canaries, and all-system flake evaluation passed. Independent review found no remaining material issues. Backups preserve affected file contents, modes, and symlink targets and reject intervening edits during restore; per-file atomic writes and rollback do not imply power-loss atomicity across the whole operation.
