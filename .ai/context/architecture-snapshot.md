# Architecture Snapshot

`template/` contains ten project files. Python and Rust mirror shared assets with three overlays: `AI.md`, `flake.nix`, and `.gitignore`. Shared instructions originate in `maintainer/guidance.md`; generated projects carry no policy/capability framework or compiler.

`tools/template.py` maintains file ownership, adapters, optional profiles, startup estimates, onboarding/sync, explicit v2-to-v3 migration, confirmed reset, and recovery. Nix apps are thin wrappers. Transactions preflight fingerprints and symlink parents, preserve customized/local state, back up affected assets, and roll back caught failures. Frozen `compat/v2/` supports the independently tested v1-to-v2 migration.

`optional/skills/` contains agent-context and frontend-design. Neither is default; this maintainer checkout explicitly selects agent-context. Shared guidance directs autonomous delegation and cheaper-model preference when supported by the runtime. Optional roles inherit models unless a project supplies explicit overrides. Native access/tool bindings stay separate from shared role instructions. Skill archives use deterministic metadata and manifest allowlists.

The flake supports x86_64-linux, aarch64-linux, and aarch64-darwin. Primary Linux uses the retained official Codex release; ARM Linux/macOS use locked unstable nixpkgs. No source check implies deployment or dataserver access.

Evaluation tooling stays outside generated projects. Offline record validation and zero-network CLI canaries do not prove live model availability or improved task outcomes.
