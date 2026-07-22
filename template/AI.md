# PROJECTNAME

TODO replace this line with a one-sentence description of the project and its users.

## Start

1. Replace `PROJECTNAME` in `AI.md`, `.ai/project.yaml`, and `flake.nix`.
2. Run `direnv allow` or `nix develop`.
3. Ask for the first outcome in plain language. The agent workflow will inspect, plan when needed, execute, and verify.
4. Invoke `agent-context` after source code exists to replace starter facts with repository evidence.

## Stack

- Nix development shell.
- Language and application stack not chosen yet.

## Commands

- `nix develop` - enter the development environment.
- `nix flake check` - validate the project flake.
- `nix run github:SPRAGE/dev-template#ai-doctor` - validate agent guidance and runtime assets.
- `nix run github:SPRAGE/dev-template#sync-skills` - refresh managed agent assets while preserving project guidance.

## Layout

- `.ai/` - neutral agent specification, project context, and the default shared skill.
- `.ai/catalog/` - conditional domain skills; consult its index for Planned or Hard work.
- `.agents/skills/` - Codex skill discovery link.
- `.claude/` - Claude Code agents and native settings.
- `.codex/` - Codex agents and native settings.

## Project Facts

- Add real entry points, exact build/test/lint commands, and non-obvious constraints here.
- Keep procedures in skills and rolling work in `.ai/context/active-context.md`, created only when needed.
