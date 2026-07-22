# dev-template

Lean Nix project templates with one provider-neutral agent specification compiled into Codex and Claude Code runtimes.

The template keeps the primary agent responsible for intent, domain grounding, planning, integration, routine verification, and the final answer. Four optional roles isolate noisy reads, external research, independent edits, and high-consequence review. Only one skill is discovered by default; a dormant specialist catalog is loaded selectively.

## Quick Start

```bash
nix flake init -t github:SPRAGE/dev-template#rust  # or #python; omit for the base template
direnv allow                                        # optional
```

Initialize the language project, replace `PROJECTNAME`, and ask for an outcome in plain language. Invoke `agent-context` after real code exists to record verified commands and architecture.

Direnv enters the Nix shell but deliberately does not load `.env` or `.env.mcp`; export only the variables needed by a developer-controlled command.

For an existing repository:

```bash
nix run github:SPRAGE/dev-template#onboard
```

## Nix And Codex

All four flakes declare `nixpkgs-unstable` and install Codex as `pkgs.codex`; generated projects create their own lock on first evaluation. There is no private Codex input, internal network fallback, or separate release package. The evaluated systems are `x86_64-linux`, `aarch64-linux`, and `aarch64-darwin`; the currently locked unstable package set no longer supports this shell on `x86_64-darwin`.

## Agent Architecture

`.ai/` is the provider-neutral source. Its versioned policy, capability profiles, four role contracts, context routes, budgets, and deterministic scenarios compile into small runtime views.

| Role | Purpose | Access | Tier |
|---|---|---|---|
| Primary | Own intent, plan, integration, routine tests/docs, and delivery | Current session | Inherited |
| `scout` | Targeted repository evidence | Read-only | Fast |
| `researcher` | Current primary-source verification | Read + network | Balanced |
| `worker` | One bounded independent change | Workspace write | Balanced |
| `reviewer` | Independent correctness/security review | Read-only | Deep |

Codex role bindings follow the [official Sol/Terra/Luna guidance](https://learn.chatgpt.com/docs/models): Luna handles narrow repeatable scouting, Terra handles material research and bounded implementation, and Sol handles high-consequence review. Claude bindings map the same fast/balanced/deep intent to Haiku/Sonnet/Opus. The main model is deliberately not pinned, so the user's runtime choice remains authoritative. Provider names and tool syntax occur only in runtime bindings and adapters.

Routine bounded work stays Direct. Planned work loads `.ai/methodology.md`, forms a minimal evidence-backed domain brief, and continues through reversible ready steps without unnecessary questions. Hard work adds explicit risk gates and independent deep review. Delegation stays flat and is used only when isolation or parallelism helps.

For a complex low-latency dashboard, this gives the agent an end-to-end route: ground the domain and data semantics, retrieve only relevant knowledge with provenance, define API and latency contracts, implement the application, validate visualization and accessibility, profile the critical path, and prove behavior with risk-based tests. Actual autonomy still depends on access to the repository, required knowledge sources, and testable infrastructure; the template does not pretend missing credentials or product decisions are inferable.

## Skills

Generated projects discover only `agent-context`, which initializes, audits, or refreshes repository guidance. Twelve provider-neutral skills ship dormant under `.ai/catalog/` and add only a 553-token index when a Planned or Hard task needs specialist routing:

- Product/domain: `domain-modeling`, `frontend-design`, `data-visualization`, `interactive-playground`.
- Architecture/delivery: `api-contracts`, `migration-safety`, `test-design`.
- Knowledge/operations: `knowledge-integration`, `performance-engineering`, `incident-debugging`.
- Agent maintenance: `agent-evaluation`, `skill-authoring`.

Use `python .ai/tools/skillctl.py list` to inspect the catalog. Activate only procedures that will recur in the project; one-off tasks can read at most two relevant skill bodies directly. Activation is a reversible relative link into `.ai/skills/` and refuses to replace custom skills.

The disposition and evidence for every previous default skill are recorded in [the 2026-07-22 skill audit](docs/skill-audit-2026-07-22.md).

## Templates And Lifecycle

- `default` — language-neutral shell.
- `python` — Python 3.13 and `uv`.
- `rust` — stable Rust and Cargo tooling.

`template/` is the authored base. Python and Rust are generated mirrors with four explicit overlays: `AI.md`, `.ai/project.yaml`, `flake.nix`, and `.gitignore`.

- `nix run github:SPRAGE/dev-template#onboard` creates missing managed assets.
- `nix run github:SPRAGE/dev-template#sync-skills` refreshes owned skills but preserves existing neutral specs, compilers, provider outputs, and project guidance.
- `nix run github:SPRAGE/dev-template#migrate-v2` performs a dry-run v1 inventory; add `-- --apply` only after reviewing it.
- `nix run github:SPRAGE/dev-template#ai-doctor` validates layout, schema, budgets, links, and generated freshness.
- `nix run github:SPRAGE/dev-template#fresh-start` replaces managed assets after confirmation while preserving designated local runtime state and language flavor.

Normal sync still refuses to run the v2 compiler over a v1 project. `migrate-v2` is the explicit compatibility path: it accepts only fingerprinted, unchanged v1 core sources; carries project identity, context, and local state forward; removes only exact retired skills; preserves customized skills; compiles the staged target before swapping it; and keeps a recovery archive under `.ai/local/migrations/`. Semantic core customization stops before any change and requires manual reconciliation. Provider-asset sync is deliberately a separate command, so a migration never expands its transactional write set after the recoverable swap. `fresh-start` remains the confirmed replacement path.

The optional knowledge contract is equally conservative. Create `.ai/context/knowledge-sources.yaml` only when a real source exists; the compiler validates authority, freshness, tenant isolation, access, logical operations, and citations while provider bindings and credentials remain local.

## Maintainer Checks

```bash
nix develop path:. -c python template/.ai/generators/compile.py --root template
nix develop path:. -c bash tests/sync-template-shared.sh
nix develop path:. -c bash tests/test-agent-system.sh
nix develop path:. -c bash tests/test-template-sync.sh
nix develop path:. -c bash tests/test-skills.sh
nix develop path:. -c bash tests/test-apps.sh
nix develop path:. -c python tests/test-eval-harness.py
nix develop path:. -c bash tests/test-runtime-canary.sh
nix flake check path:. --all-systems --no-build --no-update-lock-file
```

Budgets enforce static context estimates for always-loaded guidance, planned routes, role catalogs, role contracts, and skills. The maintainer-side behavioral harness validates frozen paired records for eight representative task classes and computes outcome, token, latency, cost, and safety deltas without launching a model. No live trials were run in this change, so static size and deterministic contracts still do not prove superior judgment. The runtime canary invokes only the locked local CLIs' version/help paths and validates generated config shape; it does not start an agent session or query account-specific model availability.

Review [SECURITY.md](SECURITY.md) before using the defaults in sensitive or production repositories.
