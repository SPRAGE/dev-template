# Optimum Skills + Agents Design — dev-template north star

- **Date:** 2026-06-17
- **Status:** current architecture; GPT-5.6 routing and contract refinement adopted 2026-07-12
- **Authors:** Claude (Opus 4.8) + Codex (custom-codex v0.2.13), co-designed via adversarial debate.
- **Verification:** Codex runtime bindings checked against the official Codex config reference (`developers.openai.com/codex/config-reference`, `/codex/subagents`). Claude runtime bindings corrected against the real subagent-type set (no built-in `Research`/`Test` types).

## Purpose

A dev-template that makes **any** agent runtime (Claude Code, Codex, future) deliver maximum value per token on a project — highest output quality, fewest tokens, lowest maintenance, true provider-neutrality.

## The core reframe

`.ai/` is **not a shared documentation folder. It is a neutral runtime *specification* that compiles into provider-native behavior.** You do not write docs every runtime reads; you write **one spec every runtime compiles from.** This single shift makes neutrality, generation, new-runtime support, and skill/agent composition fall out together.

## Design laws (non-negotiable)

1. **One source, generate downstream.** Language templates, provider views, agent bindings, and archives are generated from one neutral definition. Pointer-only adapters do not duplicate shared policy.
2. **Knowledge ≠ labor.** Skills hold procedures; agents hold execution. Each fact lives in exactly one place.
3. **Neutral by default; provider-specific only at the edge.** Provider tool names appear only in `capabilities/runtimes/*` bindings and thin adapters — enforced by lint.
4. **Progressive disclosure is mandatory.** Token cost scales with task complexity, not repo size.
5. **Capabilities are the interface.** Skills and agents speak neutral verbs; one ABI resolves them. New runtime = new binding file + adapter, nothing else.
6. **Deep reasoning is an escalation resource.** Coordinated or Hard planning and risk review use Sol/Opus; routine implementation, integration, and code review use Terra/Sonnet.
7. **Completion requires evidence.** Every handoff has success and stop conditions; every report has status, evidence, and a next action.
8. **The template enforces its own discipline.** Neutrality, budget, single-representation, freshness, authorization, routing, and report-contract checks run in CI.

## Taxonomy — the three-way split

| Element | Owns | Form | Lives in |
|---|---|---|---|
| **Skill** | the **how** — workflow, sequencing, standards, acceptance criteria, gates | prose | `.ai/skills/<s>/SKILL.md` (+ `manifest.yaml`) |
| **Agent** | the **who** — labor profile, permissions, model posture, output contract | schema | `.ai/agents/<a>.yaml` |
| **Capability** | the **handshake/ABI** — stable task type, inputs, outputs, fallback | schema | `.ai/capabilities/` |
| **Context** | project *facts* (architecture, conventions, decisions) | prose, read-tiered | `.ai/context/` |
| **Policy/Evals** | authorization, routing, evidence, and stop invariants | schema | `.ai/policy.yaml`, `.ai/evals/` |
| **Adapters** | pointer-only runtime entry points | prose, generated | `AGENTS.md`, `CODEX.md`, `CLAUDE.md` |

**Must never leak:** procedures into context; provider tool names into skills/context/neutral prose; knowledge into agent definitions; always-on bloat into adapters.

## Representation — hybrid by consumer

- **Machine-consumed** (generated, linted, budget-checked) → **YAML**: project metadata, policy, capability map, profiles, runtime bindings, agent contracts, skill manifests, fixtures, and budgets.
- **Agent-consumed** (read and followed in context) → **prose**: `SKILL.md` bodies plus compiled `instructions.md` and methodology views. Adapters only point to this shared layer and runtime discovery paths.
- **The capability map is YAML source-of-truth that *renders* a prose view** (`capabilities/map.md`) for direct agent reading. One source, two projections — resolves "must be a lintable ABI" vs "agent must read it without a parser."

## The dispatch contract

A skill never names `spawn_agent` or `Task`. It emits an abstract dispatch request; the compiler and runtime binding translate it:

```yaml
dispatch:
  capability: review.code
  profile: read_only
  task_mode: review
  current_layer: verify
  step_id: review-integrated-change
  inputs: [acceptance_criteria, preserved_invariants, required_evidence, diff]
  success_criteria: [all_material_findings_have_evidence]
  stop_conditions: [missing_diff, scope_expansion, elevated_security_risk]
  output_contract: review_report
  on_unavailable: inline_and_state_limitation
```

## The capability ABI (ratified schemas)

