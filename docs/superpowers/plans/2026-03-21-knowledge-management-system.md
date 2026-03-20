# Knowledge Management System Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a 4-layer knowledge management system (knowledge store, skills, hooks, ruflo bridge) to the dev-template so Claude Code can onboard existing repos, refresh stale context, survive context compression, and share memory with ruflo agents.

**Architecture:** File-based knowledge store (`.claude/knowledge/`) as the foundation, skills that read/write it, hooks that automate persistence, and an optional ruflo bridge for bidirectional sync. Each layer is independently shippable.

**Tech Stack:** Nix (flake apps), Bash (hook scripts), Markdown (knowledge store + skills)

**Spec:** `docs/superpowers/specs/2026-03-21-claude-code-knowledge-management-design.md`

---

## Phase 1: Knowledge Store + cc-onboard + Bootstrap

### Task 1: Create Knowledge Store Template Files

**Files:**
- Create: `template/.claude/knowledge/active-context.md`
- Create: `template/.claude/knowledge/decisions.md`
- Create: `template/.claude/knowledge/architecture-snapshot.md`
- Create: `template/.claude/knowledge/conventions.md`
- Create: `template/.claude/knowledge/stale-log.md`

- [ ] **Step 1: Create active-context.md template**

```markdown
---
last_updated: TEMPLATE
last_updated_by: cc-onboard
---

## Current Focus
<!-- What is actively being worked on right now -->

## Recent Decisions
<!-- Decisions made in the last 1-3 sessions not yet moved to decisions.md -->

## Recent Changes
<!-- Commits and file changes from recent sessions — appended by post-commit hook -->

## Open Questions
<!-- Unresolved questions that need answers -->

## Key Files in Play
<!-- Files being actively modified — paths + why they matter -->

## Blockers
<!-- Anything blocking progress -->
```

Write to `template/.claude/knowledge/active-context.md`.

- [ ] **Step 2: Create decisions.md template**

```markdown
<!-- Architectural and design decisions still in effect.
     Each entry follows this format:

## [Decision Title]
- **Date:** YYYY-MM-DD
- **Status:** active | superseded by [other decision]
- **Decision:** [What was decided]
- **Why:** [Reasoning]
- **Alternatives considered:** [What else was on the table]
-->
```

Write to `template/.claude/knowledge/decisions.md`.

- [ ] **Step 3: Create architecture-snapshot.md template**

```markdown
---
last_updated: TEMPLATE
generated_by: cc-onboard | cc-refresh
---

## Stack
<!-- Languages, frameworks, key libraries — detected from config files -->

## Directory Structure
<!-- Key directories and what lives in each — from actual tree scan -->

## Entry Points
<!-- Main files, CLI entry points, server start files, test runners -->

## Dependencies
<!-- Key dependency graph — what depends on what, external service deps -->

## Data Flow
<!-- How data moves through the system — only if applicable -->
```

Write to `template/.claude/knowledge/architecture-snapshot.md`.

- [ ] **Step 4: Create conventions.md template**

```markdown
---
last_updated: TEMPLATE
generated_by: cc-onboard | cc-refresh
---

## Naming Patterns
<!-- snake_case vs camelCase, file naming, module naming — detected from code samples -->

## Error Handling
<!-- How errors are handled — Result types, exceptions, error codes — detected patterns -->

## Testing Patterns
<!-- Test framework, test file locations, test naming, assertion style -->

## Import/Module Patterns
<!-- How imports are organized, module system conventions -->

## Build & Tooling
<!-- Build commands, linter config, formatter config, CI patterns -->
```

Write to `template/.claude/knowledge/conventions.md`.

- [ ] **Step 5: Create stale-log.md template**

```markdown
# Stale Log

Append-only log of items removed or superseded during refresh operations.
This file is a safety net — never edit entries, only append.

---
<!-- Entries appended by /cc-refresh and ruflo-sync.sh -->
```

Write to `template/.claude/knowledge/stale-log.md`.

- [ ] **Step 6: Create .gitignore for ephemeral knowledge store files**

Write to `template/.claude/knowledge/.gitignore`:

```
# Ephemeral state files used by hooks — not tracked in git
.watchdog-last-run
.watchdog-last-size
.needs-persist
.session-loaded
```

- [ ] **Step 7: Commit**

```bash
git add template/.claude/knowledge/
git commit -m "feat: add knowledge store template files (active-context, decisions, architecture, conventions, stale-log)"
```

---

### Task 2: Create the cc-onboard Skill

**Files:**
- Create: `template/.claude/skills/cc-onboard/SKILL.md`

- [ ] **Step 1: Write the cc-onboard SKILL.md**

This is a Claude Code skill file. It must follow the SKILL.md convention used by existing skills in this repo (see `template/.claude/skills/claude-automation-recommender/SKILL.md` for the format pattern: YAML frontmatter with `name`, `description`, `tools`, then markdown body).

Write the skill to `template/.claude/skills/cc-onboard/SKILL.md` with this content:

```markdown
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
```

- [ ] **Step 2: Commit**

```bash
git add template/.claude/skills/cc-onboard/
git commit -m "feat: add cc-onboard skill for bootstrapping Claude Code on existing repos"
```

---

### Task 3: Create the Onboard Nix App

**Files:**
- Modify: `flake.nix:54-109` (add `apps.onboard` alongside existing `apps.sync-skills`)

- [ ] **Step 1: Write a test script to verify the onboard app behavior**

Create a test script that we'll use to validate the onboard app works:

```bash
#!/usr/bin/env bash
# tests/test-onboard.sh — validates nix run .#onboard behavior
set -euo pipefail

TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT

echo "=== Test 1: Full bootstrap (no .claude/) ==="
cd "$TEST_DIR"
mkdir -p fake-project && cd fake-project
git init -q
touch flake.nix  # onboard checks for project root indicators

# Run onboard (the app path will be passed as $1)
"$1"

# Verify all expected files exist
for f in .claude/knowledge/active-context.md \
         .claude/knowledge/decisions.md \
         .claude/knowledge/architecture-snapshot.md \
         .claude/knowledge/conventions.md \
         .claude/knowledge/stale-log.md \
         .claude/settings.json \
         .mcp.json \
         CLAUDE.md; do
  [ -f "$f" ] || { echo "FAIL: $f not created"; exit 1; }
done

# Verify hooks are executable
for h in .claude/hooks/session-start.sh \
         .claude/hooks/context-watchdog.sh \
         .claude/hooks/post-commit-persist.sh \
         .claude/hooks/session-end.sh \
         .claude/hooks/ruflo-sync.sh; do
  [ -x "$h" ] || { echo "FAIL: $h not executable"; exit 1; }
done

echo "PASS: Full bootstrap"

echo ""
echo "=== Test 2: Knowledge-only (has .claude/ but no knowledge/) ==="
cd "$TEST_DIR"
mkdir -p partial-project/.claude && cd partial-project
git init -q
touch flake.nix

"$1"

[ -d .claude/knowledge ] || { echo "FAIL: knowledge/ not created"; exit 1; }
echo "PASS: Knowledge-only bootstrap"

echo ""
echo "=== Test 3: Already onboarded (has everything) ==="
cd "$TEST_DIR/fake-project"

OUTPUT=$("$1" 2>&1) || true
echo "$OUTPUT" | grep -q "already" || echo "WARN: expected 'already onboarded' message"
echo "PASS: Already-onboarded detection"

echo ""
echo "All tests passed."
```

Write to `tests/test-onboard.sh` and make executable.

- [ ] **Step 2: Run the test to verify it fails**

```bash
bash tests/test-onboard.sh /nonexistent 2>&1 || echo "Expected failure — onboard app not built yet"
```

