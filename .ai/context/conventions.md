# Conventions

## Authoring

- Edit neutral behavior under `template/.ai/`, then regenerate; never hand-edit marked runtime outputs.
- Keep language differences to the four documented overlays.
- Keep default discovery small. Route task-local specialist guidance through `.ai/catalog/index.yaml`; activate it only for recurring work. Add a skill only for recurring judgment that passes trigger and with/without-skill evaluation; use scripts or hooks for deterministic work.
- Provider syntax belongs in runtime bindings, not shared policy, roles, or skill entry points.

## Verification

- Agent/runtime: `nix develop path:. -c bash tests/test-agent-system.sh`.
- Mirrors: `nix develop path:. -c bash tests/test-template-sync.sh`.
- Skills/archives: `nix develop path:. -c bash tests/test-skills.sh`.
- Lifecycle: `nix develop path:. -c bash tests/test-apps.sh`.
- Evaluation records: `nix develop path:. -c python tests/test-eval-harness.py`.
- Runtime canary: `nix develop path:. -c bash tests/test-runtime-canary.sh`.
- Nix outputs: `nix flake check path:. --all-systems --no-build --no-update-lock-file`.

## Preservation

Preserve local runtime state, customized project guidance, and unrelated changes. A refresh may create missing generated files but must not replace existing provider output or run a new compiler against an older schema.
