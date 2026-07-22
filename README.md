# dev-template

Lean Nix project templates with one provider-neutral agent specification compiled into Codex and Claude Code runtimes.

The template keeps the primary agent responsible for intent, domain grounding, planning, integration, routine verification, and the final answer. Four optional roles isolate noisy reads, external research, independent edits, and high-consequence review. Only one skill is discovered by default; a dormant specialist catalog is loaded selectively.

## Quick Start

```bash
nix flake init -t github:SPRAGE/dev-template#rust  # or #python; omit for the base template
direnv allow                                        # optional
```

Initialize the language project, replace `PROJECTNAME`, and ask for an outcome in plain language. Invoke `agent-context` after real code exists to record verified commands and architecture.

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
| `researcher` | Current primary-source verification | Read + network | Fast |
| `worker` | One bounded independent change | Workspace write | Balanced |
| `reviewer` | Independent correctness/security review | Read-only | Deep |

Codex role bindings use the current official Luna/Terra/Sol tier identifiers; Claude bindings map fast/balanced/deep to Haiku/Sonnet/Opus. The main Codex model is deliberately not pinned in project config, so the user's current runtime choice remains authoritative. Provider names and tool syntax occur only in runtime bindings and adapters.

Routine bounded work stays Direct. Planned work loads `.ai/methodology.md`, forms a minimal evidence-backed domain brief, and continues through reversible ready steps without unnecessary questions. Hard work adds explicit risk gates and independent deep review. Delegation stays flat and is used only when isolation or parallelism helps.

For a complex low-latency dashboard, this gives the agent an end-to-end route: ground the domain and data semantics, retrieve only relevant knowledge with provenance, define API and latency contracts, implement the application, validate visualization and accessibility, profile the critical path, and prove behavior with risk-based tests. Actual autonomy still depends on access to the repository, required knowledge sources, and testable infrastructure; the template does not pretend missing credentials or product decisions are inferable.

## Skills

Generated projects discover only `agent-context`, which initializes, audits, or refreshes repository guidance. Twelve provider-neutral skills ship dormant under `.ai/catalog/` and add only a 699-token index when a Planned or Hard task needs specialist routing:

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

- `nix run .#onboard` creates missing managed assets.
- `nix run .#sync-skills` refreshes owned skills but preserves existing neutral specs, compilers, provider outputs, and project guidance.
- `nix run .#ai-doctor` validates layout, schema, budgets, links, and generated freshness.
- `nix run .#fresh-start` replaces managed assets after confirmation while preserving designated local runtime state and language flavor.

This is intentionally a breaking schema-v2 release, not an automatic in-place v1 migration. Sync refuses to run the new compiler over a v1 project. Existing consumers must either reconcile their neutral source manually and regenerate provider views, or version-control their local guidance and use `fresh-start`, which replaces the managed agent setup and project flake after confirmation.

## Maintainer Checks

```bash
nix develop path:. -c python template/.ai/generators/compile.py --root template
nix develop path:. -c bash tests/sync-template-shared.sh
nix develop path:. -c bash tests/test-agent-system.sh
nix develop path:. -c bash tests/test-template-sync.sh
nix develop path:. -c bash tests/test-skills.sh
nix develop path:. -c bash tests/test-apps.sh
nix flake check path:. --all-systems --no-build --no-update-lock-file
```

Budgets enforce static context estimates for always-loaded guidance, planned routes, role catalogs, role contracts, and skills. Those measurements prove smaller files and deterministic policy behavior—not superior model judgment. Representative with/without-runtime task evaluations remain the honest next step for reasoning-quality claims.

Review [SECURITY.md](SECURITY.md) before using the defaults in sensitive or production repositories.
