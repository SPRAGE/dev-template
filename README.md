# dev-template

Nix flake templates for scaffolding projects with provider-neutral AI context, shared skills, Claude Code settings/hooks, Codex repo skills, and Codex-compatible guidance baked in.
Generated projects include `AI.md` and `.ai/` as the shared guidance base, `.agents/skills/` for official Codex skill discovery, and `AGENTS.md`, `CODEX.md`, and `CLAUDE.md` as provider-specific compatibility adapters.

## Quick start

```bash
nix flake init -t github:SPRAGE/dev-template#rust    # or #python, or omit suffix for base
# Replace PROJECTNAME in .ai/instructions.md, AI.md, AGENTS.md, CODEX.md, and flake.nix
direnv allow                                           # optional, if using direnv
```

For an existing repository:

```bash
nix run github:SPRAGE/dev-template#onboard
```

To reset an existing repository back to current dev-template defaults, including replacing `flake.nix` and removing `flake.lock` so it can be regenerated:

```bash
nix run --refresh github:SPRAGE/dev-template#fresh-start
```

Then read `AI.md` and `.ai/instructions.md`. In Claude Code, run `/cc-setup` to scan the codebase and generate project-specific guidance. In Codex, request the same skills by name; Codex discovers checked-in skills from `.agents/skills/`, while `.ai/skills/` remains the provider-neutral source.

## Templates

- `default` — language-agnostic Nix devShell with Claude Code, Codex, and Node.js for MCP servers.
- `rust` — Rust stable toolchain via rust-overlay, cargo tools, OpenSSL/pkg-config, Claude Code, and Codex.
- `python` — Python 3.13, uv, Claude Code, and Codex.

Each template includes:

- `.claude/settings.json` — default plugins, permissions, hooks, and status line.
- `.claude/hooks/` — session-start and statusline scripts.
- `.ai/` — provider-neutral instructions, active context, architecture snapshot, conventions, decisions, and stale-log templates.
- `.ai/skills/` — shared skill catalog for Codex-compatible agents, Claude Code, and future agents.
- `.agents/skills/` — official Codex repo-scoped skill path, symlinked to `.ai/skills/`.
- `.claude/skills/` — Claude Code slash-command skill path, symlinked to `.ai/skills/`.
- `.codex/config.toml` and `.codex/agents/` — trusted Codex project defaults and custom subagents.
- `.codex/skills/` — compatibility skill path symlinked to `.ai/skills/`, for tools that still look under `.codex/`.
- `AI.md` — provider-agnostic top-level project guide for all agents.
- `AGENTS.md` — Codex-compatible auto-load adapter.
- `CODEX.md` — named Codex adapter alias for humans and tools.
- `CLAUDE.md` — Claude Code compatibility adapter that points to `AI.md` and `.ai/`.
- `.mcp.json` — Context7 MCP server configuration.

## Repository commands

- `nix flake check --all-systems` — validate flake outputs.
- `nix flake init -t .` — test the default template locally.
- `nix flake init -t .#rust` — test the Rust template locally.
- `nix flake init -t .#python` — test the Python template locally.
- `nix run .#onboard` — bootstrap `AI.md`, shared AI context, shared skills, adapters, Codex repo skill links/config/custom agents, and Claude Code config into an existing project.
- `nix run .#sync-skills` — pull latest shared skills, managed adapters, Codex skill links, Codex config/custom agents, Claude skill links, hooks, and missing AI context templates into any repo.
- `nix run .#fresh-start` — reset `flake.nix`, `AI.md`, shared AI context, Codex skill links/config/custom agents, and Claude Code config from template defaults; remove `flake.lock` for regeneration; preserve auto-memory and `.agents/local/`/`.codex/local/` runtime state.
- `nix run .#ai-doctor` — validate AI context files, shared skills, provider skill links, hooks, and skill layout in the current project.
- `nix develop -c bash tests/test-apps.sh` — smoke test flake apps.
- `nix develop -c bash tests/test-skills.sh` — validate skills and `skills/*.skill` archives.

## Skill archives

Distributable `skills/*.skill` files are generated from `template/.ai/skills/`. Treat the shared skill catalog as the source of truth, keep `.agents/skills/`, `.claude/skills/`, and `.codex/skills/` linked to `.ai/skills/`, regenerate archives after changing skills, and run `tests/test-skills.sh` before committing.

## Refreshing Existing Repos

Run this from any project root to pull the latest dev-template-managed assets:

```bash
nix run github:SPRAGE/dev-template#sync-skills
```

The sync updates shared skills, provider skill links, Codex config/custom agents, hooks, and managed provider adapters. It adds missing `AI.md`, `.ai/` templates, `.agents/README.md`, `.codex/README.md`, `.codex/config.toml`, `.codex/agents/`, `AGENTS.md`, `CODEX.md`, and `CLAUDE.md`, but preserves customized project guidance and populated `.ai/context/` files. Existing skills found under provider-specific skill directories are migrated into `.ai/skills/` before replacing provider skill directories with links.

## Security

Review [SECURITY.md](SECURITY.md) before using these templates in production. Pin upstream flake inputs and tighten Claude Code permissions for sensitive projects.
