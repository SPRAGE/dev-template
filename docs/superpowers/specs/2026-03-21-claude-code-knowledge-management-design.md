# Claude Code Knowledge Management System

**Date:** 2026-03-21
**Status:** Approved
**Approach:** Layered Architecture (Approach C)

## Problem Statement

Four equally painful gaps in the dev-template's Claude Code experience:

1. **No onboarding for existing repos** — cc-project-setup works top-down from brainstorm briefs, but there's no way to bootstrap Claude Code onto an existing codebase bottom-up.
2. **Stale context accumulates** — CLAUDE.md drifts, memory files reference deleted code, session JSONL files grow unbounded, knowledge store entries go stale.
3. **Context window compression loses knowledge** — when Claude compresses older messages, key decisions and active context are lost with no recovery mechanism.
4. **Claude and ruflo are separate worlds** — Claude's auto-memory and ruflo's memory system don't communicate, so agents and sessions can't share knowledge.

## Architecture Overview

Four layers, each independently shippable:

```
Layer 4: Ruflo Bridge          (optional, enhances)
         ↕ sync
Layer 3: Hooks                 (automatic, proactive)
         ↕ read/write
Layer 2: Skills                (user-invoked capabilities)
         ↕ read/write
Layer 1: Knowledge Store       (file-based, always works)
```

## Layer 1: Knowledge Store

**Location:** `.claude/knowledge/`

A structured, file-based persistent knowledge store that lives in the project. Human-readable, git-trackable, diffable.

### Files

| File | Purpose | Updated by |
|------|---------|------------|
| `active-context.md` | Current WIP, active decisions, blockers, recent changes. The "hot" context loaded on session start. | Session-end hook, post-commit hook, `/cc-refresh` |
| `decisions.md` | Architectural and design decisions still in effect. | Skills, manual, `/cc-refresh` prunes reversed decisions |
| `architecture-snapshot.md` | Current codebase structure — directories, entry points, dependency graph, data flow. Auto-generated from scanning. | `/cc-onboard`, `/cc-refresh` |
| `conventions.md` | Coding patterns, naming conventions, error handling, testing patterns detected from code. | `/cc-onboard`, `/cc-refresh` |
| `stale-log.md` | Append-only log of what was removed and why during refresh operations. Safety net for incorrect pruning. | `/cc-refresh` |

### Schema: active-context.md

```markdown
---
last_updated: 2026-03-21T14:30:00Z
last_updated_by: human | session-end-hook | cc-refresh
---

## Current Focus
[What is actively being worked on right now]

## Recent Decisions
[Decisions made in the last 1-3 sessions not yet moved to decisions.md]

## Recent Changes
[Commits and file changes from recent sessions — appended by post-commit hook]

## Open Questions
[Unresolved questions that need answers]

## Key Files in Play
[Files being actively modified — paths + why they matter]

## Blockers
[Anything blocking progress]
```

### Schema: architecture-snapshot.md

```markdown
---
last_updated: 2026-03-21T14:30:00Z
generated_by: cc-onboard | cc-refresh
---

## Stack
[Languages, frameworks, key libraries — detected from config files]

## Directory Structure
[Key directories and what lives in each — from actual tree scan]

## Entry Points
[Main files, CLI entry points, server start files, test runners]

## Dependencies
[Key dependency graph — what depends on what, external service deps]

## Data Flow
[How data moves through the system — only if applicable]
```

### Schema: conventions.md

```markdown
---
last_updated: 2026-03-21T14:30:00Z
generated_by: cc-onboard | cc-refresh
---

## Naming Patterns
[snake_case vs camelCase, file naming, module naming — detected from code samples]

## Error Handling
[How errors are handled — Result types, exceptions, error codes — detected patterns]

## Testing Patterns
[Test framework, test file locations, test naming, assertion style]

## Import/Module Patterns
[How imports are organized, module system conventions]

## Build & Tooling
[Build commands, linter config, formatter config, CI patterns]
```

