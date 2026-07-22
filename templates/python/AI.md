# PROJECTNAME

TODO replace this line with a one-sentence description of the Python application and its users.

## Start

1. Run `uv init` to create the Python package, then replace `PROJECTNAME` in `AI.md`, `.ai/project.yaml`, and `flake.nix`.
2. Run `direnv allow` or `nix develop`.
3. Ask for the first outcome in plain language; the primary agent plans and verifies, delegating only when isolation or parallelism helps.
4. Invoke `agent-context` after code exists to capture the real architecture and commands.

## Stack

- Python 3.13.
- `uv` for environments, dependencies, and command execution.
- Nix development shell.

## Commands

- `nix develop` - enter the development environment.
- `uv sync` - install dependencies after `pyproject.toml` exists.
- `uv run python --version` - verify the Python environment.
- No application test or lint command exists until the project declares its tools; do not guess one.
- `nix run github:SPRAGE/dev-template#ai-doctor` - validate agent assets.

## Layout

- `.ai/` - neutral agent specification, project context, and the default shared skill.
- `.agents/skills/` - Codex skill discovery link.
- `.claude/` and `.codex/` - generated provider agents plus native settings.

## Project Facts

- Add package entry points, exact test/lint/type-check commands, and project-specific conventions here.