Expected: Fails because the onboard app doesn't exist.

- [ ] **Step 3: Add apps.onboard to flake.nix**

In `flake.nix`, after the existing `apps.sync-skills` block (line 108), add the `apps.onboard` app. The onboard script needs access to the template files as its source.

The new `apps.onboard` block should be added inside the `flake-utils.lib.eachDefaultSystem` block, alongside `apps.sync-skills`. It uses the same pattern: `pkgs.writeShellScriptBin` wrapped in an app attrset.

```nix
apps.onboard =
  let
    knowledge-src = ./template/.claude/knowledge;
    hooks-src = ./template/.claude/hooks;
    settings-src = ./template/.claude/settings.json;
    mcp-src = ./template/.mcp.json;
    claude-md-src = ./template/CLAUDE.md;
    script = pkgs.writeShellScriptBin "onboard" ''
      set -euo pipefail

      # Must be run from a project root
      if [ ! -f "$PWD/flake.nix" ] && [ ! -d "$PWD/.git" ] && [ ! -f "$PWD/package.json" ] && [ ! -f "$PWD/Cargo.toml" ] && [ ! -f "$PWD/pyproject.toml" ] && [ ! -f "$PWD/go.mod" ]; then
        echo "error: no project root indicators found (flake.nix, .git, package.json, Cargo.toml, pyproject.toml, go.mod)"
        echo "Run this from your project root."
        exit 1
      fi

      # Detect state
      if [ -d "$PWD/.claude/knowledge" ] && [ -f "$PWD/.claude/knowledge/active-context.md" ]; then
        # Check if knowledge files have been populated (not just templates)
        if grep -q "TEMPLATE" "$PWD/.claude/knowledge/active-context.md" 2>/dev/null; then
          echo "Knowledge store exists but is unpopulated. Proceeding with bootstrap..."
        else
          echo "This project appears already onboarded (.claude/knowledge/ exists with content)."
          echo "Run /cc-refresh inside Claude Code to update existing configuration."
          exit 0
        fi
      fi

      if [ -d "$PWD/.claude" ] && [ ! -d "$PWD/.claude/knowledge" ]; then
        echo "onboard: .claude/ exists but no knowledge store. Adding knowledge store + hooks..."
        echo ""

        # Knowledge store only
        mkdir -p "$PWD/.claude/knowledge"
        for f in "${knowledge-src}"/*; do
          [ -f "$f" ] || continue
          fname=$(basename "$f")
          cp -L "$f" "$PWD/.claude/knowledge/$fname"
          chmod u+w "$PWD/.claude/knowledge/$fname"
        done

        # Hooks
        mkdir -p "$PWD/.claude/hooks"
        for f in "${hooks-src}"/*; do
          [ -f "$f" ] || continue
          fname=$(basename "$f")
          cp -L "$f" "$PWD/.claude/hooks/$fname"
          chmod u+w "$PWD/.claude/hooks/$fname"
          chmod +x "$PWD/.claude/hooks/$fname"
        done

        echo "Done. Knowledge store and hooks added."
        echo ""
        echo "Next: open Claude Code and run /cc-onboard to scan your codebase."
        exit 0
      fi

      # Full bootstrap
      echo "onboard: bootstrapping Claude Code for this project"
      echo ""

      # .claude/ directory
      mkdir -p "$PWD/.claude"

      # Settings
      cp -L "${settings-src}" "$PWD/.claude/settings.json"
      chmod u+w "$PWD/.claude/settings.json"
      echo "  + .claude/settings.json"

      # Knowledge store
      mkdir -p "$PWD/.claude/knowledge"
      for f in "${knowledge-src}"/*; do
        [ -f "$f" ] || continue
        fname=$(basename "$f")
        cp -L "$f" "$PWD/.claude/knowledge/$fname"
        chmod u+w "$PWD/.claude/knowledge/$fname"
        echo "  + .claude/knowledge/$fname"
      done

      # Hooks
      mkdir -p "$PWD/.claude/hooks"
      for f in "${hooks-src}"/*; do
        [ -f "$f" ] || continue
        fname=$(basename "$f")
        cp -L "$f" "$PWD/.claude/hooks/$fname"
        chmod u+w "$PWD/.claude/hooks/$fname"
        chmod +x "$PWD/.claude/hooks/$fname"
        echo "  + .claude/hooks/$fname"
      done

      # .mcp.json
      if [ ! -f "$PWD/.mcp.json" ]; then
        cp -L "${mcp-src}" "$PWD/.mcp.json"
        chmod u+w "$PWD/.mcp.json"
        echo "  + .mcp.json"
      else
        echo "  = .mcp.json (already exists, skipped)"
      fi

      # CLAUDE.md
      if [ ! -f "$PWD/CLAUDE.md" ]; then
        cp -L "${claude-md-src}" "$PWD/CLAUDE.md"
        chmod u+w "$PWD/CLAUDE.md"
        echo "  + CLAUDE.md (stub — run /cc-onboard to populate)"
      else
        echo "  = CLAUDE.md (already exists, skipped)"
      fi

      echo ""
      echo "Bootstrap complete."
      echo ""
      echo "Next steps:"
      echo "  1. direnv allow          (if using direnv)"
      echo "  2. Open Claude Code"
      echo "  3. Run /cc-onboard       (scans codebase and generates tailored config)"
    '';
  in
  {
    type = "app";
    program = "${script}/bin/onboard";
  };
```

Add this after the `apps.sync-skills` block closing semicolon, inside the same `eachDefaultSystem` scope.

- [ ] **Step 4: Create hooks placeholder directory (prerequisite for flake evaluation)**

The onboard app references `hooks-src = ./template/.claude/hooks` which doesn't exist yet (hooks are Phase 3). Create a placeholder so Nix can evaluate:

```bash
mkdir -p template/.claude/hooks
touch template/.claude/hooks/.gitkeep
```

- [ ] **Step 5: Verify flake evaluates**

```bash
nix flake check
```

Expected: No errors. The flake evaluates cleanly with the placeholder hooks directory.

- [ ] **Step 6: Run the test script**

```bash
ONBOARD_BIN=$(nix build .#onboard --no-link --print-out-paths 2>/dev/null)/bin/onboard
bash tests/test-onboard.sh "$ONBOARD_BIN"
```

Note: Uses `nix build .#onboard` (not system-specific path) for portability across x86_64-linux, aarch64-linux, and macOS. Hook executable checks in the test should be relaxed to skip `.gitkeep` files — update the test's hook loop to:

```bash
for h in .claude/hooks/*.sh; do
  [ -f "$h" ] || continue  # skip if no .sh files (only .gitkeep)
  [ -x "$h" ] || { echo "FAIL: $h not executable"; exit 1; }
done
```

- [ ] **Step 7: Commit**

```bash
git add flake.nix tests/test-onboard.sh template/.claude/hooks/.gitkeep
git commit -m "feat: add nix run .#onboard bootstrap app with test"
```

---

### Task 4: Expand sync-skills to Sync Hooks and Knowledge Templates

**Files:**
- Modify: `flake.nix` (the `apps.sync-skills` block, lines 54-108)

- [ ] **Step 1: Update the sync-skills script**

The existing `sync-skills` script only syncs `.claude/skills/`. Expand it to also sync:
- `.claude/hooks/` — always overwrite (hook scripts are template-owned)
- `.claude/knowledge/` — only copy files that don't exist yet (never overwrite populated knowledge)

Add two new sync sections after the existing skills sync loop. The hooks section uses the same diff-and-copy pattern as skills. The knowledge section only copies if the target file doesn't exist.