### Schema: decisions.md

```markdown
## [Decision Title]
- **Date:** YYYY-MM-DD
- **Status:** active | superseded by [other decision]
- **Decision:** [What was decided]
- **Why:** [Reasoning]
- **Alternatives considered:** [What else was on the table]
```

### Design Principles

- **Files, not databases.** Human-readable, git-trackable, diffable.
- **Single concern per file.** No monolithic knowledge dump.
- **Active-context is critical.** This is the reload point after context compression.
- **Stale-log is append-only.** Never edited, only appended. Safety net.

## Layer 2: Skills

### 2a: `/cc-onboard` Skill

**Trigger:** "onboard claude code", "set up claude code for this repo", "bootstrap claude code", "add claude code to this project"

**Two-phase design:**

#### Phase 1 — External bootstrap (`nix run .#onboard`)

- Checks if `.claude/` already exists — warns and asks to confirm if so
- Copies skeleton files:
  - `.claude/settings.json` (default permissions)
  - `.claude/knowledge/` with empty templates for all 5 knowledge store files
  - `.claude/hooks/` with all 4 hook scripts
  - `.mcp.json` (ruflo MCP server)
  - Stub `CLAUDE.md` with "run /cc-onboard to generate" marker
- Prints next steps: direnv allow, open Claude Code, run `/cc-onboard`

#### Phase 2 — `/cc-onboard` skill (inside Claude Code)