```yaml
# .ai/capabilities/map.yaml — runtime-agnostic contracts (source of truth)
version: 1
capabilities:
  explore:         { profile: read_only,       inputs: [objective, scope, repository_facts, required_evidence, stop_conditions], output: exploration_report }
  research:        { profile: read_network,    inputs: [objective, source_constraints, required_evidence, stop_conditions], output: research_report }
  plan:            { profile: read_only,       inputs: [objective, task_mode, repository_facts, constraints, preserved_invariants], output: plan }
  implement:       { profile: workspace_write, inputs: [objective, task_mode, current_layer, plan_step, repository_facts, file_scope, success_criteria, preserved_invariants, required_evidence, stop_conditions], output: change_report }
  test:            { profile: verify,          inputs: [objective, current_layer, change_scope, success_criteria, required_evidence, stop_conditions], output: test_report }
  review.code:     { profile: read_only,       inputs: [objective, current_layer, diff, success_criteria, preserved_invariants, required_evidence], output: review_report }
  review.security: { profile: read_only,       inputs: [objective, current_layer, diff, threat_scope, success_criteria, required_evidence], output: review_report }
  document:        { profile: workspace_write, inputs: [objective, current_layer, change_scope, audience, verified_behavior, file_scope], output: change_report }
  integrate:       { profile: workspace_write, inputs: [objective, current_layer, plan, worker_reports, current_diff, success_criteria, preserved_invariants, required_evidence, stop_conditions], output: integration_report }
output_contracts:
  common:             { fields: [status, current_layer, summary, evidence, blockers, stop_reason, next_action] }
  exploration_report: { fields: [repository_facts, relevant_paths, commands, risks, open_questions] }
  research_report:    { fields: [sourced_facts, sources, inferences, version_risk] }
  plan:               { fields: [objective, task_mode, assumptions, success_criteria, preserved_invariants, steps, dependencies, risks, verification, stop_conditions] }
  change_report:      { fields: [step_id, files_changed, preserved_invariants, verification, deviations] }
  test_report:        { fields: [scope, commands, results, failures, coverage_gaps, residual_risk] }
  review_report:      { fields: [findings, severity, preserved_invariants, missing_tests, residual_risk, recommendation] }
  integration_report: { fields: [integrated_steps, conflicts, preserved_invariants, verification, residual_risk] }
```

```yaml
# .ai/capabilities/profiles.yaml
version: 1
profiles:
  read_only:       { filesystem: read,      write: false,                 network: false }
  read_network:    { filesystem: read,      write: false,                 network: true }
  workspace_write: { filesystem: workspace, write: true,                  network: false }
  verify:          { filesystem: workspace, write: tests_and_diagnostics, network: false }
  privileged:      { filesystem: workspace, write: true,  network: true,  requires_human: true }
```

### Runtime binding principles

- Codex binds deep, balanced, and fast roles to `gpt-5.6-sol`, `gpt-5.6-terra`, and `gpt-5.6-luna`. Claude binds them to Opus, Sonnet, and Haiku.
- Model and reasoning effort are independent fields. Role defaults may differ within one model tier, and a role declares when escalation is justified.
- Terra/Sonnet are the default for routine implementation, integration, and code review. Sol/Opus own coordinated or Hard planning plus risk/security review.
- Luna/Haiku handle bounded read-heavy and verification work. They stop or escalate when diagnosis or synthesis becomes non-routine.
- Read, network-read, workspace-write, verification, and privileged profiles are mapped explicitly. A provider mapping may narrow access but cannot silently broaden it.
- The research role alone receives web or documentation MCP tools by default. The primary runtime and unrelated workers do not load their schemas.
- Delegation stays flat. Parallel work is limited to independent reads or disjoint write scopes; worktree isolation is optional runtime behavior, not a neutral requirement.

```yaml
# .ai/agents/reviewer.yaml — routine balanced review; risk_reviewer is separate
version: 1
name: reviewer
mission: Review integrated changes for correctness, regressions, preserved behavior, and missing tests.
when_to_use: A planned change needs routine independent review against its success criteria.
avoid_when: The change is direct and low risk, or it requires high-consequence security or migration review.
capabilities: [review.code]
routing_role: review
profile: read_only
model_tier: balanced
output_contract: review_report
max_turns: 16
constraints: [lead_with_findings, ground_findings_in_evidence, preserve_behavior, no_file_edits]
```

```yaml
# .ai/skills/<skill>/manifest.yaml — machine half of a skill (prose half is SKILL.md)
version: 1
name: virtual-tech-org
managed_by: dev-template
layer: work            # meta | setup | work
requires_capabilities: [explore, plan, implement, test, review.code, review.security, document, integrate]
budgets: { entry_tokens: 1200, total_warn: 3000 }
references: [references/domain-checks.md]
```

## New-runtime adapter contract (Codex's addition)

A runtime plugs in by adding `capabilities/runtimes/<rt>.yaml` with model tiers, profile/tool mappings, role effort where supported, scoped extensions, and an explicit inline fallback. A renderer maps that binding into provider-native files while native user-local settings remain outside the compiler.

