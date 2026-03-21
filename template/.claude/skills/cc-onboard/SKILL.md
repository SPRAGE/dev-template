---
name: cc-onboard
description: >
  Onboard Claude Code onto an existing repository that has code but no Claude Code configuration.
  Scans the codebase bottom-up to generate CLAUDE.md, .mcp.json, .claude/rules/, and populate
  the knowledge store with architecture and convention data detected from the code. Use when the
  user says "onboard claude code", "set up claude code for this repo", "bootstrap claude code",
  "add claude code to this project", or any variation of adding Claude Code to an existing project.
  This is the brownfield complement to cc-project-setup (which works top-down from brainstorm briefs).
tools: Read, Glob, Grep, Bash, Edit, Write, Agent
---

# Claude Code Onboard

Onboard Claude Code onto an existing repository by scanning the codebase and generating
tailored configuration files and a populated knowledge store.

**This skill writes files.** It generates CLAUDE.md, .mcp.json, .claude/rules/, and
populates .claude/knowledge/ based on what it finds in the code.

## When This Skill Runs

The user has a repository with existing code but no (or minimal) Claude Code setup.
They want Claude Code configured based on what's actually in the codebase — not from
a brainstorm brief.

## Prerequisites

Check if `nix run .#onboard` (or the equivalent bootstrap) was already run:
- If `.claude/knowledge/` exists with template files → Phase 1 done, proceed to scanning
- If `.claude/` doesn't exist at all → do minimal inline bootstrap: create `.claude/knowledge/`
  with empty templates, create stub `.mcp.json`, then proceed to scanning
- If `.claude/knowledge/` exists with populated files → warn user this repo appears already
  onboarded, suggest `/cc-refresh` instead. Proceed only if user confirms.

## Scanning Phase

Dispatch 4 parallel Agent tool subagents. Each agent gets a focused task and returns
structured findings.

### Agent 1: Language & Framework Detector

**Prompt for agent:**
> Scan this repository to identify all programming languages and frameworks in use.
> Look for these indicator files (check each, report what you find):
> - `Cargo.toml` → Rust (read for edition, dependencies, features)
> - `package.json` → Node.js/JavaScript (read for dependencies, scripts, type field)
> - `pyproject.toml` / `setup.py` / `requirements.txt` → Python (read for dependencies)
> - `go.mod` → Go (read for module path, go version)
> - `flake.nix` / `default.nix` → Nix (read for inputs, outputs)
> - `Gemfile` → Ruby
> - `pom.xml` / `build.gradle` → Java/Kotlin
> - `.csproj` / `.sln` → C#/.NET
> - `Makefile` / `CMakeLists.txt` → C/C++
> - `mix.exs` → Elixir
> - `deno.json` / `deno.jsonc` → Deno
>
> Also check for framework indicators:
> - `next.config.*` → Next.js
> - `vite.config.*` → Vite
> - `svelte.config.*` → SvelteKit
> - `angular.json` → Angular
> - `tailwind.config.*` → Tailwind CSS
> - `tsconfig.json` → TypeScript
> - `.eslintrc*` / `eslint.config.*` → ESLint
> - `prettier.config.*` / `.prettierrc*` → Prettier
>
> Return a structured report:
> ```
> ## Languages
> - [language]: [version if detectable]
>
> ## Frameworks
> - [framework]: [version if detectable]
>
> ## Package Managers
> - [manager]: [lockfile present? yes/no]
>
> ## Key Config Files
> - [path]: [what it configures]
> ```

### Agent 2: Structure Mapper

**Prompt for agent:**
> Map the directory structure of this repository. Focus on:
> 1. Top-level directories and their purpose (src/, lib/, tests/, docs/, etc.)
> 2. Entry points (main files, index files, CLI entry points, server start files)
> 3. Test directories and test file patterns (where do tests live? what naming convention?)
> 4. Config file locations (at root? in config/ dir?)
> 5. Build output directories (.gitignore patterns for build artifacts)
> 6. Any monorepo structure (packages/, apps/, modules/)
>
> Use `Glob` and `Read` tools. Don't read file contents unless needed to identify purpose.
>
> Return a structured report:
> ```
> ## Directory Structure
> - `path/` — [purpose]
>
> ## Entry Points
> - `path/to/main.ext` — [what it does]
>
> ## Test Locations
> - `path/to/tests/` — [test framework, naming pattern]
>
> ## Config Locations
> - `path/to/config` — [what it configures]
>
> ## Build Artifacts
> - [pattern] — [what generates it]
> ```

### Agent 3: Convention Detector