Add new source references at the top of the `let` block:
```nix
hooks-src = ./template/.claude/hooks;
knowledge-src = ./template/.claude/knowledge;
```

Add to the script body, after the skills sync loop and before the "Done" line:

```bash
# Sync hooks (always overwrite — hooks are template-owned)
HOOKS_SOURCE="${hooks-src}"
HOOKS_TARGET="$PWD/.claude/hooks"
if [ -d "$HOOKS_SOURCE" ] && [ "$(ls -A "$HOOKS_SOURCE" 2>/dev/null)" ]; then
  mkdir -p "$HOOKS_TARGET"
  echo ""
  echo "sync-skills: syncing hooks"
  for hook_file in "$HOOKS_SOURCE"/*; do
    [ -f "$hook_file" ] || continue
    hook_name=$(basename "$hook_file")
    [ "$hook_name" = ".gitkeep" ] && continue
    if [ -f "$HOOKS_TARGET/$hook_name" ]; then
      if ! diff -q "$HOOKS_SOURCE/$hook_name" "$HOOKS_TARGET/$hook_name" >/dev/null 2>&1; then
        cp -L "$HOOKS_SOURCE/$hook_name" "$HOOKS_TARGET/$hook_name"
        chmod u+w "$HOOKS_TARGET/$hook_name"
        chmod +x "$HOOKS_TARGET/$hook_name"
        echo "  ~ $hook_name (updated)"
      else
        echo "  = $hook_name (up to date)"
      fi
    else
      cp -L "$HOOKS_SOURCE/$hook_name" "$HOOKS_TARGET/$hook_name"
      chmod u+w "$HOOKS_TARGET/$hook_name"
      chmod +x "$HOOKS_TARGET/$hook_name"
      echo "  + $hook_name (added)"
    fi
  done
fi

# Sync knowledge templates (never overwrite populated files)
KNOWLEDGE_SOURCE="${knowledge-src}"
KNOWLEDGE_TARGET="$PWD/.claude/knowledge"
if [ -d "$KNOWLEDGE_SOURCE" ]; then
  mkdir -p "$KNOWLEDGE_TARGET"
  echo ""
  echo "sync-skills: syncing knowledge templates"
  for know_file in "$KNOWLEDGE_SOURCE"/*; do
    [ -f "$know_file" ] || continue
    know_name=$(basename "$know_file")
    if [ -f "$KNOWLEDGE_TARGET/$know_name" ]; then
      echo "  = $know_name (exists, not overwriting)"
    else
      cp -L "$KNOWLEDGE_SOURCE/$know_name" "$KNOWLEDGE_TARGET/$know_name"
      chmod u+w "$KNOWLEDGE_TARGET/$know_name"
      echo "  + $know_name (added)"
    fi
  done
fi
```

- [ ] **Step 2: Verify flake evaluates**

```bash
nix flake check
```

Expected: Clean evaluation.

- [ ] **Step 3: Commit**

```bash
git add flake.nix
git commit -m "feat: expand sync-skills to sync hooks and knowledge templates"
```

---

### Task 5: Sync Phase 1 to Rust and Python Templates

**Files:**
- Sync to: `templates/rust/.claude/knowledge/`, `templates/rust/.claude/skills/cc-onboard/`
- Sync to: `templates/python/.claude/knowledge/`, `templates/python/.claude/skills/cc-onboard/`

- [ ] **Step 1: Copy knowledge store templates to both templates**

```bash
mkdir -p templates/rust/.claude/knowledge templates/python/.claude/knowledge
cp template/.claude/knowledge/* templates/rust/.claude/knowledge/
cp template/.claude/knowledge/* templates/python/.claude/knowledge/
```

- [ ] **Step 2: Copy cc-onboard skill to both templates**

```bash
mkdir -p templates/rust/.claude/skills/cc-onboard templates/python/.claude/skills/cc-onboard
cp template/.claude/skills/cc-onboard/SKILL.md templates/rust/.claude/skills/cc-onboard/
cp template/.claude/skills/cc-onboard/SKILL.md templates/python/.claude/skills/cc-onboard/
```

- [ ] **Step 3: Copy hooks placeholder to both templates**

```bash
mkdir -p templates/rust/.claude/hooks templates/python/.claude/hooks
cp template/.claude/hooks/.gitkeep templates/rust/.claude/hooks/
cp template/.claude/hooks/.gitkeep templates/python/.claude/hooks/
```

- [ ] **Step 4: Verify and commit**

```bash
nix flake check
git add templates/
git commit -m "feat: sync Phase 1 files (knowledge store, cc-onboard, hooks placeholder) to rust/python templates"
```

---

### Task 6: Validate Phase 1 End-to-End

- [ ] **Step 1: Test nix flake check passes**

```bash
nix flake check
```

Expected: Clean.

- [ ] **Step 2: Test onboard app in a temp directory**

```bash
TEST_DIR=$(mktemp -d)
cd "$TEST_DIR" && git init -q && touch flake.nix
nix run /home/shaun/codes/dev-template#onboard
ls -la .claude/knowledge/
ls -la .claude/hooks/
cat CLAUDE.md
cd /home/shaun/codes/dev-template
rm -rf "$TEST_DIR"
```

Expected: All files created, CLAUDE.md is the template stub, knowledge store has empty templates.

- [ ] **Step 3: Commit any fixes**

If any issues were found, fix and commit.

---

## Phase 2: cc-refresh Skill

### Task 7: Create the cc-refresh Skill

**Files:**
- Create: `template/.claude/skills/cc-refresh/SKILL.md`

- [ ] **Step 1: Write the cc-refresh SKILL.md**

