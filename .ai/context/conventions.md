# Conventions

## Code Style

- Keep template files concise and explicit.
- Prefer exact commands over prose descriptions.
- Keep shared top-level guidance in `AI.md`.
- Keep provider-neutral context under `.ai/`.
- Keep provider adapters thin and pointed at `AI.md` plus `.ai/`.
- Keep shared skill sources under `template/.ai/skills/`.
- Keep Codex repo skills available under `template/.agents/skills/` as a link to `template/.ai/skills/`.
- Keep Claude Code runtime files under `.claude/`.
- Keep Codex project config and custom agents under `.codex/`.

## Testing

- Run `nix flake check --all-systems` for flake output changes.
- Run `nix develop -c bash tests/test-apps.sh` for app behavior changes.
- Run `nix develop -c bash tests/test-skills.sh` after changing skill source files.

## Commands

- `nix flake check --all-systems` - validate flake outputs.
- `nix run .#ai-doctor` - validate AI context files and provider-specific settings layout.

## Git / Review

- Do not overwrite user-local settings or runtime files.
- Regenerate `skills/*.skill` archives and keep `.agents`, `.claude`, and `.codex` skill links intact whenever `template/.ai/skills/` changes.

## Security / Secrets

- Never commit `.env*`, tokens, private keys, or local credentials.
- Agents may recommend permission changes, but humans should own permission changes.
