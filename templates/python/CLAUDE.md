# CLAUDE.md

## Project

PROJECTNAME — TODO: replace with one-line description.

## Getting Started

This project was scaffolded from dev-template (Python variant). To set up:

1. Replace `PROJECTNAME` in this file and `flake.nix`
2. `uv init` to set up the Python project
3. `direnv allow` to enter the dev shell (includes python, uv, ruflo)
4. Run `/virtual-tech-org` to spin up a full virtual tech company that builds your project through staged delivery
   - OR use individual skills: `/project-brainstorm` → `/cc-project-setup` → `/feature-planner`

## Stack

- Python 3.13
- uv (package manager)
- Ruflo (AI agent orchestration)

## Commands

- `uv run python main.py` — run
- `uv run pytest` — test
- `uv run ruff check .` — lint
- `uv run ruff format .` — format
- `nix develop` — enter dev shell
- `nix run github:USER/dev-template#sync-skills` — pull latest skills from template

## Conventions

- Type hints on all function signatures
- snake_case for functions/variables, PascalCase for classes
- Tests in `tests/` mirroring `src/` structure
