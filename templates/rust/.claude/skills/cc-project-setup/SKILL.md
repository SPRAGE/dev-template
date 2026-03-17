---
name: cc-project-setup
description: >
  Generates a complete Claude Code project setup — CLAUDE.md, .mcp.json, .claude/rules/,
  and workflow tips — tailored to a project's stack and goals. Works after a project-brainstorm
  session or standalone. Use whenever the user says "set up Claude Code for this project",
  "generate a CLAUDE.md", "what MCP servers should I use", "configure Claude Code", "create
  a .mcp.json", "what plugins for Claude Code", or finishes a brainstorm and wants to start
  building. Also trigger for "prepare my project for Claude Code", "set up my dev environment",
  or any request about Claude Code workflow, MCP config, or project memory files. This skill
  is about Claude Code (the CLI tool), not Claude.ai or Claude Desktop.
---

# Claude Code Setup Generator

You take a project plan (ideally from a brainstorm session, but any description works) and
produce a ready-to-use Claude Code configuration: the files, the MCP servers, the rules, and
the workflow advice that will make Claude Code effective for that specific project.

## When This Skill Runs

There are two entry points:

1. **Post-brainstorm**: The user just finished a project brainstorm (Phase 7 brief exists in
   conversation history). Extract everything you need from the brief — don't re-ask questions
   that were already answered.

2. **Standalone**: The user describes a project and wants Claude Code setup. Gather the minimum
   info you need (see Quick Intake below), then generate.

## Quick Intake (Standalone Mode Only)

If there's no brainstorm brief in the conversation, ask these questions (use `ask_user_input`
for bounded choices, prose for open-ended):

1. "Describe the project in a sentence or two — what does it do and what's the stack?"
2. "What languages and key frameworks are you using?" (offer common options via ask_user_input)
3. "Where does the code live — GitHub, GitLab, local only?"
4. "What's your package manager / build tool?" (offer options based on detected languages)
5. "Is this solo or team?"

That's it. Five questions max. Don't over-interview — make reasonable assumptions and state them.

## What You Generate

Read `references/mcp-catalog.md` before generating anything. It contains the MCP server catalog,
`.mcp.json` format, CLAUDE.md best practices, and rule file patterns you should follow.

For every project, produce these deliverables:

### 1. CLAUDE.md

A project-root CLAUDE.md file. Follow these rules strictly:

- **Under 100 lines.** Aim for 40-80. Every line should earn its place.
- **No fluff.** No "Welcome to the project" preamble. Start with the one-liner.
- **Exact commands.** Not "run the tests" but the actual command string.
- **Specific conventions.** Not "write clean code" but "use snake_case for functions, PascalCase for types".
- **Architecture map.** Brief directory listing showing where key things live.

Structure the file in this order:
```
# [Project Name]
[One-line description]

## Stack
[Languages, frameworks, key libraries — as a short list]

## Commands
[Build, test, lint, format, run — exact strings]

## Architecture
[Key directories and what lives in each]

## Conventions
[Naming, patterns, error handling approach, etc.]

## Important Notes
[Gotchas, things that are easy to get wrong, non-obvious decisions]
```

Adapt sections based on the project. A simple CLI tool doesn't need a full architecture section.
A Nix config project needs a module structure section instead.

### 2. .mcp.json

A project-scoped MCP configuration file. Only include servers that are genuinely useful for
this specific project — don't dump every possible server in.

Selection criteria:
- Does the project use GitHub? → GitHub MCP
- Does the project have a database? → appropriate database MCP
- Is this a web app that needs E2E testing? → Playwright MCP
- Is the user working with specific library docs? → Context7 MCP
- Does the project integrate with Figma designs? → Figma MCP

Use environment variable expansion (`${VAR}`) for all secrets and tokens. Never hardcode
credentials. Add a comment-style note (in the skill output, not the JSON) about which env
vars the user needs to set.

### 3. .claude/rules/ Files

Generate 1-3 focused rule files based on the project's domains. Each file should be:
- 10-25 lines
- Focused on one concern (testing, API conventions, styling, etc.)
- Written as clear, actionable directives

Don't create rule files for things that linters or formatters already handle.

### 4. Workflow Recommendations

A short section (not a file — just advice in your response) covering:

- **Session workflow**: How to use Claude Code effectively for this project type.
  For example: "Start sessions with `claude --add-dir ../shared-lib` to include the shared
  library" or "Use `/compact` frequently in long refactoring sessions".
- **Useful slash commands**: Which built-in commands matter most for this project.
- **Multi-agent patterns**: If the project is complex enough, suggest when to use
  parallel agents or worktrees.
- **What NOT to ask Claude Code to do**: Things better handled by other tools (e.g.,
  "Don't ask Claude to format code — your Prettier config handles that").

### 5. Setup Script (Optional)

If the MCP setup involves multiple `claude mcp add` commands or env var exports, generate
a small shell script the user can run to bootstrap everything. Name it `setup-claude-code.sh`.

## Presentation

Present the deliverables in this order:

1. **Quick summary**: "Here's what I'm setting up for [project] and why."
2. **CLAUDE.md**: Show the full content, explain any non-obvious choices.
3. **.mcp.json**: Show the config, list the env vars they need to set.
4. **Rules files**: Show each one with a one-line explanation of what it handles.
5. **Workflow tips**: The advice section.
6. **Setup script**: If generated.

Save all files to the appropriate output location. Create the directory structure:
```
[project-name]-claude-setup/
├── CLAUDE.md
├── .mcp.json
└── .claude/
    └── rules/
        ├── [rule-1].md
        └── [rule-2].md
```

If there's a setup script, include it at the root of this directory.

## Adaptation by Stack

### Rust Projects
- Emphasize `cargo` commands (build, test, clippy, fmt)
- Note the Rust Analyzer integration
- If using a Nix flake for builds, include the `nix build` / `nix develop` commands
- Rule file for error handling patterns (Result/Option conventions, thiserror vs anyhow)

### Python Projects
- Include the package manager commands (uv, pip, poetry, etc.)
- Note virtual environment activation if relevant
- Type hinting conventions in rules
- pytest conventions if applicable

### Nix / NixOS Config Projects
- Module structure as the architecture section
- `nixos-rebuild` commands with exact flags
- Flake-specific commands (nix flake check, nix flake update)
- Rule file for Nix idioms (when to use mkIf, lib patterns, etc.)

### Web Apps (React, Svelte, etc.)
- Dev server, build, and preview commands
- Component file structure conventions
- API route patterns in rules
- Playwright MCP if E2E testing is in scope

### Data / Analytics Projects
- Database connection details (sanitized) in CLAUDE.md
- Query conventions in rules
- Data directory structure in architecture section

## Important Constraints

- Never include actual secrets, tokens, or passwords in any generated file.
- Always use `${ENV_VAR}` expansion for sensitive values.
- If the user's project is a Nix flake, don't recommend `npm`/`npx`-based MCP servers
  without noting that the user may prefer to wrap them in a Nix shell or devShell.
- The CLAUDE.md must be genuinely useful on day one — not a template with placeholders
  the user has to fill in. Use the information from the brainstorm or intake to populate
  real values.
- If you don't know something (e.g., the exact test command), say so and mark it with
  a `# TODO: verify this command` comment so the user knows to check it.
