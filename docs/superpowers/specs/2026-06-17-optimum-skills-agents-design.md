# Optimum Skills + Agents Design — dev-template north star

- **Date:** 2026-06-17
- **Status:** active — north-star spec; informs (does not block) the Stage-1 roadmap
- **Authors:** Claude (Opus 4.8) + Codex (custom-codex v0.2.13), co-designed via adversarial debate.
- **Verification:** Codex runtime bindings checked against the official Codex config reference (`developers.openai.com/codex/config-reference`, `/codex/subagents`). Claude runtime bindings corrected against the real subagent-type set (no built-in `Research`/`Test` types).

## Purpose

A dev-template that makes **any** agent runtime (Claude Code, Codex, future) deliver maximum value per token on a project — highest output quality, fewest tokens, lowest maintenance, true provider-neutrality.

## The core reframe

`.ai/` is **not a shared documentation folder. It is a neutral runtime *specification* that compiles into provider-native behavior.** You do not write docs every runtime reads; you write **one spec every runtime compiles from.** This single shift makes neutrality, generation, new-runtime support, and skill/agent composition fall out together.

## Design laws (non-negotiable)

1. **One source, generate downstream.** Language templates, provider views, agent bindings, archives are *generated* from one neutral definition. Authoring is edit-once; drift is structurally impossible (CI regenerates + diffs).
2. **Knowledge ≠ labor.** Skills hold procedures; agents hold execution. Each fact lives in exactly one place.
3. **Neutral by default; provider-specific only at the edge.** Provider tool names appear only in `capabilities/runtimes/*` bindings and thin adapters — enforced by lint.
4. **Progressive disclosure is mandatory.** Token cost scales with task complexity, not repo size.
5. **Capabilities are the interface.** Skills and agents speak neutral verbs; one ABI resolves them. New runtime = new binding file + adapter, nothing else.
6. **The template enforces its own discipline** — neutrality, budget, single-representation, and freshness lints run in CI.

## Taxonomy — the three-way split

| Element | Owns | Form | Lives in |
|---|---|---|---|
| **Skill** | the **how** — workflow, sequencing, standards, acceptance criteria, gates | prose | `.ai/skills/<s>/SKILL.md` (+ `manifest.yaml`) |
| **Agent** | the **who** — labor profile, permissions, model posture, output contract | schema | `.ai/agents/<a>.yaml` |
| **Capability** | the **handshake/ABI** — stable task type, inputs, outputs, fallback | schema | `.ai/capabilities/` |
| **Context** | project *facts* (architecture, conventions, decisions) | prose, read-tiered | `.ai/context/` |
| **Rules/Hooks** | deterministic constraints + automation | schema → generated | `.ai/rules/` |
| **Adapters** | thin runtime entry points | prose, generated | `AI.md`, `AGENTS.md`, `CODEX.md`, `CLAUDE.md` |

**Must never leak:** procedures into context; provider tool names into skills/context/neutral prose; knowledge into agent definitions; always-on bloat into adapters.

## Representation — hybrid by consumer

- **Machine-consumed** (generated, linted, budget-checked) → **YAML**: capability map, profiles, runtime bindings, agent contracts, skill manifests, rules, budgets.
- **Agent-consumed** (read and followed in context) → **prose**: `SKILL.md` bodies, `instructions.md`, methodology, adapters.
- **The capability map is YAML source-of-truth that *renders* a prose view** (`capabilities/map.md`) for direct agent reading. One source, two projections — resolves "must be a lintable ABI" vs "agent must read it without a parser."

> Note: the shipped `virtual-tech-org/references/orchestration.md` is the *transitional* prose form of this map — correct for Stage 0, superseded by `capabilities/map.yaml` here.

## The dispatch contract

A skill never names `spawn_agent` or `Task`. It emits an abstract dispatch request; the runtime adapter translates it:

```yaml
dispatch:
  capability: review.code
  profile: read_only
  inputs: [acceptance_criteria, diff]
  output_contract: findings
  on_unavailable: inline_and_state_limitation
```

## The capability ABI (ratified schemas)

```yaml
# .ai/capabilities/map.yaml — runtime-agnostic contracts (source of truth)
version: 1
capabilities:
  explore:         { profile: read_only,       inputs: [question, scope],     output: findings }
  research:        { profile: read_network,     inputs: [topic],               output: findings }
  plan:            { profile: read_only,        inputs: [brief],               output: plan }
  implement:       { profile: workspace_write,  inputs: [spec, acceptance],    output: diff }
  test:            { profile: verify,           inputs: [scope],               output: test_report }
  review.code:     { profile: read_only,        inputs: [diff, acceptance],    output: findings }
  review.security: { profile: read_only,        inputs: [diff],                output: findings }
  document:        { profile: workspace_write,  inputs: [scope],               output: diff }
  integrate:       { profile: workspace_write,  inputs: [workspaces|branches], output: diff }
output_contracts:
  findings:    { items: [{title, severity, file, line, evidence, fix}] }
  diff:        { format: unified, files_changed: int, summary: str }
  plan:        { steps: [{id, action, files, deps}] }
  test_report: { command: str, passed: bool, failures: [{name, detail}] }
```

