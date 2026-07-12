# dev-template

Nix templates that compile a provider-neutral agent specification into efficient Codex and Claude project runtimes.

## Stack

- Nix flakes for templates, packages, and lifecycle apps.
- Bash for app/test orchestration.
- Python plus PyYAML for neutral-spec validation and provider artifact generation.
- Markdown and YAML for project facts, skills, capabilities, and agent contracts.

## Commands

- `nix flake check --all-systems` - validate flake outputs.
- `bash tests/test-agent-system.sh` - validate contracts, token budgets, model pins, and generated artifacts.
- `bash tests/test-template-sync.sh` - enforce base-template plus overlay generation.
- `nix develop -c bash tests/test-skills.sh` - validate skill sources and archives.
- `nix develop -c bash tests/test-apps.sh` - exercise onboard, sync, reset, and doctor apps.
- `bash tests/sync-template-shared.sh` - regenerate Python/Rust shared files and runtime artifacts.
- `python template/.ai/generators/compile.py --root template` - compile the base runtime.

## Architecture

- `template/` - authored language-neutral template and neutral agent source.
- `templates/{python,rust}/` - generated shared files plus four explicit language overlays.
- `template/.ai/` - policy, capabilities, agents, model tiers, context, skills, eval fixtures, and compiler.
- `template/.codex/` and `template/.claude/agents/` - generated provider artifacts.
- `flake.nix` - template exports and lifecycle apps: `onboard`, `sync-skills`, `fresh-start`, `ai-doctor`.
- `skills/*.skill` - distributable archives generated from `template/.ai/skills/`.
- `tests/` - generation, contract, archive, and app behavior checks.

## Source Boundaries

- Edit neutral behavior in `template/.ai/`, then compile and sync variants.
- Edit provider-native settings only in their provider directories.
- Treat generated files bearing the compiler marker as outputs, not sources.
- Keep language differences limited to `AI.md`, `.ai/project.yaml`, `flake.nix`, and `.gitignore`.
- Regenerate skill archives after any skill source change.

## Working Rules

- Preserve user-local state and unrelated changes, especially `.claude/settings.local.json`, `.agents/local/`, and `.codex/local/`.
- Do not hardcode secrets or organization-private endpoints into public template defaults.
- Keep the Codex/Claude topology flat and enforce model tiers through the neutral runtime maps.
- Add or update tests whenever lifecycle app behavior, generated contracts, or template propagation changes.
