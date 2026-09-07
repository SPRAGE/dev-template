# Agent Runtime Contract

V3 projects have no default skills, custom roles, project compiler, model pins, or effort overrides. Their selected provider entrypoint contains concise shared execution guidance and reads `AI.md` for project facts. Relevant context loads on demand. The primary owns planning and integration; independent review remains appropriate for consequential changes.

## Downstream delegation policy

Every generated provider entrypoint directs the primary agent to own planning, architecture, integration, and final review. It can autonomously delegate bounded, independent implementation in parallel when coordination cost is justified, supplying relevant context, file ownership, interfaces, and acceptance checks. Prefer an available model explicitly identified as cheaper; inspect actual diffs and verify the integrated result. Escalate stalled or difficult work and obtain independent review for consequential changes.

This is portable agent guidance, not a scheduler or a provider capability. The runtime must expose subagents and supported model choices. Native subagent tools can follow the policy without the optional role profile. If cheaper model selection or delegation is unavailable, work inline and report the limitation. Do not infer lower cost from parallelism, a role name, or inherited model settings. Named-role runtimes can use the explicit overrides below to select an appropriate worker model. Configuration, review, and tests do not prove actual cost savings; representative runs are needed for that.

## Source and optional profiles

`maintainer/guidance.md` generates provider entrypoints through `tools/template.py`. `template/` supplies shared project assets; Python and Rust have only `AI.md`, `flake.nix`, and `.gitignore` overlays. Maintainer tooling and `compat/v2/` are never copied into new projects.

`agent-profile enable roles` renders `optional/roles.yaml` using `optional/runtime-bindings.json`:

| Role | Access | Codex sandbox | Claude permission mode |
|---|---|---|---|
| scout | Repository read | read-only | plan |
| researcher | Read and external research | read-only | plan |
| worker | Bounded workspace edits | workspace-write | acceptEdits |
| reviewer | Independent read | read-only | plan |

Role files omit model and reasoning-effort fields by default, leaving selection to the runtime. To choose models explicitly, create a project-owned JSON file and use `agent-profile enable roles --overrides choices.json`:

```json
{
  "codex": {"worker": {"model": "your-model-id", "model_reasoning_effort": "low"}},
  "claude": {"reviewer": {"model": "inherit"}}
}
```

Only known role names and model/effort keys are accepted; this interface cannot expand permissions. Availability of an explicitly chosen model is the project's responsibility. No local canary contacts a model endpoint.

`skill:agent-context` and `skill:frontend-design` copy manifest-allowlisted sources into `.ai/skills/` and link only the selected skill into `.agents/skills/` and `.claude/skills/`. Existing canonical discovery links remain valid. Disabling a profile refuses to remove customized files; it never silently removes a project's changes.

## Ownership and recovery

`.ai/template.json` records version 3, selected profiles, explicit overrides, a startup budget, and fingerprints of owned files. It is bookkeeping, not prompt context. Routine sync updates missing or unchanged owned assets. It preserves modified collisions and always preserves `AI.md`, the application's flake, local settings, context, and source code. Enabling or disabling a profile preflights all its changes.

Transactions snapshot affected files and symlinks before edits, use atomic replacement per file, and roll back caught failures. Backups have private permissions and their own Git ignore rule under `.ai/local/dev-template/backups/`. This provides recovery from command failures, not an atomic filesystem snapshot across power loss. `agent-restore` refuses intervening edits and backs up the restoration itself.

V2 upgrades are explicit: `migrate` previews, `migrate --apply` applies. Known framework sources and generated defaults are retired; unknown core changes or customized adapters stop before mutation. Preserve project identity in `.ai/context/legacy-project.yaml`, all context, customized skill trees as complete units, catalog activation targets, and customized native output. A complete unchanged dormant catalog and its known activation CLI are retired; custom content/tools or active canonical/native links preserve the catalog and tool together. V1 still uses the frozen, tested `migrate-v2` route first.

`fresh-start` resets agent assets, `AI.md`, `.envrc`, and the selected language flake and removes `flake.lock`. It requires confirmation or `--yes`; application files and designated provider-local state survive. `--flavor default|python|rust` overrides language detection.

## Measurements and verification

`python tools/template.py stats --root template` is read-only. The estimator is `ceil(max(UTF-8 bytes / 4, whitespace words * 1.3))` per surface. Startup counts `AI.md`, the larger provider entrypoint, and discovered role and skill names/descriptions. Duplicate runtime views are not summed. Loaded skill bodies, project context, runtime wrappers, tool schemas, and conversation history remain additional costs.

New projects budget 900 estimated startup tokens. Edit `startup_budget` in `.ai/template.json` deliberately as real project facts grow. `ai-doctor` checks the budget against the actual files, including custom role/skill discovery. Estimates cannot establish billing, latency, or model quality improvements.

Regression checks cover minimal onboarding, customization and local-state preservation, native discovery and permissions, store-file modes, profile collisions, explicit overrides, fingerprint migration, recovery, injected failure rollback, and unsafe paths/symlinks. The runtime canary validates installed CLI version/help and local formats with no network/model calls. Legacy compiler/registry contracts remain tested against an isolated compatibility fixture.
