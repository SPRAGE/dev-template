# Conventions

Edit shared behavior in `maintainer/guidance.md`; keep provider syntax in `optional/runtime-bindings.json`. `template/` owns project assets, with only `AI.md`, `flake.nix`, and `.gitignore` differing in language mirrors. Regenerate with `python tools/template.py generate` and `bash tests/sync-template-shared.sh`.

New projects have no default skills, roles, model pins, or compiler. Keep reusable workflow sources under `optional/`, deterministic utilities under `tools/`, and project-specific facts in `AI.md` or conditional context. Shared guidance carries autonomous delegation, cheaper-model preference, and primary review into downstream projects; runtime capabilities and model availability still govern execution. Startup estimates include native role and skill discovery.

Run the checks documented in `AI.md`. Preserve customization, project identity, unrelated changes, and local runtime state. Sync does not upgrade legacy schemas. Migration must preflight, preserve complete custom skill trees, and provide tested recovery. Never infer permission to access the dataserver from source-validation work.
