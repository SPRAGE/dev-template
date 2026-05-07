# dev-template

Nix flake templates for scaffolding projects with provider-neutral AI context, Claude Code skills/settings, hooks, and Codex-compatible guidance baked in.
Generated projects include `.ai/` as the shared context base, with `AGENTS.md` and `CLAUDE.md` as provider-specific adapters.

## Quick start

```bash
nix flake init -t github:SPRAGE/dev-template#rust    # or #python, or omit suffix for base
# Replace PROJECTNAME in .ai/instructions.md, CLAUDE.md, AGENTS.md, and flake.nix
direnv allow                                           # optional, if using direnv
```

For an existing repository:

```bash
nix run github:SPRAGE/dev-template#onboard
```

Then read `.ai/instructions.md`. In Claude Code, run `/cc-setup` to scan the codebase and generate project-specific guidance.

## Templates

- `default` — language-agnostic Nix devShell with Claude Code and Node.js for MCP servers.
- `rust` — Rust stable toolchain via rust-overlay, cargo tools, OpenSSL/pkg-config, Claude Code.
- `python` — Python 3.13, uv, Claude Code.

Each template includes:

- `.claude/settings.json` — default plugins, permissions, hooks, and status line.
- `.claude/hooks/` — session-start and statusline scripts.
- `.claude/skills/` — planner, cc-setup, cc-refresh, fresh-start, frontend-design, playground, skill-creator, and virtual-tech-org.
- `.ai/` — provider-neutral instructions, active context, architecture snapshot, conventions, decisions, and stale-log templates.
- `AGENTS.md` — cross-agent guidance for Codex-compatible assistants.
- `CLAUDE.md` — Claude Code adapter that points back to `.ai/`.
- `.mcp.json` — Context7 MCP server configuration.

## Repository commands

- `nix flake check --all-systems` — validate flake outputs.
- `nix flake init -t .` — test the default template locally.
- `nix flake init -t .#rust` — test the Rust template locally.
- `nix flake init -t .#python` — test the Python template locally.
- `nix run .#onboard` — bootstrap shared AI context and Claude Code config into an existing project.
- `nix run .#sync-skills` — sync skills, hooks, and AI context templates into a project.
- `nix run .#fresh-start` — reset shared AI context and Claude Code config from template defaults while preserving auto-memory.
- `nix run .#ai-doctor` — validate AI context files, hooks, and skill layout in the current project.
- `nix develop -c bash tests/test-apps.sh` — smoke test flake apps.
- `nix develop -c bash tests/test-skills.sh` — validate skills and `.skill` archives.

## Skill archives

Root `*.skill` files are distributable archives generated from `template/.claude/skills/`. Treat the directories as the source of truth, regenerate archives after changing skills, and run `tests/test-skills.sh` before committing.

## Security

Review [SECURITY.md](SECURITY.md) before using these templates in production. Pin upstream flake inputs and tighten Claude Code permissions for sensitive projects.