```yaml
# .ai/capabilities/profiles.yaml
version: 1
profiles:
  read_only:       { filesystem: read,      write: false, network: false, requires_human: false }
  read_network:    { filesystem: read,      write: false, network: true,  requires_human: false }
  workspace_write: { filesystem: workspace, write: true,  network: false, requires_human: false }
  verify:          { filesystem: workspace, write: true,  network: false, scope: tests_and_diagnostics, requires_human: false }
  privileged:      { filesystem: workspace, write: true,  network: true,  requires_human: true }
```

```yaml
# .ai/capabilities/runtimes/codex.yaml — capability -> Codex primitive (docs-verified)
version: 1
runtime: codex
capabilities:
  explore:         { via: custom_agent, ref: repo_explorer }
  research:        { via: custom_agent, ref: docs_researcher }
  plan:            { via: local }                       # orchestrator plans locally on Codex
  implement:       { via: spawn_agent, isolation: forked_workspace }
  test:            { via: custom_agent, ref: test_verifier }
  review.code:     { via: custom_agent, ref: reviewer }
  review.security: { via: custom_agent, ref: reviewer, prompt_variant: security }
  document:        { via: spawn_agent, isolation: forked_workspace }
  integrate:       { via: spawn_agent, isolation: forked_workspace }
primitives:
  parallelize:     { via: spawn_agent, max_threads: 6, max_depth: 1 }
  background:      { start_with: spawn_agent, await_with: wait_agent, resume_with: resume_agent, send_with: send_input, close_with: close_agent }
sandbox_for_profile:
  read_only:       { sandbox_mode: read-only }
  read_network:    { sandbox_mode: read-only, notes: "network depends on tool availability; prefer MCP/web tools over shell network" }
  workspace_write: { sandbox_mode: workspace-write, sandbox_workspace_write: { network_access: false } }
  verify:          { sandbox_mode: workspace-write, sandbox_workspace_write: { network_access: false } }
  privileged:      { sandbox_mode: workspace-write, sandbox_workspace_write: { network_access: true }, approval_policy: on-request, requires_human: true, notes: "do NOT auto-map neutral privileged to danger-full-access" }
```

```yaml
# .ai/capabilities/runtimes/claude.yaml — capability -> Claude Code primitive
# (corrected: Claude has no built-in Research/Test subagent types -> general-purpose)
version: 1
runtime: claude
capabilities:
  explore:         { via: subagent, ref: Explore }
  research:        { via: subagent, ref: general-purpose }   # + web search
  plan:            { via: subagent, ref: Plan }
  implement:       { via: subagent, ref: general-purpose }
  test:            { via: subagent, ref: general-purpose }   # + run suite
  review.code:     { via: subagent, ref: "superpowers:code-reviewer" }
  review.security: { via: subagent, ref: "superpowers:code-reviewer", prompt_variant: security }
  document:        { via: subagent, ref: general-purpose }
  integrate:       { via: subagent, ref: general-purpose }
primitives:
  parallelize:     { via: multi_dispatch }                   # N Agent calls in one message
  isolate:         { via: worktree }                         # Agent(isolation:"worktree")
  background:      { via: run_in_background }                 # Agent(run_in_background:true)
```

```yaml
# .ai/agents/reviewer.yaml — neutral agent contract (one per agent)
version: 1
name: reviewer
mission: Review changes for correctness, security, and maintainability.
capabilities: [review.code, review.security]
profile: read_only
output_contract: findings
constraints: [no_file_edits, cite_file_line_for_every_finding, separate_confirmed_findings_from_assumptions]
```

```yaml
# .ai/skills/<skill>/manifest.yaml — machine half of a skill (prose half is SKILL.md)
version: 1
name: virtual-tech-org
layer: work            # meta | setup | work
requires_capabilities: [explore, plan, implement, test, review.code, review.security, document, integrate]
budgets: { entry_tokens: 1200, total_warn: 6000 }
references: [references/workflow-stages.md, references/org-roles.md]
```

## New-runtime adapter contract (Codex's addition)

A runtime plugs in by adding `capabilities/runtimes/<rt>.yaml` **and** declaring, in one place:
supported **profiles** · its **primitive vocabulary** (`via:` values) · **capability coverage** · **unsupported capabilities** (→ inline fallback) · **generated files** · **non-generated runtime-local settings**. That declaration is sufficient for a third runtime to drop in cleanly.

