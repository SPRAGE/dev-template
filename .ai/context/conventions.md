# Conventions

## Code Style

- Keep template files concise and explicit.
- Prefer exact commands over prose descriptions.
- Keep provider-neutral context under `.ai/`.
- Keep Claude Code runtime files under `.claude/`.

## Testing

- Run `nix flake check --all-systems` for flake output changes.
- Run `nix develop -c bash tests/test-apps.sh` for app behavior changes.
- Run `nix develop -c bash tests/test-skills.sh` after changing skill source files.

## Commands

- `nix flake check --all-systems` - validate flake outputs.
- `nix run .#ai-doctor` - validate AI context files and provider-specific settings layout.

## Git / Review

- Do not overwrite user-local settings or runtime files.
- Regenerate root `.skill` archives whenever `template/.claude/skills/` changes.

## Security / Secrets

- Never commit `.env*`, tokens, private keys, or local credentials.
- Agents may recommend permission changes, but humans should own permission changes.
