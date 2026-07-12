# dev-template

Nix project templates with a provider-neutral agent specification compiled into Codex and Claude runtimes.

The default workflow is inference-first: a small request supplies the outcome while the runtime inspects the repository, infers reversible details, and selects the smallest verified delivery loop. Routine implementation, integration, and review stay on the balanced tier. The deep tier is reserved for genuinely coordinated or high-risk planning and specialist review. Project facts, skill bodies, and tool schemas load only when the task needs them.

## Quick Start

```bash
nix flake init -t github:SPRAGE/dev-template#rust  # or #python, or omit for base
direnv allow                                        # optional
```

Initialize the language project (`cargo init` or `uv init`), replace `PROJECTNAME`, then ask for an outcome in plain language. Run `cc-setup` once real code exists to capture exact commands and architecture.

For an existing repository:

```bash
nix run github:SPRAGE/dev-template#onboard
```

## Agent Architecture

`.ai/` is the source specification:

- `project.yaml` - project identity, context routes, compiled-spec paths, and token budgets.
- `policy.yaml` - authorization, delivery routing, handoffs, preservation, and completion rules.
- `capabilities/` - runtime-neutral inputs, outputs, profiles, and provider/model bindings.
- `agents/` - role, permission, model-tier, and output contracts.
- `instructions.md` and `methodology.md` - generated readable policy views.
- `context/` - project facts loaded only when relevant.
- `skills/` - task procedures loaded on demand.
- `evals/` - deterministic authorization, routing, and report-contract fixtures.
- `generators/compile.py` - validates policy and produces pointer-only adapters plus provider-native agents.

Generated views:

- `AGENTS.md`, `CODEX.md`, and `CLAUDE.md` are small runtime pointers; workflow policy remains in `.ai/`.
- `.codex/agents/*.toml` and `.claude/agents/*.md` bind neutral roles to provider models, tools, and permissions.
- `.agents/skills/`, `.claude/skills/`, and `.codex/skills/` link to `.ai/skills/`.

The model tiers are explicit and centralized:

| Work | Codex | Claude |
|---|---|---|
| Coordinated/Hard planning and risk or security review | `gpt-5.6-sol` | `opus` |
| Routine implementation, integration, and code review | `gpt-5.6-terra` | `sonnet` |
| Focused exploration, documentation, and bounded verification | `gpt-5.6-luna` | `haiku` |

Model identity and reasoning effort are separate runtime controls. Change bindings or role effort in `.ai/capabilities/runtimes/`, then regenerate; do not edit generated agents directly.

## Delivery Contract

- Explain, review, diagnose, and plan requests inspect and report; they do not silently become implementation work.
- Build, change, and fix requests authorize in-scope local edits and non-destructive validation.
- Direct, routine work executes without a formal plan. Use a deep plan when work has real coordination, architectural coupling, material ambiguity, or elevated risk.
- A worker handoff carries its task mode, current layer, step scope, success criteria, preserved invariants, required evidence, and stop conditions.
- Reports return `complete`, `partial`, or `blocked` with evidence and a next action. A completion claim without required evidence is invalid.
- Destructive actions, external writes or deployments, purchases, permission expansion, and material scope expansion require confirmation.
- Repository inspection stays inside the current Git root unless the user names another path or explicitly authorizes cross-repository work. Missing code is reported rather than searched for in sibling directories.

## Templates

- `default` - language-neutral shell.
- `python` - Python 3.13 and `uv`.
- `rust` - stable Rust, Cargo tooling, OpenSSL, and `pkg-config`.

`template/` is the authored base. Language variants are generated copies with only `AI.md`, `.ai/project.yaml`, `flake.nix`, and `.gitignore` as overlays.

## Commands

```bash
python template/.ai/generators/compile.py --root template
bash tests/sync-template-shared.sh
bash tests/test-agent-system.sh
bash tests/test-template-sync.sh
nix develop -c bash tests/test-skills.sh
nix develop -c bash tests/test-apps.sh
nix flake check --all-systems
```

Lifecycle apps:

- `nix run .#onboard` - add missing managed assets without replacing project guidance.
- `nix run .#sync-skills` - refresh managed skills, generated adapters, and provider agents.
- `nix run .#ai-doctor` - validate layout, contracts, budgets, and generated freshness.
- `nix run .#fresh-start` - destructively reset managed assets after confirmation while preserving local runtime state and language flavor.

## Cost And Context

- Always-loaded guidance is budgeted in `.ai/project.yaml`.
- Provider adapters point to shared guidance instead of repeating its workflow policy.
- Skill descriptions have a combined discovery budget; entry files have individual budgets.
- Placeholder `active-context.md` is not seeded. Create it only for real cross-session work.
- No global MCP server, web catalog, or optional Claude plugin is enabled by default. Documentation and browser tools belong on the research role that needs them.
- Delegation depth stays at one. Parallelize independent work only, and do not delegate merely to satisfy a process template.
- Deterministic policy fixtures test authorization, tier selection, provider parity, and evidence/stop invariants without pretending to measure live-model judgment.

## Skill Archives

`template/.ai/skills/` is the source. After a change, regenerate archives with the skill packager and run `tests/test-skills.sh`. CI rejects source/archive drift and template-generation drift.

Review [SECURITY.md](SECURITY.md) before using the defaults in sensitive or production repositories.
