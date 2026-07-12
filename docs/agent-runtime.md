# Agent Runtime Architecture

## Objective

A minimal request should produce the analysis needed for a verified result without paying deep-model cost for every step. The primary context retains user intent, preserved values, decisions, and delivery state. Specialized agents receive bounded work and return evidence instead of raw session history.

## Instruction Layers

Authored policy lives under `template/.ai/`:

- `project.yaml` defines project identity, context routes, budgets, and compiled-spec paths;
- `policy.yaml` defines authorization, delivery triggers, handoffs, preservation, and completion;
- `capabilities/` defines task inputs, report contracts, profiles, and runtime bindings;
- `agents/` defines bounded roles, model posture, escalation conditions, and write scope;
- `instructions.md` and `methodology.md` are generated readable policy views;
- `skills/` hold procedures loaded only when triggered;
- `evals/` holds deterministic policy and generation fixtures.

`AGENTS.md`, `CODEX.md`, and `CLAUDE.md` are generated pointer-only adapters. They identify runtime discovery paths and point to shared policy; they do not restate the delivery loop. This keeps an instruction authoritative in one place and prevents provider drift.

## Authorization And Routing

Intent determines the action boundary before task complexity determines the model tier:

- Explain, review, diagnose, and plan requests inspect and report without implementation.
- Build, change, and fix requests authorize scoped local edits and non-destructive validation.
- Destructive actions, external writes or deployments, purchases, permission expansion, and material scope expansion require confirmation.

Direct, routine work executes without a formal plan. Use a deep planner when work is genuinely coordinated, architecturally coupled, materially ambiguous, security-sensitive, destructive, regulated, or otherwise high risk. Reuse an adequate existing plan instead of planning again.

| Work | Codex | Claude |
|---|---|---|
| Coordinated/Hard planning; risk and security review | Sol | Opus |
| Routine implementation, integration, and code review | Terra | Sonnet |
| Focused exploration, documentation, and bounded verification | Luna | Haiku |

Model identity and reasoning effort are independent controls. Routine Sol or Opus work should not default to maximum effort, and a fast-tier worker must stop or escalate when synthesis, diagnosis, or risk exceeds its contract.

## Handoff And Evidence

Every dispatched step includes:

- task mode and current delivery layer;
- step identifier, relevant facts, dependencies, and exact file scope;
- success criteria and user-provided values or behavior that must remain unchanged;
- required evidence and validation commands;
- stop conditions for contradictions, missing dependencies, scope expansion, or elevated risk.

Every worker report has a normalized `complete`, `partial`, or `blocked` status, evidence, material caveats, and a next action. `complete` is invalid when required evidence is absent. Workers do not silently redesign a plan, weaken behavior, or delete functionality to make a check pass.

The primary or a balanced integrator reconciles worker reports against current repository state. Sol/Opus review is added when risk warrants it, not as a mandatory ceremony for every cross-file edit.

## Tool Isolation

The main runtime does not load a global MCP or web catalog. Network and documentation tools are scoped to the research role, and other agents receive only the tools required by their profile. Parallel work stays flat and is limited to independent reads or disjoint write scopes.

## Compilation And Policy Checks

`compile.py` validates the neutral schema and generates Codex TOML agents, Claude Markdown agents, pointer adapters, and the readable capability map. It rejects unused policy fields, unexplained provider privilege expansion, missing scopes, budget overruns, and stale generated files.

Deterministic fixtures cover authorization outcomes, delivery-tier selection, provider metadata parity, contradiction stops, and evidence requirements. These tests prove policy and compiler behavior; optional live-model evaluations are still required to measure GPT-5.6 or Claude judgment quality.

## Context Budget

The compiler estimates and enforces always-loaded, adapter, skill-discovery, skill-entry, and agent-contract budgets. Architecture, conventions, decisions, active work, references, and tool schemas remain conditional. Placeholder active context and globally exposed tool schemas are intentionally absent.

## Change Workflow

1. Edit the neutral source or deterministic fixtures.
2. Run `python template/.ai/generators/compile.py --root template`.
3. Run `bash tests/sync-template-shared.sh`.
4. Regenerate skill archives when skill sources changed.
5. Run agent-system, template-sync, skill, app, and flake checks.
