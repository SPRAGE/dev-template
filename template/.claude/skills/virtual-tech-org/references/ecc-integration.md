# ECC Integration — Everything Claude Code

The virtual tech org uses [everything-claude-code](https://github.com/affaan-m/everything-claude-code) (ECC) as the engineering team's shared "playbook" — the rules, standards, workflows, and agent behaviors that every team member follows. Ruflo handles orchestration (who works when, in what order). ECC handles quality (how each agent does their job well).

## What ECC Provides to the Org

### Agent Behaviors (how each role does their job)
ECC defines battle-tested agent definitions that our org roles use as their operating manual:

| Org Role | ECC Agent Source | What It Provides |
|----------|-----------------|------------------|
| Sam (VP Eng) | `planner.md` | Structured planning: requirements restatement, risk identification, phased breakdown, dependency analysis |
| Priya (Architect) | `architect.md` | ADR format, system design templates, scalability analysis, tech decision framework |
| Marcus (Core Dev) | `tdd-guide.md` + coding standards | TDD discipline: RED→GREEN→REFACTOR, test-first development |
| Lina (UI/Client Dev) | `tdd-guide.md` + UI patterns | TDD discipline, component design patterns for the project's UI layer |
| Robin (QA) | `e2e-runner.md` + `tdd-guide.md` | End-to-end testing, test coverage analysis, regression strategies |
| Kai (DevOps) | `build-error-resolver.md` | Build error diagnosis, CI/CD pipeline patterns |
| Ash (Security) | `security-reviewer.md` | OWASP Top 10 audit, vulnerability analysis, secret detection |
| Casey (Code Review) | `code-reviewer.md` | Quality/security/maintainability review with severity ratings |
| Morgan (Docs) | `doc-updater.md` | Documentation sync, ensuring docs stay current with code |
| Drew (Research) | `docs-lookup.md` | Documentation research, library evaluation |
| Riley (Domain Expert) | N/A — user-facing persona | Domain knowledge is provided conversationally; during execution stages, domain requirements are injected into agent prompts via ruflo shared memory |

### Engineering Rules (the org's standards)
ECC's rules become the org's engineering handbook. Every agent follows these:

- **`security.md`** — No hardcoded secrets, validate all inputs, sanitize outputs
- **`coding-style.md`** — Immutability preference, file organization, naming conventions
- **`testing.md`** — TDD workflow, 80%+ coverage requirement, test naming
- **`git-workflow.md`** — Conventional commits (`feat:`, `fix:`, `refactor:`), PR process
- **`performance.md`** — Model selection, context management, resource efficiency
- **`patterns.md`** — API response envelope format, error handling patterns, hook patterns

### Development Workflow (Plan → TDD → Review → Ship)
ECC enforces a disciplined development cycle that the CTO builds into every execution stage:

1. **Plan** (`/plan`) — Planner agent creates implementation blueprint before any code is written
2. **TDD** (`/tdd`) — Write failing tests first, implement, refactor
3. **Review** (`/code-review`) — Code reviewer checks quality, security, maintainability
4. **Security** (`/security-scan`) — Security reviewer audits for vulnerabilities
5. **E2E** (`/e2e`) — E2E runner validates critical user/consumer flows
6. **Ship** — Only after all checks pass

### Hooks (automated quality enforcement)
ECC's hooks run automatically during development:

- **Pre-tool hooks**: Validate inputs before file edits, warn about risky operations
- **Post-tool hooks**: Type-check after edits, lint on save, detect debug statements
- **Session hooks**: Track costs, persist session state, generate summaries
- **Build hooks**: Auto-resolve common build errors

### Instinct System (team learning)
ECC's instinct-based learning system means the team gets smarter over time:
- Patterns that work get higher confidence scores
- Failed approaches are recorded to avoid repetition
- Team instincts can be exported/imported across projects

## Setup

### Install ECC as a Claude Code plugin

```bash
# Via plugin system (recommended)
/plugin marketplace add affaan-m/everything-claude-code
/plugin install everything-claude-code@everything-claude-code

# Or manual install
git clone https://github.com/affaan-m/everything-claude-code.git
cp -r everything-claude-code/agents/ ~/.claude/agents/
cp -r everything-claude-code/rules/ ~/.claude/rules/
cp -r everything-claude-code/commands/ ~/.claude/commands/
cp -r everything-claude-code/skills/ ~/.claude/skills/
```

### Verify installation

```bash
# Check plugin is active
/plugin list everything-claude-code@everything-claude-code

# Verify agents are available
ls ~/.claude/agents/
# Should show: planner.md, architect.md, tdd-guide.md, code-reviewer.md,
# security-reviewer.md, build-error-resolver.md, e2e-runner.md,
# refactor-cleaner.md, doc-updater.md
```

### Context window management
ECC warns about context window bloat. The CTO should:
- Keep under 10 MCPs enabled per project
- Under 80 tools active
- Use `disabledMcpServers` for unused integrations
- Disable unused hooks via `ECC_HOOK_PROFILE=minimal` for lightweight stages

## How the CTO Uses ECC Internally

When orchestrating the team, the CTO injects ECC patterns into ruflo agent prompts:

### For planning stages (Sam uses ECC planner pattern)
```
"You are a planner agent following ECC's planning protocol:
1. Restate requirements — clarify what needs to be built
2. Identify risks — surface potential issues and blockers
3. Create phased step plan — break into implementation phases
4. List dependencies between phases
5. Estimate complexity per phase (Low/Medium/High)
Output format: Implementation Plan markdown with Overview, Requirements,
Architecture Changes, and Implementation Steps sections."
```

### For development stages (Marcus/Lina use ECC TDD pattern)
```
"Follow ECC's TDD workflow strictly:
1. Define interfaces first
2. Write failing tests (RED)
3. Implement minimal code to pass (GREEN)
4. Refactor for quality (IMPROVE)
5. Verify 80%+ coverage
Use conventional commits: feat:, fix:, refactor:, test:, docs:"
```

### For review stages (Casey uses ECC code-reviewer pattern)
```
"You are a senior code reviewer following ECC's review protocol:
- Check: quality, security, maintainability, test coverage
- Rate findings: CRITICAL / HIGH / MEDIUM / LOW
- For each finding: describe issue, show location, suggest fix
- Check for: hardcoded secrets, missing input validation,
  injection vulnerabilities, missing error handling
- Verify conventional commit format
- Ensure 80%+ test coverage"
```

### For security stages (Ash uses ECC security-reviewer pattern)
```
"You are a security specialist following ECC's security protocol:
- OWASP Top 10 audit (adapted to project archetype)
- Dependency vulnerability scan
- Secret detection (no hardcoded API keys, tokens, passwords)
- Input validation review (all user inputs sanitized)
- Authentication/authorization audit (if applicable)
- Supply chain security review (for libraries/published packages)
- Rate findings by severity with remediation steps"
```

## ECC Commands Available to the Org

The CTO can invoke these internally during any stage:

| Command | Agent | Purpose |
|---------|-------|---------|
| `/plan` | planner | Create implementation plan before coding |
| `/tdd` | tdd-guide | Enforce test-driven development |
| `/code-review` | code-reviewer | Quality and security review |
| `/security-scan` | security-reviewer | Vulnerability analysis |
| `/e2e` | e2e-runner | End-to-end test generation |
| `/build-fix` | build-error-resolver | Diagnose and fix build failures |
| `/refactor-clean` | refactor-cleaner | Dead code removal and cleanup |
| `/test-coverage` | — | Coverage analysis report |
| `/update-docs` | doc-updater | Sync documentation with code changes |

## When ECC Is Not Available

If ECC is not installed:
1. The CTO notes it: "We don't have ECC installed — I'll apply the same engineering standards manually."
2. The skill still works — ECC patterns are baked into the agent prompts in `ruflo-config.md`
3. Quality is slightly lower (no automated hooks, no instinct learning) but the core workflow is the same
4. The CTO can recommend installing it: "If you install ECC, the team gets automated quality enforcement — linting, security scanning, test-first workflows. Worth it for anything beyond a prototype."
