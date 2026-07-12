# Conventions

## Authoring

- Edit neutral agent behavior under `template/.ai/`; never hand-edit generated provider agents or adapters.
- Keep language differences to `AI.md`, `.ai/project.yaml`, `flake.nix`, and `.gitignore`.
- Keep always-loaded guidance factual and short; move procedures to skills and optional detail to references.
- Give every writable agent an explicit file scope and every agent a structured output contract.

## Verification

- Neutral/runtime changes: `bash tests/test-agent-system.sh`.
- Shared template changes: `bash tests/test-template-sync.sh`.
- Skill changes: regenerate archives, then `bash tests/test-skills.sh`.
- Lifecycle changes: `nix develop path:. -c bash tests/test-apps.sh`.
- Flake changes: `nix flake check path:. --all-systems --no-update-lock-file`.

## Safety

- Preserve local runtime state, customized project guidance, and unrelated worktree changes.
- Permission changes and destructive reset behavior require explicit user intent.
- Never put secrets or private credentials in generated guidance.
