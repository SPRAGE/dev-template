# Architecture Snapshot

## Source and generation

- `template/` is the authored language-neutral project; Python and Rust variants mirror it except for `AI.md`, `.ai/project.yaml`, `flake.nix`, and `.gitignore`.
- `.ai/policy.yaml`, capabilities, four role contracts, and runtime maps are neutral sources. The compiler validates schema version 2, budgets the common routes, and emits readable guidance plus runtime adapters.
- The primary owns planning, integration, routine testing, and documentation. `scout`, `researcher`, `worker`, and `reviewer` provide context isolation or independent work.
- One default `agent-context` skill is discovered in generated projects. Twelve dormant specialist skills live under `template/.ai/catalog/`; its 699-token index routes at most two procedures per task, and `skillctl.py` safely activates recurring ones.

## Packaging

- The root flake emits `x86_64-linux`, `aarch64-linux`, and `aarch64-darwin`; the locked unstable nixpkgs supplies Codex directly.
- Lifecycle apps onboard, sync, reset, and diagnose managed assets, including the dormant catalog and activation tool. Sync preserves existing compilers and provider outputs; schema upgrades require an explicit migration.
- Skill archives contain only manifest allowlisted files with deterministic metadata.

## Flow

1. Edit neutral sources or an explicit language overlay.
2. Compile the base and maintainer runtime.
3. Generate language mirrors and compile each variant.
4. Package default and optional skills.
5. Run contract, template, skill, lifecycle, and flake checks.
