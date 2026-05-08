# AI.md

## Project

dev-template - Nix flake templates for scaffolding projects with provider-neutral AI context, shared skills, Claude Code runtime support, and Codex-compatible adapters.

## Prerequisites

- Nix with flakes enabled
- direnv (optional but recommended)

## Structure

- `template/` - base template (language-agnostic devShell)
- `templates/rust/` - Rust template with rust-overlay, cargo tools
- `templates/python/` - Python template with uv
- `.ai/` - provider-neutral context for this repository
- `template/.ai/` - provider-neutral context seeded into generated projects
- `template/.ai/skills/` - shared skill catalog for all agents
- `skills/*.skill` - distributable skill archives for manual installation
- `template/.claude/hooks/` - Claude Code hook scripts (session-start, statusline)
- `template/.agents/skills/` - official Codex repo-scoped skill link to `template/.ai/skills/`
- `template/.claude/skills/` - Claude Code skill link to `template/.ai/skills/`
- `template/.codex/config.toml` and `template/.codex/agents/` - Codex project defaults and custom subagents
- `template/.codex/skills/` - Codex compatibility skill link to `template/.ai/skills/`
- `AGENTS.md`, `CODEX.md`, and `CLAUDE.md` - provider-specific compatibility adapters

## Source of Truth

- `.ai/` is the shared AI context for this repository.
- `AI.md` is the shared top-level guide for all agents.
- `template/.ai/` is the provider-neutral context seeded into generated projects.
- `template/` is the base template. Keep common AI assets here first.
- `templates/python/` and `templates/rust/` are language-specific templates. Keep shared files aligned with `template/` unless the stack needs different guidance.
- `template/.ai/skills/` is the source for shared skills.
- `template/.agents/skills/` is the official Codex repo-scoped link to `template/.ai/skills/`.
- `template/.claude/skills/` is the Claude Code skill link to `template/.ai/skills/`.
- `template/.codex/` contains Codex project config, custom agents, and a compatibility skill link.
- `skills/*.skill` archives must match `template/.ai/skills/`.
- `tests/` protects app behavior, template sync, and skill archive freshness.

Each template bundles:
- **Claude Code** - AI coding assistant via `github:sadjow/claude-code-nix`
- **Codex** - AI coding assistant available in the dev shell
- **virtual-tech-org** skill - staged delivery workflow using agent roles and project state
- **planner** skill - project and feature planning companion
- **cc-setup** skill - generate or refresh shared project guidance
- **cc-refresh** skill - audit and refresh shared AI context and provider adapters
- **frontend-design** skill - production-grade frontend interfaces
- **fresh-start** skill - reset AI config and restore dev-template defaults
- **skill-creator** skill - create, test, and package skills
- **playground** skill - interactive HTML playgrounds for visual exploration

## Shared AI Context

All agents should treat `.ai/` as the shared context source:

1. `.ai/instructions.md`
2. `.ai/context/active-context.md`
3. `.ai/context/architecture-snapshot.md`
4. `.ai/context/conventions.md`
5. `.ai/context/decisions.md`

Provider-specific settings remain in provider-specific files such as `.claude/settings.json`.
Shared skills live under `.ai/skills/`; Codex discovers repo-scoped skills from `.agents/skills/`, Claude Code uses `.claude/skills/` for slash commands, and `.codex/skills/` remains a compatibility path. Provider skill paths are symlinks to `.ai/skills/`, so additions are shared across provider views.

## Commands

- `nix flake check` - validate the flake
- `nix flake init -t .` - test default template
- `nix flake init -t .#rust` - test rust template
- `nix flake init -t .#python` - test python template
- `nix run .#sync-skills` - sync latest shared skills, managed adapters, provider skill links, Codex config/custom agents, hooks, and missing AI context templates into the current project
- `nix run .#onboard` - bootstrap shared AI context, shared skills, managed adapters, Codex repo skills/config/custom agents, and Claude Code onto an existing project
- `nix run .#fresh-start` - reset AI, Codex, and Claude Code config from template defaults
- `nix run .#ai-doctor` - validate AI context files, shared skills, provider skill links, hooks, and skill layout
- `nix develop -c bash tests/test-apps.sh` - smoke test flake apps
- `nix develop -c bash tests/test-skills.sh` - validate skills and distributable archives

## Workflow

1. `nix flake init -t github:SPRAGE/dev-template#rust` (or `#python`, or default)
2. Replace `PROJECTNAME` in generated project files
3. `direnv allow`
4. Open Claude Code or Codex.
   - Claude Code: use `/virtual-tech-org`, or `/planner` -> `/cc-setup` -> `/planner`.
   - Codex-compatible agents: ask to use the same skill by name; Codex discovers repo skills from `.agents/skills/`, while `AGENTS.md` points agents back to `.ai/skills/` as the provider-neutral source.
5. For existing repos, run `nix run .#onboard`, then use `cc-setup` to scan and configure guidance.
6. Use `cc-refresh` periodically to clean up stale context.

## Conventions

- All templates use `nixpkgs-unstable` and `flake-utils.eachDefaultSystem`.
- `PROJECTNAME` is the placeholder token.
- Claude Code and Codex are included in every template's devShell.
- Common inspection tools (`rg`, `fd`, `jq`, `tree`) are included in every template's devShell.
- Keep templates minimal; skills handle project-specific customization.
- Skills are sourced from `template/.ai/skills/`; provider skill paths link there.
- `skills/*.skill` archives should be regenerated whenever source skills change.

## Working Rules

- Preserve user-local files such as `.claude/settings.local.json`, `.env*`, `.agents/local/`, `.agents/tmp/`, `.codex/local/`, and `.codex/tmp/`.
- Keep shared project context in `.ai/`; keep provider-specific settings in provider-specific folders.
- Keep shared top-level guidance in `AI.md`; keep `AGENTS.md`, `CODEX.md`, and `CLAUDE.md` as compatibility adapters.
- If you change a skill source, keep the `.agents`, `.claude`, and `.codex` skill links aligned, regenerate its archive under `skills/`, and run `tests/test-skills.sh`.
- If you change an app in `flake.nix`, add or update coverage in `tests/test-apps.sh` or `tests/test-onboard.sh`.
- Do not hardcode secrets, tokens, local absolute paths, or organization-private values into templates.
- Prefer exact, copy-paste-ready commands in docs and generated guidance.
