# dev-template

Nix project templates with concise project guidance and no default skills, custom roles, or model pins.

`template/` is the base; Python and Rust differ only in `AI.md`, `flake.nix`, and `.gitignore`. Shared behavior is authored in `maintainer/guidance.md`. Optional skills, role contracts, and provider bindings live under `optional/`. Tools and legacy compatibility fixtures stay in this repository, outside generated projects. This maintainer checkout explicitly enables `agent-context`.

## Commands

Inside `nix develop path:.`:

- `python tools/template.py generate` — refresh adapters, manifests, and maintainer guidance.
- `bash tests/sync-template-shared.sh` — mirror shared files.
- `bash tests/test-agent-system.sh` — v3 lifecycle and legacy compatibility contracts.
- `bash tests/test-template-sync.sh` — parity, local-state preservation, and Nix contracts.
- `bash tests/test-skills.sh` — optional skills and deterministic archives.
- `bash tests/test-apps.sh` — exercise the Nix lifecycle entrypoints.
- `python tests/test-migrate-v2.py` — legacy migration recovery.
- `python tests/test-eval-harness.py` — offline evaluation records.
- `bash tests/test-runtime-canary.sh` — local CLI and optional-role compatibility.
- `python tools/template.py stats --root template` — static context estimates.

Use `nix flake check path:. --all-systems --no-build --no-update-lock-file` for all-system evaluation. Add `--offline` for cached local checks.

Preserve project customization, local runtime state, and unrelated work. The retained official Codex release serves `x86_64-linux`; ARM Linux and macOS use locked unstable nixpkgs. Source validation does not authorize dataserver access or deployment.
