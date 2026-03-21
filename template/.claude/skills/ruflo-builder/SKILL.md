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
