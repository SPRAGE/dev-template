# CLAUDE.md

## Project

PROJECTNAME — TODO: replace with one-line description.

## Getting Started

1. Replace `PROJECTNAME` in this file and `flake.nix`
2. `uv init` to set up the Python project
3. `direnv allow` to enter the dev shell
4. Run `/planner` to brainstorm, then `/cc-setup` to generate config
   - OR run `/virtual-tech-org` for full autonomous staged delivery

## Stack

- Python 3.13
- uv (package manager)

## Commands

- `uv run python main.py` — run
- `uv run pytest` — test
- `uv run ruff check .` — lint
- `uv run ruff format .` — format
- `nix develop` — enter dev shell

## Conventions

- Type hints on all function signatures
- snake_case for functions/variables, PascalCase for classes
- Tests in `tests/` mirroring `src/` structure

## Decisions

Architectural decisions are tracked in `.claude/knowledge/decisions.md`.
