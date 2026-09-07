# dev-template

Nix project templates with short, shared guidance for Codex and Claude Code. New projects contain **zero skills, zero custom roles, and no model or reasoning-effort pins**.

```bash
nix flake init -t github:SPRAGE/dev-template#rust  # #python or omit for the base
nix develop
```

Initialize the application with `cargo init` or `uv init`, replace `PROJECTNAME`, and record verified project commands and constraints in `AI.md`. `direnv allow` is optional; generated shells do not automatically load `.env` or `.env.mcp`.

For an existing repository, run `nix run github:SPRAGE/dev-template#onboard`. Run lifecycle commands from its project root, or pass `--root /path/to/project`.

## What a project receives

Ten files: `AI.md`, two provider entrypoints (`AGENTS.md` and `CLAUDE.md`), `flake.nix`, `.envrc`, `.gitignore`, native Claude permissions and a statusline hook, `.ai/context/.gitignore`, and `.ai/template.json` for file ownership. Only the selected provider entrypoint and `AI.md` are startup guidance. Real architecture, conventions, and other context load when relevant.

There is no project compiler, capability framework, route taxonomy, model tier table, role catalog, or skill index. Models handle ordinary engineering work; skills are useful when they add a concrete recurring project procedure or evidence the model cannot infer.

The shared guidance directs the primary agent to autonomously delegate bounded implementation in parallel when the coordination cost is justified, prefer available models explicitly identified as cheaper, review worker diffs, and verify integration. Architecture, planning, and final review stay with the primary. Stalled or difficult work is escalated.

This policy travels with every template and onboarding installation. Actual delegation and model selection depend on the host runtime's tools and permissions. A runtime with native subagents can follow the policy without custom role files. When cheaper models or delegation are unavailable, the agent works inline and reports the limitation. Optional roles inherit the current model until an explicit override is configured; installing roles alone does not establish cost savings.

## Optional workflows

Enable only what a project actually needs:

```bash
nix run github:SPRAGE/dev-template#agent-profile -- list
nix run github:SPRAGE/dev-template#agent-profile -- enable skill:agent-context
nix run github:SPRAGE/dev-template#agent-profile -- enable skill:frontend-design
nix run github:SPRAGE/dev-template#agent-profile -- enable roles
nix run github:SPRAGE/dev-template#agent-profile -- disable roles
```

`agent-context` maintains verified repository guidance. `frontend-design` requires a real design brief, project examples, and browser verification. Neither is installed by default. Performance, migration/recovery, and incident guidance lives in [project runbook templates](docs/workflows/) to fill with actual commands and system evidence.

The optional roles are `scout`, `researcher`, `worker`, and `reviewer`. They inherit runtime model choices. Explicit project model overrides are supported with `enable roles --overrides choices.json`; see the [runtime contract](docs/agent-runtime.md). Optional skills use one canonical `.ai/skills/<name>` copy, linked into the native Codex and Claude discovery paths.

## Updating and recovery

| App | Behavior |
|---|---|
| `onboard` | Add missing guidance and ownership state; preserve existing project files |
| `sync-skills` | Update unchanged owned files and enabled profiles; report customized files |
| `ai-doctor` | Check ownership, native formats, discovery, and startup budget |
| `agent-profile` | List, enable, or disable optional skills and roles |
| `migrate` | Preview v2-to-v3 changes; `--apply` performs the explicit upgrade |
| `migrate-v2` | Fingerprint-gated v1-to-v2 migration; required before upgrading v1 to v3 |
| `fresh-start` | Confirmed reset of agent guidance, `AI.md`, `.envrc`, and language flake; removes the lock |
| `agent-restore` | Restore a v3 lifecycle backup when affected files have not changed since |

Ordinary sync never upgrades a legacy schema. Explicit v2 migration preserves `AI.md`, context, project identity, custom skills, and runtime overrides. Unchanged dormant catalogs and their known activation CLI are retired; customized catalogs/tools or active catalog links preserve that workflow together. A customized core contract or provider adapter stops migration before edits; reconcile those instructions first. Project specification facts are retained in `.ai/context/legacy-project.yaml` for selective reference.

Changes are backed up under `.ai/local/dev-template/backups/<id>/backup.json`; backups are private and ignored by Git. Pass that path to `agent-restore`. Restoration checks for intervening edits and creates its own backup. The older `migrate-v2` command retains its recovery archive under `.ai/local/migrations/`. Resets preserve `.ai`, `.agents`, `.codex`, and `.claude` local/tmp/session/log directories plus `.claude/settings.local.json`.

## Maintaining this repository

Shared guidance lives in `maintainer/guidance.md`; `template/` owns shared project assets. Language templates have only three overlays: `AI.md`, `flake.nix`, and `.gitignore`. Validation, packaging, evaluation fixtures, and frozen v2 compatibility sources stay in this repository.

Inside `nix develop path:.`:

```bash
python tools/template.py generate
bash tests/sync-template-shared.sh
bash tests/test-agent-system.sh
bash tests/test-template-sync.sh
bash tests/test-skills.sh
bash tests/test-apps.sh
python tests/test-migrate-v2.py
python tests/test-eval-harness.py
bash tests/test-runtime-canary.sh
python tools/template.py stats --root template
nix flake check path:. --all-systems --no-build --no-update-lock-file
```

See the [redesign measurements](docs/template-efficiency-2026-09-07.md), [optional knowledge registry](docs/knowledge-sources.md), and [offline evaluation harness](docs/behavioral-evaluation.md). Static prompt reductions do not establish better model outcomes; promote optional workflows only after useful project evidence.

All four flakes retain the prebuilt official Codex release at `192.168.0.7` for `x86_64-linux`; ARM Linux and macOS use `pkgs.codex` from locked unstable nixpkgs. Generated projects need SSH access to that source when first locking or explicitly refreshing it. Supported systems remain `x86_64-linux`, `aarch64-linux`, and `aarch64-darwin`. See [SECURITY.md](SECURITY.md) for runtime boundaries.