## Generate / don't-generate boundary

- **Single-source (neutral):** context schema, delivery and authorization policy, skill manifests, capability contracts, neutral agent contracts, deterministic fixtures, budgets, and lints.
- **Generated downstream:** shared instruction/methodology views; pointer-only `AGENTS.md`, `CODEX.md`, and `CLAUDE.md`; `.codex/agents/*.toml`; Claude agent registrations; the readable capability map; and per-language shared files. Provider skill views are symlinks and `.skill` archives are deterministic packages.
- **Native/local:** provider settings that cannot be represented neutrally, user-local permissions, installed connector state, secrets, and ephemeral agent memory. Default tool bindings still come from the runtime map rather than ad hoc adapter prose.

## Minimal high-leverage sets

- **Capabilities (9):** explore · research · plan · implement · test · review.code · review.security · document · integrate.
- **Agents (9):** repo-explorer · docs-researcher · architecture-planner · implementation-worker · test-verifier · reviewer · risk-reviewer · documenter · integrator.
- **Profiles (5):** read_only · read_network · workspace_write · verify · privileged.

## Token strategy + guardrails

**Always-loaded:** `AI.md` plus `.ai/instructions.md`; generated adapters only point at this shared layer. `active-context.md` exists only when it holds real cross-session state. Architecture, conventions, decisions, skills, references, and tool schemas are read conditionally.

**Explicit budgets (CI-enforced):**
```yaml
budgets: { always_loaded_tokens: 2400, adapter_tokens: 500, skill_descriptions_tokens: 900, skill_entry_tokens: 1200, agent_contract_tokens: 800 }
```

**Lints and fixtures (CI):** provider terms in neutral files · unused policy/runtime keys · skill and always-loaded budgets · duplicate adapter policy · missing capability declarations · agents without output or stop contracts · writable agents without scope · runtime privilege expansion · skill refs to nonexistent files · generated drift · authorization scenarios · tier routing · provider metadata parity · completion without evidence · blocked reports without a reason or next action.

## Ideal layout

```
AI.md                          # always-on project facts
AGENTS.md / CODEX.md / CLAUDE.md   # GENERATED pointer-only runtime adapters
.ai/                           # the neutral SPEC that compiles to provider-native behavior
  project.yaml                 # identity, context routes, spec paths, budgets
  policy.yaml                  # authorization, routing, handoffs, completion
  instructions.md              # GENERATED always-loaded policy view
  capabilities/
    map.yaml                   # capability contracts (SOURCE OF TRUTH)
    profiles.yaml              # read_only | read_network | workspace_write | verify | privileged
    runtimes/{codex,claude}.yaml   # models, effort, tools, permissions, fallback
    map.md                     # rendered prose view (generated, agent-readable)
  methodology.md               # GENERATED detailed delivery view
  context/{architecture,conventions,decisions,active}.md   # read-tiered; active only when real
  skills/<skill>/{manifest.yaml, SKILL.md, references/}    # contract = yaml, procedure = prose
  agents/<agent>.yaml          # neutral contracts: mission, capabilities, profile, output_contract
  evals/*.yaml                 # deterministic policy and report-contract fixtures
  generators/                  # how .ai/ compiles to provider views
tools/  (ai-doctor · compiler · package-skills · sync)
tests/  (policy · provider parity · budgets · generated freshness · skills · apps · layout)
.claude/ .agents/ .codex/      # generated provider views plus explicit native settings
templates/<lang>/              # GENERATED overlays — only true deltas authored
```

## Current migration state

- **Historical foundation:** shared skills and context moved from Claude-specific paths to `.ai/`; language templates collapsed into a base plus explicit overlays.
- **Compiled runtime:** capability maps, profiles, model bindings, agent contracts, budgets, and provider artifacts are generated and checked for drift.
- **GPT-5.6 refinement:** adapters are pointer-only; tools are role-scoped; routine work uses the balanced tier; deep planning and review are risk-triggered; handoffs carry preserved invariants, evidence, and stops; deterministic fixtures test policy behavior.
- **Measured optimization:** optional live-model evals compare task success, token use, latency, and cost before changing model or effort defaults. Pro-style modes, PTC, or additional delegation are enabled only when representative evals justify them.

## Method / provenance

Co-designed by Claude and Codex over four exchanges: (1) VTO provider-neutral refactor + 2-round review-to-consensus, (2) generative improvement debate → ranked roadmap, (3) independent first-principles designs → synthesis, (4) ratification + schema pinning. Both sides corrected the other's runtime errors (Codex fixed Claude's isolation/dispatch model; Claude fixed Codex's non-existent `Research`/`Test` subagent refs). Codex bindings docs-verified.
