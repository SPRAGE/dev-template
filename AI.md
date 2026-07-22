# dev-template

Nix templates that compile provider-neutral repository policy and skills into small runtime adapters for Codex and Claude Code.

## Commands

- `nix flake check path:. --all-systems --no-build --no-update-lock-file` — evaluate every emitted system and package.
- `nix develop path:. -c bash tests/test-agent-system.sh` — validate schemas, route budgets, and generated runtimes.
- `nix develop path:. -c bash tests/test-template-sync.sh` — enforce base-plus-overlay template generation.
- `nix develop path:. -c bash tests/test-skills.sh` — validate default/optional skills and archives.
- `nix develop path:. -c bash tests/test-apps.sh` — exercise onboard, sync, reset, and doctor lifecycles.
- `nix develop path:. -c python tests/test-eval-harness.py` — validate zero-credit paired evaluation records.
- `nix develop path:. -c bash tests/test-runtime-canary.sh` — check locked CLIs and generated runtime bindings without model calls.
- `nix develop path:. -c bash tests/sync-template-shared.sh` — regenerate language mirrors after base changes.

## Architecture

- `template/` is the authored base; `templates/{python,rust}/` are generated shared files plus four language overlays.
- `template/.ai/` owns neutral policy, capabilities, roles, context, the default skill, eval fixtures, and compiler.
- `template/.codex/` and `template/.claude/agents/` are generated runtime bindings.
- `skill-catalog/` contains opt-in skills; `skills/*.skill` are deterministic archives.
- `flake.nix` exports the templates and lifecycle apps. Codex comes directly from the locked unstable nixpkgs input.

## Boundaries

Edit neutral sources before generated outputs and regenerate every affected mirror. Language differences are limited to `AI.md`, `.ai/project.yaml`, `flake.nix`, and `.gitignore`. Preserve unrelated work plus `.codex/local/`, `.agents/local/`, and provider-local settings. Never publish private endpoints or credentials.