## Generate / don't-generate boundary

- **Single-source (neutral):** context schema, skill manifests, capability contracts, neutral agent contracts, rule/policy intent, budgets/lints.
- **Generated downstream:** `AGENTS.md`, `CODEX.md`, `CLAUDE.md`, `.codex/agents/*.toml`, Claude agent registrations, provider skill links/wrappers, hook config, MCP fragments, per-language template overlays, `.skill` archives.
- **NEVER generated (stays native/local):** provider runtime settings that are inherently native, user-local permissions, model-specific tuning, installed connector state, ephemeral agent memory.

## Minimal high-leverage sets

- **Capabilities (9):** explore · research · plan · implement · test · review.code · review.security · document · integrate.
- **Agents (≈8):** repo-explorer · docs-researcher · planner · implementer · test-verifier · reviewer · documenter · **integrator** (merges parallel forked-workspace results at the gate).
- **Profiles (5):** read_only · read_network · workspace_write · verify · privileged.

## Token strategy + guardrails

**Always-loaded (budget ≤ ~3500 tokens):** `AI.md` (project facts + response-style) + `.ai/instructions.md` (+ `active-context.md` only when it holds real state). Deeper context (architecture/conventions/decisions) is read **conditionally** by task type.

**Explicit budgets (CI-enforced):**
```yaml
budgets: { always_loaded_tokens: 3500, skill_entry_tokens: 1200, skill_total_warn: 6000, agent_contract_tokens: 800, adapter_tokens: 500 }
```

**Lints (CI):** provider terms in neutral files · skill body over budget · always-loaded over budget · duplicate sections across adapters · skills missing capability declarations · agents without output contracts · agents with write perms but no scope constraint · hooks/rules encoding workflow prose · context stale beyond threshold · skill refs to nonexistent files · generated files diverging from neutral source.

## Ideal layout

```
AI.md                          # always-on, minimal: project facts + response-style
AGENTS.md / CODEX.md / CLAUDE.md   # GENERATED thin adapters + runtime-notes
.ai/                           # the neutral SPEC that compiles to provider-native behavior
  project.yaml                 # name, stack, commands, tiered read-order, token budgets
  instructions.md              # tiny prose: read-order + response-style + safety
  capabilities/
    map.yaml                   # capability contracts (SOURCE OF TRUTH)
    profiles.yaml              # read_only | read_network | workspace_write | verify | privileged
    runtimes/{codex,claude,fallback}.yaml   # per-runtime bindings
    map.md                     # rendered prose view (generated, agent-readable)
  methodology.md               # disciplined cycle + per-runtime enforcers (prose, optional)
  context/{architecture,conventions,decisions,active}.md   # read-tiered; active only when real
  skills/<skill>/{manifest.yaml, SKILL.md, references/}    # contract = yaml, procedure = prose
  agents/<agent>.yaml          # neutral contracts: mission, capabilities, profile, output_contract
  rules/*.yaml                 # policy / neutrality-lint / budgets
  generators/                  # how .ai/ compiles to provider views
tools/  (ai-doctor · generate-runtime · lint-ai · package-skills · sync)
tests/  (neutrality · token-budgets · generated-freshness · skills · agents · layout)
.claude/ .agents/ .codex/      # GENERATED provider views + native settings (NOT generated)
templates/<lang>/              # GENERATED overlays — only true deltas authored
```

## Migration path (this spec ↔ the agreed roadmap)

- **Stage 0 — shipped:** `virtual-tech-org` neutralized; capability/methodology maps proven in prose (`orchestration.md`).
- **Stage 1 — agreed roadmap:** neutralize cc-setup & skill-creator in place · Codex runtime rules in `AGENTS.md` · provider-neutrality lint · Codex multi-agent playbook · drop `CLAUDE.md` from Codex doc fallbacks · tier `.ai/context` reads · drop seeded `active-context.md` · trim `AI.md` · shared response-style rule · **collapse triplication into base + overlays.**
- **Stage 2 — this spec:** lift prose maps → `capabilities/map.yaml` ABI · agents → neutral contracts with output contracts · `.ai/` becomes a *compiled* spec with budget + neutrality lints in CI.

Each roadmap step removes a prose/coupling smell and moves a fact behind the capability ABI — the roadmap **is** the migration path to this spec.

## Method / provenance

Co-designed by Claude and Codex over four exchanges: (1) VTO provider-neutral refactor + 2-round review-to-consensus, (2) generative improvement debate → ranked roadmap, (3) independent first-principles designs → synthesis, (4) ratification + schema pinning. Both sides corrected the other's runtime errors (Codex fixed Claude's isolation/dispatch model; Claude fixed Codex's non-existent `Research`/`Test` subagent refs). Codex bindings docs-verified.