```markdown
---
name: cc-refresh
description: >
  Audit and refresh all Claude Code context — CLAUDE.md, knowledge store, auto-memory files,
  session history, and rules. Scans for stale content, proposes targeted fixes, and executes
  approved changes. Use when the user says "refresh claude context", "clean up claude memory",
  "prune stale context", "context cleanup", "refresh knowledge", or any variation of wanting
  to clean up outdated Claude Code configuration. Also trigger when context feels stale,
  Claude is referencing things that no longer exist, or the user mentions "CLAUDE.md maintenance"
  or "project memory optimization". Supports --dry-run for audit-only mode.
tools: Read, Glob, Grep, Bash, Edit, Write, Agent
---

# Claude Code Context Refresh

Audit all Claude Code artifacts for staleness, report findings, propose fixes, and
execute approved changes. This is the maintenance counterpart to `/cc-onboard`.

**This skill modifies files.** It updates CLAUDE.md, knowledge store, memory files,
and can archive old sessions. All changes require user approval.

## Dry-Run Mode

If the user invokes with `--dry-run` or asks for a preview/audit only, run the Audit
and Report phases only. Skip Propose, Approve, and Execute phases entirely.

## Phase 1: Audit

Dispatch parallel Agent tool subagents, each auditing one target area:

### Agent 1: CLAUDE.md Auditor

**Prompt for agent:**
> Audit the CLAUDE.md file at the project root for accuracy against the current codebase.
> Check:
> 1. Every command listed — does it actually work? Check if the binary/script exists.
>    (e.g., if CLAUDE.md says `npm test`, does package.json have a test script?)
> 2. Architecture section — do the listed directories exist? Are there new directories
>    not mentioned?
> 3. Conventions — sample 3-5 source files and check if stated conventions match actual code.
> 4. Stack — does the listed stack match what's in config files (package.json, Cargo.toml, etc.)?
>
> Return structured findings:
> ```
> ## CLAUDE.md Audit
> ### Stale Items
> - [item]: [what's wrong] (severity: HIGH/MEDIUM/LOW)
> ### Missing Items
> - [item]: [what should be added]
> ### Accurate Items
> - [item]: confirmed current
> ```

### Agent 2: Knowledge Store Auditor

**Prompt for agent:**
> Audit all files in `.claude/knowledge/` for accuracy:
> 1. `active-context.md` — does "Current Focus" reference real work? Do "Key Files in Play"
>    exist? Are "Blockers" still relevant?
> 2. `decisions.md` — for each decision marked "active", is it still reflected in the code?
>    Any decisions that appear to have been reversed?
> 3. `architecture-snapshot.md` — do listed directories/entry points exist? Any new ones?
> 4. `conventions.md` — sample files and compare to stated conventions.
> 5. Check frontmatter `last_updated` dates — flag anything older than 14 days.
>
> Return structured findings per file with staleness indicators.

### Agent 3: Memory & Session Auditor

**Prompt for agent:**
> Audit Claude Code auto-memory and session history.
>
> 1. Find the project memory directory. Try these patterns:
>    - `~/.claude/projects/*/memory/` where the directory name matches the project path
>    - Look for MEMORY.md index file
>    If not found, report "Auto-memory directory not found" and skip memory audit.
>
> 2. For each memory file found:
>    - Read its content
>    - Check if it references files, functions, or patterns that still exist in the codebase
>    - Flag memories that reference deleted/renamed things
>    - Flag memories older than 30 days
>
> 3. Find session JSONL files in the same project directory:
>    - Count total sessions
>    - Sum total file sizes (use `stat` or `ls -l`, don't read the files)
>    - Note age of oldest session
>    - Recommend archiving sessions older than 7 days
>
> Return structured findings with sizes and dates.

### Agent 4: Rules Auditor

**Prompt for agent:**
> Audit all files in `.claude/rules/` (if the directory exists).
> For each rule file:
> 1. Read its content
> 2. Check if the patterns/conventions it enforces match current code
> 3. Check if it references tools, frameworks, or patterns no longer in use
> 4. Flag rules that duplicate what a linter/formatter already handles
>
> If `.claude/rules/` doesn't exist or is empty, report "No rules found" and skip.
>
> Return findings per rule file.

## Phase 2: Report

Synthesize all agent findings into a structured report. Format:

```
## Context Refresh Report

### Summary
- Targets audited: [N]
- Total findings: [N] (HIGH: [n], MEDIUM: [n], LOW: [n])
- Recommended actions: [N]

### CLAUDE.md
[Agent 1 findings]

### Knowledge Store
[Agent 2 findings]

### Auto-Memory & Sessions
[Agent 3 findings]

### Rules
[Agent 4 findings]
```

Present this report to the user. In dry-run mode, stop here.

## Phase 3: Propose Actions

For each finding, propose a specific action:

| Action | Description |
|--------|-------------|
| **Update** | Rewrite stale content with current state. Show exact diff. |
| **Archive** | Move old sessions to `.claude/archive/` |
| **Prune** | Remove stale memory file (content logged to stale-log.md first) |
| **Supersede** | Mark reversed decision as `superseded by [new decision]` |
| **Add** | Add missing information discovered during audit |
| **Skip** | Finding is informational, no action needed |

Group proposals by target (CLAUDE.md, knowledge store, memory, sessions, rules).

## Phase 4: Approve

Present proposals grouped by category. Ask user:
> "Apply all changes? Or review per category? (all / by-category / per-item)"

- **all**: Apply everything proposed
- **by-category**: Ask approval for each category (CLAUDE.md changes, knowledge changes, etc.)
- **per-item**: Ask approval for each individual change

Declined items are logged to stdout: "Skipped: [item] — [reason: user declined]"
Do not re-prompt for declined items.

## Phase 5: Execute

Apply approved changes:
1. For each **Prune**: append the full content being removed to `stale-log.md` with timestamp and reason, then delete
2. For each **Update/Add**: apply the edit using Edit tool
3. For each **Archive**: create `.claude/archive/` if needed, move files there
4. For each **Supersede**: update the decision entry in decisions.md
5. Update `active-context.md` frontmatter with current timestamp
6. Append summary to `stale-log.md`:
   ```
   [YYYY-MM-DD HH:MM] [cc-refresh] Refresh completed: N updates, N prunes, N archives, N superseded
   ```

## Phase 6: Optional Ruflo Sync

If ruflo is available (`command -v ruflo` succeeds):
> "Ruflo detected. Sync updated knowledge store to ruflo memory?"

If yes, run `.claude/hooks/ruflo-sync.sh push` or do it inline.

## Stale-Log Format

Every removal/prune appends an entry:

```markdown
---
### [YYYY-MM-DD HH:MM] [cc-refresh] Pruned: [filename or item]
**Reason:** [why it was pruned]
**Original content:**
[full content of what was removed]
---
```

This ensures nothing is permanently lost. Users can recover incorrectly pruned items.
```

Write to `template/.claude/skills/cc-refresh/SKILL.md`.

- [ ] **Step 2: Commit**

```bash
git add template/.claude/skills/cc-refresh/
git commit -m "feat: add cc-refresh skill for auditing and pruning stale Claude Code context"
```

---

### Task 8: Sync cc-refresh to Templates and Validate

**Files:**
- Sync to: `templates/rust/.claude/skills/cc-refresh/`, `templates/python/.claude/skills/cc-refresh/`

- [ ] **Step 1: Copy to both templates**

```bash
mkdir -p templates/rust/.claude/skills/cc-refresh templates/python/.claude/skills/cc-refresh
cp template/.claude/skills/cc-refresh/SKILL.md templates/rust/.claude/skills/cc-refresh/
cp template/.claude/skills/cc-refresh/SKILL.md templates/python/.claude/skills/cc-refresh/
```

- [ ] **Step 2: Validate and commit**

```bash
nix flake check
git add templates/
git commit -m "feat: sync cc-refresh skill to rust/python templates"
```

---

## Phase 3: Hooks

### Task 9: Create ruflo-sync.sh (Dependency for Other Hooks)

**Files:**
- Create: `template/.claude/hooks/ruflo-sync.sh`

Other hooks call this script, so it must exist first.

- [ ] **Step 1: Write ruflo-sync.sh**

```bash
#!/usr/bin/env bash
# ruflo-sync.sh — bidirectional sync between knowledge store and ruflo memory
# Usage: ruflo-sync.sh [push|pull|both]
set -euo pipefail

KNOWLEDGE_DIR=".claude/knowledge"
MODE="${1:-both}"

# Graceful degradation — skip if ruflo not available
command -v ruflo >/dev/null 2>&1 || { echo "ruflo not available, skipping sync"; exit 0; }

# Verify knowledge store exists
[ -d "$KNOWLEDGE_DIR" ] || { echo "No knowledge store found at $KNOWLEDGE_DIR, skipping sync"; exit 0; }

push_to_ruflo() {
  local file key
  for file in "$KNOWLEDGE_DIR"/{active-context,decisions,architecture-snapshot,conventions}.md; do
    [ -f "$file" ] || continue
    key=$(basename "$file" .md)
    ruflo memory store "$key" "$(cat "$file")" --namespace project 2>/dev/null || true
  done
  ruflo memory store "last-sync" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" --namespace project 2>/dev/null || true
}

pull_from_ruflo() {
  local output_dir="$KNOWLEDGE_DIR/agent-outputs"
  mkdir -p "$output_dir"

  # Query for agent outputs
  local agent_output
  agent_output=$(ruflo memory query "agent-output" --namespace project 2>/dev/null) || return 0

  if [ -n "$agent_output" ]; then
    local timestamp
    timestamp=$(date -u +%Y%m%d-%H%M%S)
    echo "$agent_output" > "$output_dir/agent-output-${timestamp}.md"

    # Update active-context with agent activity note
    if [ -f "$KNOWLEDGE_DIR/active-context.md" ]; then
      local marker="## Recent Agent Activity"
      if ! grep -q "$marker" "$KNOWLEDGE_DIR/active-context.md" 2>/dev/null; then
        printf "\n%s\n" "$marker" >> "$KNOWLEDGE_DIR/active-context.md"
      fi
      printf "- [%s] Agent output captured\\n" "$(date -u +%Y-%m-%d)" >> "$KNOWLEDGE_DIR/active-context.md"
    fi
  fi
}

sync_with_overwrite_logging() {
  # For bidirectional files, log overwrites to stale-log
  local stale_log="$KNOWLEDGE_DIR/stale-log.md"
  for file in architecture-snapshot conventions; do
    local local_file="$KNOWLEDGE_DIR/${file}.md"
    [ -f "$local_file" ] || continue

    local remote_content
    remote_content=$(ruflo memory query "$file" --namespace project 2>/dev/null) || continue
    [ -n "$remote_content" ] || continue

    local local_content
    local_content=$(cat "$local_file")

    if [ "$local_content" != "$remote_content" ]; then
      # Log the overwrite
      {
        echo ""
        echo "---"
        echo "### $(date -u +%Y-%m-%dT%H:%M:%SZ) [sync-overwrite] ${file}.md overwritten by ruflo"
        echo "**Source:** ruflo memory → local file"
        echo "**Previous local content:**"
        echo "$local_content"
        echo "---"
      } >> "$stale_log"

      echo "$remote_content" > "$local_file"
    fi
  done
}

case "$MODE" in
  push)
    push_to_ruflo
    ;;
  pull)
    pull_from_ruflo
    ;;
  both)
    push_to_ruflo
    sync_with_overwrite_logging
    pull_from_ruflo
    ;;
  *)
    echo "Usage: ruflo-sync.sh [push|pull|both]"
    exit 1
    ;;
esac
```

Write to `template/.claude/hooks/ruflo-sync.sh`.

- [ ] **Step 2: Verify syntax**

```bash
bash -n template/.claude/hooks/ruflo-sync.sh
```

Expected: No output (syntax valid).

- [ ] **Step 3: Commit**

```bash
git add template/.claude/hooks/ruflo-sync.sh
rm template/.claude/hooks/.gitkeep 2>/dev/null || true
git add template/.claude/hooks/
git commit -m "feat: add ruflo-sync.sh for bidirectional knowledge store sync"
```

---

### Task 10: Create session-start.sh

**Files:**
- Create: `template/.claude/hooks/session-start.sh`

- [ ] **Step 1: Write session-start.sh**

```bash
#!/usr/bin/env bash
# session-start.sh — loads knowledge store context at session start
# Event: SessionStart
set -euo pipefail

KNOWLEDGE_DIR=".claude/knowledge"

# Missing-file safe: if knowledge store doesn't exist, exit quietly
[ -d "$KNOWLEDGE_DIR" ] || exit 0

# --- Load active context ---
if [ -f "$KNOWLEDGE_DIR/active-context.md" ]; then
  # Skip if it's just the empty template
  if ! grep -q "TEMPLATE" "$KNOWLEDGE_DIR/active-context.md" 2>/dev/null; then
    echo "=== Active Context (from knowledge store) ==="
    cat "$KNOWLEDGE_DIR/active-context.md"
    echo ""
  fi
fi

# --- Surface active decisions ---
# Note: true date-range filtering in bash is complex; instead we surface
# all decisions marked "active". This is a practical simplification.
if [ -f "$KNOWLEDGE_DIR/decisions.md" ]; then
  if grep -q "^## " "$KNOWLEDGE_DIR/decisions.md" 2>/dev/null; then
    ACTIVE_DECISIONS=$(grep -B1 -A3 "active" "$KNOWLEDGE_DIR/decisions.md" 2>/dev/null | grep -v "^--$" || true)
    if [ -n "$ACTIVE_DECISIONS" ]; then
      echo "=== Active Decisions ==="
      echo "$ACTIVE_DECISIONS"
      echo ""
    fi
  fi
fi

# --- Surface recent agent outputs (last 3 days) ---
AGENT_OUTPUTS_DIR="$KNOWLEDGE_DIR/agent-outputs"
if [ -d "$AGENT_OUTPUTS_DIR" ]; then
  THREE_DAYS_AGO_TS=$(date -d "3 days ago" +%s 2>/dev/null || date -v-3d +%s 2>/dev/null || echo "0")
  RECENT_OUTPUTS=""
  for output_file in "$AGENT_OUTPUTS_DIR"/*.md; do
    [ -f "$output_file" ] || continue
    FILE_TS=$(stat -c %Y "$output_file" 2>/dev/null || stat -f %m "$output_file" 2>/dev/null || echo "0")
    if [ "$FILE_TS" -ge "$THREE_DAYS_AGO_TS" ] 2>/dev/null; then
      RECENT_OUTPUTS="${RECENT_OUTPUTS}\n- $(basename "$output_file")"
    fi
  done
  if [ -n "$RECENT_OUTPUTS" ]; then
    echo "=== Recent Agent Outputs ==="
    printf "%b\\n" "$RECENT_OUTPUTS"
    echo ""
  fi
fi

# --- Staleness checks ---
NUDGES=""

# Architecture snapshot age
if [ -f "$KNOWLEDGE_DIR/architecture-snapshot.md" ]; then
  SNAP_TS=$(stat -c %Y "$KNOWLEDGE_DIR/architecture-snapshot.md" 2>/dev/null || stat -f %m "$KNOWLEDGE_DIR/architecture-snapshot.md" 2>/dev/null || echo "0")
  FOURTEEN_DAYS_AGO_TS=$(date -d "14 days ago" +%s 2>/dev/null || date -v-14d +%s 2>/dev/null || echo "0")
  if [ "$SNAP_TS" -lt "$FOURTEEN_DAYS_AGO_TS" ] 2>/dev/null; then
    NUDGES="${NUDGES}\n- Architecture snapshot is stale (>14 days). Consider running /cc-refresh."
  fi
fi

# Auto-memory age check (30 days)
PROJECT_DIR=$(echo "$PWD" | sed 's|/|-|g; s|^-||')
CLAUDE_PROJECT_DIR="$HOME/.claude/projects/${PROJECT_DIR}"
MEMORY_DIR="$CLAUDE_PROJECT_DIR/memory"
if [ -d "$MEMORY_DIR" ]; then
  THIRTY_DAYS_AGO_TS=$(date -d "30 days ago" +%s 2>/dev/null || date -v-30d +%s 2>/dev/null || echo "0")
  STALE_MEMORIES=0
  for mem_file in "$MEMORY_DIR"/*.md; do
    [ -f "$mem_file" ] || continue
    MEM_TS=$(stat -c %Y "$mem_file" 2>/dev/null || stat -f %m "$mem_file" 2>/dev/null || echo "0")
    if [ "$MEM_TS" -lt "$THIRTY_DAYS_AGO_TS" ] 2>/dev/null; then
      STALE_MEMORIES=$((STALE_MEMORIES + 1))
    fi
  done
  if [ "$STALE_MEMORIES" -gt 0 ]; then
    NUDGES="${NUDGES}\n- ${STALE_MEMORIES} auto-memory file(s) older than 30 days. Consider running /cc-refresh."
  fi
fi

# Session JSONL total size
if [ -d "$CLAUDE_PROJECT_DIR" ]; then
  TOTAL_SIZE=0
  for jsonl in "$CLAUDE_PROJECT_DIR"/*.jsonl; do
    [ -f "$jsonl" ] || continue
    FSIZE=$(stat -c %s "$jsonl" 2>/dev/null || stat -f %z "$jsonl" 2>/dev/null || echo "0")
    TOTAL_SIZE=$((TOTAL_SIZE + FSIZE))
  done
  if [ "$TOTAL_SIZE" -gt 5242880 ]; then  # 5MB
    SIZE_MB=$((TOTAL_SIZE / 1048576))
    NUDGES="${NUDGES}\n- Session history is ${SIZE_MB}MB. Consider running /cc-refresh to archive old sessions."
  fi
fi

if [ -n "$NUDGES" ]; then
  echo "=== Maintenance Nudges ==="
  printf "%b\\n" "$NUDGES"
  echo ""
fi

# --- Ruflo pull (if available) ---
if [ -x ".claude/hooks/ruflo-sync.sh" ]; then
  .claude/hooks/ruflo-sync.sh pull 2>/dev/null || true
fi
```

Write to `template/.claude/hooks/session-start.sh`.

- [ ] **Step 2: Verify syntax**

```bash
bash -n template/.claude/hooks/session-start.sh
```

Expected: No output (syntax valid).

- [ ] **Step 3: Commit**

```bash
git add template/.claude/hooks/session-start.sh
git commit -m "feat: add session-start hook for knowledge store context reload"
```

---

### Task 11: Create context-watchdog.sh

**Files:**
- Create: `template/.claude/hooks/context-watchdog.sh`

- [ ] **Step 1: Write context-watchdog.sh**

```bash
#!/usr/bin/env bash
# context-watchdog.sh — monitors session JSONL growth and nudges persistence
# Event: PostToolUse (matcher: .*)
set -euo pipefail

KNOWLEDGE_DIR=".claude/knowledge"
LAST_RUN_FILE="$KNOWLEDGE_DIR/.watchdog-last-run"
LAST_SIZE_FILE="$KNOWLEDGE_DIR/.watchdog-last-size"
THRESHOLD="${CLAUDE_WATCHDOG_THRESHOLD:-102400}"  # 100KB default

# Missing-file safe
[ -d "$KNOWLEDGE_DIR" ] || exit 0

# Gate: skip if last run was < 3 minutes ago
if [ -f "$LAST_RUN_FILE" ]; then
  LAST_RUN_TS=$(stat -c %Y "$LAST_RUN_FILE" 2>/dev/null || stat -f %m "$LAST_RUN_FILE" 2>/dev/null || echo "0")
  NOW_TS=$(date +%s)
  ELAPSED=$((NOW_TS - LAST_RUN_TS))
  [ "$ELAPSED" -lt 180 ] && exit 0
fi

# Find current session JSONL
PROJECT_DIR=$(echo "$PWD" | sed 's|/|-|g; s|^-||')
CLAUDE_PROJECT_DIR="$HOME/.claude/projects/${PROJECT_DIR}"

# Fragile dependency: if path doesn't exist, skip silently
[ -d "$CLAUDE_PROJECT_DIR" ] || exit 0

# Find the most recently modified JSONL (current session)
CURRENT_JSONL=""
LATEST_TS=0
for jsonl in "$CLAUDE_PROJECT_DIR"/*.jsonl; do
  [ -f "$jsonl" ] || continue
  JTS=$(stat -c %Y "$jsonl" 2>/dev/null || stat -f %m "$jsonl" 2>/dev/null || echo "0")
  if [ "$JTS" -gt "$LATEST_TS" ]; then
    LATEST_TS=$JTS
    CURRENT_JSONL=$jsonl
  fi
done

[ -n "$CURRENT_JSONL" ] || exit 0

# Get current size via stat (never read the file)
CURRENT_SIZE=$(stat -c %s "$CURRENT_JSONL" 2>/dev/null || stat -f %z "$CURRENT_JSONL" 2>/dev/null || echo "0")

# Compare to last known size
LAST_SIZE=0
if [ -f "$LAST_SIZE_FILE" ]; then
  LAST_SIZE=$(cat "$LAST_SIZE_FILE" 2>/dev/null || echo "0")
fi

DELTA=$((CURRENT_SIZE - LAST_SIZE))

# Update state
echo "$CURRENT_SIZE" > "$LAST_SIZE_FILE"
touch "$LAST_RUN_FILE"

# Nudge if growth exceeds threshold
if [ "$DELTA" -gt "$THRESHOLD" ]; then
  echo "$CURRENT_SIZE" > "$LAST_SIZE_FILE"
  touch "$KNOWLEDGE_DIR/.needs-persist"
  DELTA_KB=$((DELTA / 1024))
  echo "Context has grown ${DELTA_KB}KB since last check. Consider persisting key decisions and active work to the knowledge store (.claude/knowledge/active-context.md)."
fi
```

Write to `template/.claude/hooks/context-watchdog.sh`.

- [ ] **Step 2: Verify syntax**

```bash
bash -n template/.claude/hooks/context-watchdog.sh
```

- [ ] **Step 3: Commit**

```bash
git add template/.claude/hooks/context-watchdog.sh
git commit -m "feat: add context-watchdog hook for session growth monitoring"
```

---

### Task 12: Create post-commit-persist.sh

**Files:**
- Create: `template/.claude/hooks/post-commit-persist.sh`

- [ ] **Step 1: Write post-commit-persist.sh**

```bash
#!/usr/bin/env bash
# post-commit-persist.sh — appends commit info to active-context after git commits
# Event: PostToolUse (matcher: Bash)
set -euo pipefail

KNOWLEDGE_DIR=".claude/knowledge"
ACTIVE_CONTEXT="$KNOWLEDGE_DIR/active-context.md"

# Missing-file safe
[ -d "$KNOWLEDGE_DIR" ] || exit 0
[ -f "$ACTIVE_CONTEXT" ] || exit 0

# Check if the tool input was a git commit
# Hook receives tool input on stdin as JSON
INPUT=$(cat)
COMMAND=$(echo "$INPUT" | grep -o '"command"[[:space:]]*:[[:space:]]*"[^"]*"' 2>/dev/null | head -1 | sed 's/.*"command"[[:space:]]*:[[:space:]]*"//;s/"$//' || true)

# Exit if not a git commit
case "$COMMAND" in
  *"git commit"*) ;;
  *) exit 0 ;;
esac

# Extract commit info
COMMIT_MSG=$(git log -1 --pretty=%s 2>/dev/null || echo "unknown")
COMMIT_HASH=$(git log -1 --pretty=%h 2>/dev/null || echo "unknown")
FILES_CHANGED=$(git diff --name-only HEAD~1 2>/dev/null | head -10 || echo "unknown")
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# Append to Recent Changes section
MARKER="## Recent Changes"
if ! grep -q "$MARKER" "$ACTIVE_CONTEXT" 2>/dev/null; then
  printf "\n%s\n" "$MARKER" >> "$ACTIVE_CONTEXT"
fi

{
  echo "- [$TIMESTAMP] \`$COMMIT_HASH\` $COMMIT_MSG"
  echo "$FILES_CHANGED" | sed 's/^/  - /'
} >> "$ACTIVE_CONTEXT"

# Update frontmatter timestamp (portable sed -i: try GNU, fall back to macOS)
sed_inplace() {
  if sed -i "s|$1|$2|" "$3" 2>/dev/null; then
    return 0
  else
    # macOS sed requires backup extension
    sed -i '' "s|$1|$2|" "$3" 2>/dev/null || true
  fi
}
if grep -q "^last_updated:" "$ACTIVE_CONTEXT" 2>/dev/null; then
  sed_inplace "^last_updated:.*" "last_updated: $TIMESTAMP" "$ACTIVE_CONTEXT"
fi
if grep -q "^last_updated_by:" "$ACTIVE_CONTEXT" 2>/dev/null; then
  sed_inplace "^last_updated_by:.*" "last_updated_by: post-commit-hook" "$ACTIVE_CONTEXT"
fi

# Clear needs-persist marker
rm -f "$KNOWLEDGE_DIR/.needs-persist" 2>/dev/null || true

# Ruflo push sync if knowledge files were in the commit
if echo "$FILES_CHANGED" | grep -q ".claude/knowledge/" 2>/dev/null; then
  if [ -x ".claude/hooks/ruflo-sync.sh" ]; then
    .claude/hooks/ruflo-sync.sh push 2>/dev/null || true
  fi
fi
```

Write to `template/.claude/hooks/post-commit-persist.sh`.

- [ ] **Step 2: Verify syntax**

```bash
bash -n template/.claude/hooks/post-commit-persist.sh
```

- [ ] **Step 3: Commit**

```bash
git add template/.claude/hooks/post-commit-persist.sh
git commit -m "feat: add post-commit-persist hook for tracking changes in knowledge store"
```

---

### Task 13: Create session-end.sh

**Files:**
- Create: `template/.claude/hooks/session-end.sh`

- [ ] **Step 1: Write session-end.sh**

```bash
#!/usr/bin/env bash
# session-end.sh — pushes knowledge store to ruflo on session close
# Event: SessionEnd
set -euo pipefail

# Lightweight — just trigger ruflo sync if available
if [ -x ".claude/hooks/ruflo-sync.sh" ]; then
  .claude/hooks/ruflo-sync.sh push 2>/dev/null || true
fi
```

Write to `template/.claude/hooks/session-end.sh`.

- [ ] **Step 2: Verify syntax**

```bash
bash -n template/.claude/hooks/session-end.sh
```

- [ ] **Step 3: Commit**

```bash
git add template/.claude/hooks/session-end.sh
git commit -m "feat: add session-end hook for ruflo memory sync on close"
```

---

### Task 14: Update Template settings.json with Hook Configuration

**Files:**
- Modify: `template/.claude/settings.json`

- [ ] **Step 1: Update settings.json hooks section**

The current settings.json has empty hook arrays. Replace with the configured hooks:

```json
{
  "permissions": {
    "allow": [
      "Bash(nix develop *)",
      "Bash(nix build *)",
      "Bash(nix flake *)",
      "Bash(ruflo mcp start)",
      "Bash(ruflo mcp stop)",
      "Bash(ruflo mcp status)",
      "mcp__ruflo__read_plan",
      "mcp__ruflo__list_tasks",
      "mcp__ruflo__get_task",
      "mcp__ruflo__update_task"
    ],
    "deny": [
      "Bash(cat .env*)",
      "Read(.env*)",
      "Bash(head .env*)",
      "Bash(tail .env*)",
      "Bash(less .env*)",
      "Bash(more .env*)",
      "Bash(grep * .env*)",
      "Bash(sed * .env*)",
      "Bash(awk * .env*)",
      "Bash(python*)",
      "Bash(node*)",
      "Bash(ruby*)",
      "Bash(perl*)",
      "Bash(rm -rf *)",
      "Bash(rm -r *)",
      "Bash(git push *)",
      "Bash(git push --force *)",
      "Bash(curl *)",
      "Bash(wget *)",
      "Bash(ssh *)",
      "Bash(scp *)",
      "Bash(sudo *)",
      "Bash(chmod *)",
      "Bash(chown *)",
      "Bash(nix-store --delete *)"
    ]
  },
  "hooks": {
    "SessionStart": [
      {
        "command": ".claude/hooks/session-start.sh"
      }
    ],
    "PreToolUse": [],
    "PostToolUse": [
      {
        "matcher": ".*",
        "command": ".claude/hooks/context-watchdog.sh"
      },
      {
        "matcher": "Bash",
        "command": ".claude/hooks/post-commit-persist.sh"
      }
    ],
    "SessionEnd": [
      {
        "command": ".claude/hooks/session-end.sh"
      }
    ]
  }
}
```

Use the Edit tool to replace the entire hooks section in `template/.claude/settings.json`.

- [ ] **Step 2: Commit**

```bash
git add template/.claude/settings.json
git commit -m "feat: configure hooks in template settings.json (session-start, watchdog, post-commit, session-end)"
```

---

### Task 15: Sync Phase 3 to Rust/Python Templates and Validate

**Files:**
- Sync hooks to: `templates/rust/.claude/hooks/`, `templates/python/.claude/hooks/`
- Sync settings to: `templates/rust/.claude/settings.json`, `templates/python/.claude/settings.json`

- [ ] **Step 1: Copy hooks to both templates**

```bash
rm -f templates/rust/.claude/hooks/.gitkeep templates/python/.claude/hooks/.gitkeep
cp template/.claude/hooks/*.sh templates/rust/.claude/hooks/
cp template/.claude/hooks/*.sh templates/python/.claude/hooks/
chmod +x templates/rust/.claude/hooks/*.sh
chmod +x templates/python/.claude/hooks/*.sh
```

- [ ] **Step 2: Copy updated settings.json**

```bash
cp template/.claude/settings.json templates/rust/.claude/settings.json
cp template/.claude/settings.json templates/python/.claude/settings.json
```

- [ ] **Step 3: Validate and commit**

```bash
nix flake check
bash -n template/.claude/hooks/*.sh
git add templates/
git commit -m "feat: sync hooks and settings to rust/python templates"
```

---

## Phase 4: ruflo-builder Skill + Bridge

### Task 16: Create the ruflo-builder Skill

**Files:**
- Create: `template/.claude/skills/ruflo-builder/SKILL.md`

- [ ] **Step 1: Write the ruflo-builder SKILL.md**

```markdown
---
name: ruflo-builder
description: >
  Scaffold custom ruflo agents, workflows, and swarm configurations tailored to the current project.
  Reads the knowledge store to auto-fill project-specific values into ruflo workflow templates.
  Use when the user says "build ruflo agents", "create ruflo workflow", "scaffold a swarm",
  "set up ruflo agents for this project", "custom ruflo workflow", "create an agent for [task]",
  or any variation of wanting to build ruflo-powered automation for their project.
tools: Read, Glob, Grep, Bash, Write
---

# Ruflo Builder

Scaffold custom ruflo agents, workflows, and swarm configurations by reading the project's
knowledge store and generating tailored configs with real values — no placeholders.

**This skill writes files.** It generates ruflo workflow JSON, agent prompt files, and
CLI command scripts. All outputs are saved to `project/workflows/`.

## Prerequisites

1. Check if ruflo is available: `command -v ruflo`
   - If not available: warn the user but still generate the config files (they can be
     used when ruflo becomes available)
2. Check if knowledge store exists at `.claude/knowledge/`
   - If yes: read all knowledge files to gather project context
   - If no: warn the user and suggest running `/cc-onboard` first. Still proceed if
     the user wants to — gather context by reading CLAUDE.md and scanning manually.

## Workflow

### Step 1: Gather Project Context

Read these files to understand the project:
- `.claude/knowledge/architecture-snapshot.md` → stack, structure, entry points
- `.claude/knowledge/conventions.md` → naming, testing, build patterns
- `.claude/knowledge/active-context.md` → current focus and recent work
- `.claude/knowledge/decisions.md` → active architectural decisions
- `CLAUDE.md` → commands, high-level overview

Extract and store internally:
- `PROJECT_NAME` — from CLAUDE.md header or directory name
- `TECH_STACK` — from architecture-snapshot Stack section
- `ARCHETYPE` — infer from structure (web app, API, CLI, library, data pipeline, etc.)
- `TEST_FRAMEWORK` — from conventions Testing Patterns section
- `BUILD_COMMANDS` — from CLAUDE.md Commands section
- `DOMAIN` — from CLAUDE.md or active decisions if available

### Step 2: Ask What to Build

Present options:

> "What would you like to build with ruflo?"
>
> **(A)** A custom agent role — a specialized agent for a specific task in your project
>   (e.g., "a migration specialist", "a security reviewer for our auth module")
>
> **(B)** A workflow for a task — a multi-step pipeline for a recurring job
>   (e.g., "a code review workflow", "a deploy preparation checklist")
>
> **(C)** A full swarm config — a complete team for a project phase
>   (e.g., "a testing swarm for our API", "a documentation swarm")
>
> **(D)** A ruflo memory namespace setup — configure shared memory for agent coordination

### Step 3: Generate Based on Choice

#### Choice A: Custom Agent Role

Ask:
1. "What should this agent specialize in?" (open-ended)
2. "What tools/files should it have access to?" (suggest based on knowledge store)

Generate `project/workflows/agents/<agent-name>.json`:
```json
{
  "role": "<agent-name>",
  "description": "<what it does>",
  "claudePrompt": "<detailed prompt incorporating project context from knowledge store>",
  "tools": ["<relevant tools>"]
}
```

The `claudePrompt` must include:
- Project context pulled from knowledge store (actual values, not placeholders)
- Instruction to query ruflo memory for additional context
- Specific file paths and patterns from the architecture snapshot

#### Choice B: Task Workflow

Ask:
1. "Describe the workflow — what are the steps?" (open-ended)
2. "Should any steps run in parallel?" (yes/no, which ones)

Generate `project/workflows/<workflow-name>.json`:
```json
{
  "name": "<workflow-name>",
  "description": "<purpose>",
  "tasks": [
    {
      "id": "<step-id>",
      "assignTo": "<agent-type>",
      "depends": [],
      "description": "<what this step does>",
      "claudePrompt": "<prompt with project context baked in>"
    }
  ]
}
```

All `claudePrompt` values include:
- "Project context available via ruflo memory (namespace: project)."
- "Run `ruflo memory query 'architecture' --namespace project` for codebase structure."
- "Run `ruflo memory query 'conventions' --namespace project` for coding patterns."
- Actual project-specific details from the knowledge store.

#### Choice C: Full Swarm Config

Ask:
1. "What phase is this for?" (prototype, MVP, production, testing, documentation, custom)
2. "Any specific focus areas?" (open-ended)

Use the workflow templates from `virtual-tech-org/references/ruflo-config.md` as the base.
Read that reference file, then customize:
- Replace all `{{PLACEHOLDER}}` values with actual project context
- Remove tasks that don't apply to the project archetype
- Add domain-specific tasks if relevant

Generate `project/workflows/swarm-<phase>.json`.

#### Choice D: Memory Namespace Setup

Generate a setup script `project/workflows/setup-memory.sh`:
```bash
#!/usr/bin/env bash
# Initialize ruflo memory with project knowledge store
set -euo pipefail

RUFLO_CMD="ruflo"
command -v $RUFLO_CMD >/dev/null 2>&1 || { echo "ruflo not found"; exit 1; }

# Store knowledge
$RUFLO_CMD memory store "architecture" "$(cat .claude/knowledge/architecture-snapshot.md)" --namespace project
$RUFLO_CMD memory store "conventions" "$(cat .claude/knowledge/conventions.md)" --namespace project
$RUFLO_CMD memory store "decisions" "$(cat .claude/knowledge/decisions.md)" --namespace project
$RUFLO_CMD memory store "active-context" "$(cat .claude/knowledge/active-context.md)" --namespace project

# Store project metadata
$RUFLO_CMD memory store "project-name" "<PROJECT_NAME>" --namespace project
$RUFLO_CMD memory store "tech-stack" "<TECH_STACK_JSON>" --namespace project

echo "Memory initialized. Agents can query: ruflo memory query '<key>' --namespace project"
```

Fill in actual values for `<PROJECT_NAME>` and `<TECH_STACK_JSON>`.

### Step 4: Test Availability

If ruflo is available:
> "Want me to do a dry-run? I'll validate the config without executing it."

Run: `ruflo automation validate <workflow.json>` if available, or check JSON syntax.

### Step 5: Save and Integrate

1. Create `project/workflows/` directory if needed
2. Write generated file(s)
3. Show the user what was generated and how to run it:
   ```
   Workflow saved to project/workflows/<name>.json

   To run:
     ruflo automation run-workflow project/workflows/<name>.json --claude --non-interactive

   To monitor:
     ruflo hive-mind status
   ```
4. If new agent types were created, note that they can be referenced in future workflows
```

Write to `template/.claude/skills/ruflo-builder/SKILL.md`.

- [ ] **Step 2: Commit**

```bash
git add template/.claude/skills/ruflo-builder/
git commit -m "feat: add ruflo-builder skill for scaffolding custom ruflo workflows from knowledge store"
```

---

### Task 17: Sync Phase 4 to Templates, Update CLAUDE.md, Final Validation

**Files:**
- Sync to: `templates/rust/.claude/skills/ruflo-builder/`, `templates/python/.claude/skills/ruflo-builder/`
- Modify: `CLAUDE.md` (project root — update with new commands and skills)

- [ ] **Step 1: Copy ruflo-builder skill to both templates**

```bash
mkdir -p templates/rust/.claude/skills/ruflo-builder templates/python/.claude/skills/ruflo-builder
cp template/.claude/skills/ruflo-builder/SKILL.md templates/rust/.claude/skills/ruflo-builder/
cp template/.claude/skills/ruflo-builder/SKILL.md templates/python/.claude/skills/ruflo-builder/
```

- [ ] **Step 2: Update project CLAUDE.md**

Update the root `CLAUDE.md` to document the new skills, commands, and knowledge store. Add to the Structure section:

```markdown
- `template/.claude/knowledge/` — knowledge store templates (active-context, decisions, architecture, conventions, stale-log)
- `template/.claude/hooks/` — hook scripts (session-start, context-watchdog, post-commit-persist, session-end, ruflo-sync)
```

Add to the Commands section:

```markdown
- `nix run .#onboard` — bootstrap Claude Code onto an existing project (copies skeleton files)
```

Add to the Workflow section:

```markdown
5. OR use `/cc-onboard` on an existing repo to bootstrap Claude Code from existing code (brownfield)
6. Use `/cc-refresh` periodically to clean up stale context, memory, and session history
7. Use `/ruflo-builder` to scaffold custom ruflo agents and workflows from the knowledge store
```

- [ ] **Step 3: Update template CLAUDE.md**

Update `template/CLAUDE.md` to mention the knowledge store and new skills:

Add a Knowledge Store section:

```markdown
## Knowledge Store

Project context persists in `.claude/knowledge/`:
- `active-context.md` — current focus, recent decisions, blockers
- `decisions.md` — architectural decisions in effect
- `architecture-snapshot.md` — codebase structure (auto-generated)
- `conventions.md` — coding patterns (auto-generated)
- `stale-log.md` — audit trail of removed items

Hooks automatically maintain this store. Run `/cc-refresh` to audit and clean up.
```

Update the Getting Started section to include `/cc-onboard` as an option.

- [ ] **Step 4: Final validation**

```bash
nix flake check
bash -n template/.claude/hooks/*.sh
```

Expected: Clean.

- [ ] **Step 5: Commit**

```bash
git add templates/ CLAUDE.md template/CLAUDE.md
git commit -m "feat: complete knowledge management system — sync Phase 4 and update docs"
```