1. **Detect existing state** — check what exists. If Phase 1 wasn't run, do minimal bootstrap inline.
2. **Scan codebase** using parallel Agent tool dispatches (Claude Code's built-in subagent mechanism — each runs as a separate Claude instance with its own context):
   - Language/framework detector agent — glob for telltale files, read configs
   - Structure mapper agent — directory tree, entry points, test dirs, config locations
   - Convention detector agent — sample source files, detect naming/error/test patterns
   - Command discoverer agent — parse Makefiles, package.json, Cargo.toml, flake.nix
3. **Generate artifacts:**
   - `CLAUDE.md` — populated with real commands, architecture, conventions
   - `.mcp.json` — servers selected by detected stack
   - `.claude/rules/` — 1-3 rule files based on detected patterns
   - `.claude/knowledge/architecture-snapshot.md` — from scan
   - `.claude/knowledge/conventions.md` — from scan
   - `.claude/knowledge/active-context.md` — initialized with onboard state
   - `.claude/knowledge/decisions.md` — empty, ready for use
   - `.claude/knowledge/stale-log.md` — initialized with onboard timestamp
4. **Present to user** — show generated artifacts, explain choices, ask approval before writing
5. **Optional ruflo setup** — if ruflo available, offer to init ruflo memory with knowledge store

**Distinction from cc-project-setup:** cc-project-setup works top-down from brainstorm briefs (greenfield). cc-onboard works bottom-up from existing code (brownfield). They complement each other.

### 2b: `/cc-refresh` Skill

**Trigger:** "refresh claude context", "clean up claude memory", "prune stale context", "context cleanup"

**Workflow:**

1. **Audit phase** — scan all Claude Code artifacts in parallel:

   | Target | Checks |
   |--------|--------|
   | `CLAUDE.md` | Commands valid? Architecture matches dirs? Conventions match code? |
   | `.claude/knowledge/*` | Decisions still active? Snapshot matches reality? Active-context refs exist? |
   | `~/.claude/projects/<path>/memory/*` | Memory files reference existing functions/files? Reversed decisions? (Note: path is internal to Claude Code and may change between versions. Skill should discover path dynamically and skip gracefully if not found.) |
   | `~/.claude/projects/<path>/*.jsonl` | Session count, total size, age of oldest. (Same fragile-path caveat as memory.) |
   | `.claude/rules/*` | Rules relevant to current codebase? |

2. **Report phase** — structured findings per target with specific issues found.

3. **Propose actions** — for each finding:
   - **Update:** rewrite stale content with current state
   - **Archive:** move old sessions to `.claude/archive/`
   - **Prune:** remove stale memory files (logged to stale-log.md)
   - **Supersede:** mark reversed decisions

4. **User approves** — granular approval (all, per-category, or per-item). Declined items are logged to stdout with "Skipped: [reason]" so the user has a record, but no file changes are made for them. The skill does not re-prompt for declined items.

5. **Execute** — apply approved changes, append all removals to `stale-log.md`.

**Dry-run support:** When invoked as `/cc-refresh --dry-run` (or when the user asks for a preview), the skill runs the audit and report phases only — no proposals, no file changes. Useful for scripting and CI checks.

6. **Optional ruflo sync** — if available, sync updated knowledge store to ruflo memory.

### 2c: `/ruflo-builder` Skill

**Trigger:** "build ruflo agents", "create ruflo workflow", "scaffold a swarm", "custom ruflo workflow"

**Workflow:**

1. **Read project knowledge** — load `.claude/knowledge/` for project context
2. **Ask what to build:**
   - (A) Custom agent role
   - (B) Workflow for a specific task
   - (C) Full swarm config for a project phase
   - (D) Ruflo memory namespace setup
3. **Generate config** — ruflo workflow JSON, agent prompts, CLI commands, all tailored from knowledge store (no `{{PLACEHOLDER}}` — real values)
4. **Test availability** — verify ruflo accessible, offer dry-run
5. **Save and integrate** — save to `project/workflows/`, update `.mcp.json` if needed

## Layer 3: Hooks

All hooks follow these principles:
- **Fast by default.** Gate condition check first, bail early. Target < 50ms when skipping.
- **Knowledge store maintenance only.** Hooks may append to knowledge store files (active-context.md, .needs-persist marker) but never modify source code, CLAUDE.md, or primary project files. All substantive changes go through skills with user approval.
- **Inspectable.** Shell scripts in `.claude/hooks/`, readable and editable.
- **Missing-file safe.** All hooks check for knowledge store file existence before reading/writing. If files are missing (e.g., Phase 2 pruned them before Phase 3 hooks were installed), hooks exit 0 gracefully — never error.

### 3a: Session-Start Hook

**Event:** `SessionStart` (native Claude Code hook event — fires once at session start)

No flag-file workaround needed. Claude Code supports `SessionStart` as a first-class hook event.

**Behavior:**
- Reads `active-context.md` (if it exists), outputs to stdout (Claude sees as hook output)
- Surfaces decisions from last 7 days from `decisions.md`
- Surfaces recent agent outputs from `.claude/knowledge/agent-outputs/` (last 3 days)
- Staleness checks:
  - If `architecture-snapshot.md` older than 14 days → nudge: "Architecture snapshot is stale. Consider running /cc-refresh."
  - If auto-memory files older than 30 days → nudge to run `/cc-refresh`
  - If session JSONL total > 5MB → nudge to archive old sessions
- Triggers ruflo pull sync (if ruflo available) to surface agent outputs

### 3b: Context Watchdog Hook

**Event:** `PostToolUse` on `.*`

**Behavior:**
- Checks timestamp file `.claude/knowledge/.watchdog-last-run` — skips if last run < 3 minutes ago (single `stat` call, ~1ms)
- When it does run: uses `stat -c %s` (Linux) or `stat -f %z` (macOS) on the current session JSONL file to get size — never reads the file content
- Stores the byte count in `.claude/knowledge/.watchdog-last-size`
- If growth delta > 100KB since last check (configurable via `CLAUDE_WATCHDOG_THRESHOLD` env var, default 100KB), writes `.claude/knowledge/.needs-persist` marker
- Outputs nudge: "Context is growing. Key decisions and active work should be persisted to knowledge store."
- This is a heuristic proxy for context compression — can't intercept compact directly, but JSONL growth rate correlates

**Fragile dependency note:** The session JSONL path (`~/.claude/projects/<path>/*.jsonl`) is an internal Claude Code implementation detail. If the path format changes between Claude Code versions, this hook will silently skip (no JSONL found = no size check = no nudge). The core functionality (knowledge store, skills) is unaffected.

### 3c: Post-Commit Persist Hook

**Event:** `PostToolUse` on `Bash`

**Behavior:**
- Receives tool input on stdin as JSON; checks if the command contains `git commit` — exits immediately if not
- Extracts commit message via `git log -1 --pretty=%s` and files changed via `git diff --name-only HEAD~1`
- Appends to `active-context.md` "Recent Changes" section (knowledge store maintenance, not source modification)
- If `.claude/knowledge/` files were modified in the commit, triggers ruflo push sync (if available)
- Clears `.needs-persist` marker if set

### 3d: Session-End Hook

**Event:** `SessionEnd` (native Claude Code hook event — fires when session closes)

**Behavior:**
- Triggers ruflo push sync (if available) to persist latest knowledge store to ruflo memory
- Lightweight — just the sync call, no analysis

### 3e: Hook Configuration

Added to `.claude/settings.json` in template. Hook schema uses `matcher` (regex for tool name filtering, applies to PreToolUse/PostToolUse only) and `command` (shell command to execute):

```json
{
  "hooks": {
    "SessionStart": [
      {
        "command": ".claude/hooks/session-start.sh"
      }
    ],
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

**Note:** The hook object schema (`matcher`, `command`) matches the structure used in Claude Code's settings.json. `matcher` is only applicable to PreToolUse/PostToolUse events. SessionStart/SessionEnd hooks omit `matcher` since they are not tool-scoped.

## Layer 4: Ruflo Bridge

### Sync Model

Bidirectional with clear ownership:

| Data | Owner | Direction |
|------|-------|-----------|
| `active-context.md` | Claude sessions | Claude -> ruflo (read-only for agents) |
| `decisions.md` | Claude sessions | Claude -> ruflo (read-only for agents) |
| `architecture-snapshot.md` | Either | Bidirectional |
| `conventions.md` | Either | Bidirectional |
| Agent outputs | Ruflo agents | ruflo -> Claude |
| Swarm status/metrics | Ruflo | ruflo -> Claude |

**Conflict resolution:** Last-write-wins with stale-log audit trail. For bidirectional files (`architecture-snapshot.md`, `conventions.md`), every sync overwrite appends the overwritten content to `stale-log.md` with a `[sync-overwrite]` tag, timestamp, and source (claude vs ruflo). This ensures silent data loss is detectable and recoverable.

### Sync Mechanism

Single script: `.claude/hooks/ruflo-sync.sh`

**Usage:** `ruflo-sync.sh [push|pull|both]`

**Push (knowledge -> ruflo memory):**
```bash
ruflo memory store "active-context" "$(cat .claude/knowledge/active-context.md)" --namespace project
ruflo memory store "decisions" "$(cat .claude/knowledge/decisions.md)" --namespace project
```

**Pull (ruflo memory -> knowledge):**
- Queries `agent-output` keys from ruflo memory
- Writes to `.claude/knowledge/agent-outputs/<workflow>-<timestamp>.md`
- Updates `active-context.md` with "Latest agent activity" section

**When sync runs:**
- Push: after `/cc-onboard`, after `/cc-refresh`, after post-commit hook
- Pull: on session-start hook, on-demand via `/ruflo-builder`
- Both: on explicit user request

**Graceful degradation:**
```bash
command -v ruflo >/dev/null 2>&1 || { echo "ruflo not available, skipping sync"; exit 0; }
```

### Agent Knowledge Access

`/ruflo-builder` injects knowledge store awareness into generated agent prompts:
```json
"claudePrompt": "...Project context available via ruflo memory (namespace: project). Run `ruflo memory query 'architecture' --namespace project` to understand the codebase..."
```

### Agent Output Capture

Agent outputs go to:
- `.claude/knowledge/agent-outputs/<workflow-name>-<timestamp>.md`
- Ruflo memory under `agent-output-<workflow-name>` key

Session-start hook surfaces recent agent outputs so Claude knows what swarms accomplished since last session.

## External Bootstrap: `nix run .#onboard`

Added to `flake.nix` as `apps.onboard`.

**Behavior:**

1. Detect state:
   - No `.claude/` -> full bootstrap
   - `.claude/` exists but no `knowledge/` -> add knowledge store only
   - Everything exists -> warn, suggest `/cc-refresh`

2. Copy files (full bootstrap):
   ```
   .claude/
   ├── settings.json
   ├── knowledge/
   │   ├── active-context.md
   │   ├── decisions.md
   │   ├── architecture-snapshot.md
   │   ├── conventions.md
   │   └── stale-log.md
   ├── hooks/
   │   ├── session-start.sh
   │   ├── context-watchdog.sh
   │   ├── post-commit-persist.sh
   │   ├── session-end.sh
   │   └── ruflo-sync.sh
   └── skills/               (via existing sync-skills)
   .mcp.json
   CLAUDE.md                 (stub)
   ```

3. `chmod +x .claude/hooks/*.sh`

4. Print next steps.

**Note:** `nix run .#onboard` always runs outside Claude Code in the user's shell. The `chmod` call is a direct shell command, not routed through Claude Code's Bash tool (which has `chmod` in its deny list).

**Relationship to sync-skills:** `onboard` runs once for initial setup. `sync-skills` runs whenever you want the latest skills. The existing `sync-skills` app syncs only `.claude/skills/`. It should be expanded to also sync `.claude/hooks/` and `.claude/knowledge/` templates (empty schemas only — never overwrite populated knowledge files). This ensures hook updates and new knowledge store schema fields propagate to existing projects.

## New Files Added to Template

| Path | Type | Purpose |
|------|------|---------|
| `template/.claude/knowledge/active-context.md` | Template | Empty schema |
| `template/.claude/knowledge/decisions.md` | Template | Empty schema |
| `template/.claude/knowledge/architecture-snapshot.md` | Template | Empty, filled by onboard |
| `template/.claude/knowledge/conventions.md` | Template | Empty, filled by onboard |
| `template/.claude/knowledge/stale-log.md` | Template | Initialized with creation date |
| `template/.claude/hooks/session-start.sh` | Hook | Context reload on SessionStart |
| `template/.claude/hooks/context-watchdog.sh` | Hook | Monitor context pressure |
| `template/.claude/hooks/post-commit-persist.sh` | Hook | Persist on commit |
| `template/.claude/hooks/session-end.sh` | Hook | Ruflo push sync on SessionEnd |
| `template/.claude/hooks/ruflo-sync.sh` | Hook | Bidirectional ruflo sync |
| `template/.claude/skills/cc-onboard/SKILL.md` | Skill | Codebase scan + config gen |
| `template/.claude/skills/cc-refresh/SKILL.md` | Skill | Audit + prune stale context |
| `template/.claude/skills/ruflo-builder/SKILL.md` | Skill | Scaffold ruflo workflows |
| `flake.nix` (modified) | Nix app | `apps.onboard` |

## Build Order

| Phase | Ships | Enables |
|-------|-------|---------|
| **1** | Knowledge store templates + `/cc-onboard` skill + `nix run .#onboard` | Bootstrap Claude Code on any existing repo with intelligent scanning |
| **2** | `/cc-refresh` skill | Clean stale context across CLAUDE.md, memory, knowledge store, sessions |
| **3** | All 4 hooks | Automatic memory management — reload, compression protection, commit checkpoints |
| **4** | `/ruflo-builder` skill + ruflo bridge sync | Custom ruflo workflows, bidirectional Claude-ruflo memory sync |

Each phase is independently shippable and testable.