**Prompt for agent:**
> Analyze coding conventions in this repository by sampling source files.
> Read 5-10 representative source files (pick from different directories/modules).
>
> Detect and report:
> 1. **Naming**: snake_case, camelCase, PascalCase — for functions, variables, types, files
> 2. **Error handling**: Result/Option types, try/catch, error codes, custom error types
> 3. **Testing**: test naming convention (test_*, *_test, it("should...")), assertion library
> 4. **Imports**: relative vs absolute, barrel files, module system
> 5. **Code style**: indentation (tabs/spaces/size), line length, trailing commas
> 6. **Documentation**: docstrings present? JSDoc? Rustdoc? Type annotations?
>
> Return a structured report:
> ```
> ## Naming Patterns
> - Functions: [convention] (evidence: [example])
> - Variables: [convention]
> - Types/Classes: [convention]
> - Files: [convention]
>
> ## Error Handling
> - Pattern: [description] (evidence: [file:line])
>
> ## Testing Patterns
> - Framework: [name]
> - Naming: [convention]
> - Assertions: [style]
>
> ## Import/Module Patterns
> - Style: [description]
>
> ## Code Style
> - Indentation: [tabs/spaces, size]
> - Other: [observations]
> ```

### Agent 4: Command Discoverer

**Prompt for agent:**
> Discover all build, test, lint, format, and run commands available in this repository.
>
> Check these sources (read each if it exists):
> - `Makefile` → make targets
> - `package.json` → scripts section
> - `Cargo.toml` → standard cargo commands (build, test, clippy, fmt)
> - `pyproject.toml` → scripts section, build system
> - `flake.nix` → apps, checks, devShell packages
> - `justfile` → just recipes
> - `Taskfile.yml` → task definitions
> - `deno.json` → tasks section
> - `.github/workflows/*.yml` → CI commands (these show what the project actually runs)
> - `docker-compose.yml` → service definitions
> - `Procfile` → process definitions
>
> For each command found, note:
> - The exact command string (copy-paste ready)
> - What it does
> - Whether it requires environment setup
>
> Return a structured report:
> ```
> ## Build
> - `[exact command]` — [description]
>
> ## Test
> - `[exact command]` — [description]
>
> ## Lint
> - `[exact command]` — [description]
>
> ## Format
> - `[exact command]` — [description]
>
> ## Run/Dev
> - `[exact command]` — [description]
>
> ## Other
> - `[exact command]` — [description]
> ```

## Generation Phase

After all 4 agents return, synthesize their findings into:

### 1. CLAUDE.md

Generate a CLAUDE.md following these rules:
- **Under 100 lines.** Aim for 40-80.
- **No fluff.** Start with a one-liner description.
- **Exact commands.** Copy-paste ready from the command discoverer's findings.
- **Specific conventions.** From the convention detector's findings.
- **Architecture map.** From the structure mapper's findings.

Structure:
```
# [Project Name]
[One-line description — infer from README.md if it exists, or from code structure]

## Stack
[From language/framework detector]

## Commands
[From command discoverer — exact strings only]

## Architecture
[From structure mapper — key directories]

## Conventions
[From convention detector — actual patterns found, not aspirational]

## Important Notes
[Any gotchas discovered during scanning]
```

### 2. .mcp.json

Start with ruflo MCP server (always included). Add others based on detected stack:
- `.git/` + GitHub remote → suggest GitHub MCP (but don't add — requires token setup)
- Web app with test directory → note Playwright MCP option
- Library-heavy project → note Context7 MCP option
- Database config found → note appropriate database MCP

Only include ruflo by default. List others as recommendations in the output, not in the file.

### 3. .claude/rules/

Generate 1-3 rule files based on detected patterns. Each file 10-25 lines, focused on
one concern. Only create rules for things linters/formatters DON'T already handle.

### 4. Knowledge Store Population

- `architecture-snapshot.md` — fill from agents 1 + 2 findings, update frontmatter
- `conventions.md` — fill from agent 3 findings, update frontmatter
- `active-context.md` — set Current Focus to "Project just onboarded via /cc-onboard",
  update frontmatter with current timestamp
- `decisions.md` — leave empty (no decisions made yet)
- `stale-log.md` — append: `[YYYY-MM-DD HH:MM] [onboard] Knowledge store initialized`

## Presentation Phase

Show the user everything that was generated:
1. CLAUDE.md content with explanation of non-obvious choices
2. .mcp.json (should be minimal — just ruflo + any auto-detected servers)
3. Rule files with one-line explanation each
4. Knowledge store population summary

Ask for approval before writing any files.

## Post-Write Phase

After user approves and files are written:
1. Check if ruflo is available (`command -v ruflo`)
2. If yes, offer to initialize ruflo memory: "Ruflo detected. Want me to sync the
   knowledge store to ruflo memory so agents can access it?"
3. If user agrees, run ruflo-sync.sh push (if hooks are installed) or do it inline

## Important Constraints

- Never include actual secrets, tokens, or passwords in generated files
- Use `${ENV_VAR}` expansion for sensitive values in .mcp.json
- If something can't be detected, mark it with `<!-- TODO: verify -->` so the user knows
- Don't guess at commands — if you can't find a test command, say "no test command found"
  rather than guessing `npm test`
- The CLAUDE.md must be useful on day one — no placeholder sections
