# Ruflo Configuration Reference

This file contains the ruflo workflow templates and CLI commands the CTO uses to orchestrate the engineering team.

## Prerequisites

Ruflo should be available via npx. The CTO checks and initializes on first use:

```bash
# Check availability (try ruflo first, fall back to claude-flow)
RUFLO_CMD="npx ruflo@latest"
$RUFLO_CMD --version 2>/dev/null || {
  RUFLO_CMD="npx claude-flow@latest"
  $RUFLO_CMD --version 2>/dev/null || {
    echo "Installing ruflo..."
    npx ruflo@latest init --force
    RUFLO_CMD="npx ruflo@latest"
  }
}
```

## Quick Reference: Key Commands

```bash
# Initialize hive-mind
$RUFLO_CMD hive-mind init

# Spawn a swarm with an objective
$RUFLO_CMD hive-mind spawn "<objective>" --queen-type strategic --claude

# Run a workflow file
$RUFLO_CMD automation run-workflow <workflow.json> --claude --non-interactive --output-format stream-json

# Spawn specific agent types
$RUFLO_CMD swarm spawn researcher "<task>"
$RUFLO_CMD swarm spawn coder "<task>"
$RUFLO_CMD swarm spawn tester "<task>"
$RUFLO_CMD swarm spawn architect "<task>"
$RUFLO_CMD swarm spawn reviewer "<task>"
$RUFLO_CMD swarm spawn documenter "<task>"
$RUFLO_CMD swarm spawn optimizer "<task>"
$RUFLO_CMD swarm spawn analyst "<task>"

# Monitor
$RUFLO_CMD hive-mind status
$RUFLO_CMD hive-mind metrics
$RUFLO_CMD swarm status

# Memory (for shared state between agents)
$RUFLO_CMD memory store <key> "<value>" --namespace project
$RUFLO_CMD memory query "<search>" --namespace project
```

## Workflow Templates

The CTO customizes these templates per project. Replace `{{PLACEHOLDER}}` values with project-specific information from the product brief and architecture doc.

**Archetype adaptation**: For projects without a UI layer, omit the `ui` task. For projects without a server layer, omit deployment-related tasks. The templates below show the full set — the CTO strips what doesn't apply.

### Stage 1: Architecture Workflow

This is a lightweight workflow — just the architect and researcher doing design work.

```json
{
  "name": "stage-1-architecture",
  "description": "Architecture design for {{PROJECT_NAME}}",
  "tasks": [
    {
      "id": "research",
      "assignTo": "researcher",
      "description": "Research best practices, existing solutions, and technology options for: {{PRODUCT_BRIEF_SUMMARY}}. Output a structured comparison of approaches with pros/cons.",
      "claudePrompt": "You are a senior technology researcher. Analyze the requirements and produce a technology evaluation report covering: architecture patterns, frameworks, and tooling options. Focus on {{TECH_CONSTRAINTS}}. The user's preferred stack is {{USER_PREFERRED_STACK}}. Be practical — recommend what works, not what's trendy. If the user has stated preferences, evaluate those first."
    },
    {
      "id": "domain_research",
      "assignTo": "researcher",
      "description": "Research domain-specific requirements: industry standards, compliance, data formats, and integration requirements for {{DOMAIN}}.",
      "claudePrompt": "You are a domain research specialist. For the {{DOMAIN}} industry, research and document: 1) Regulatory and compliance requirements that affect architecture (e.g., HIPAA, PCI-DSS, GDPR, FERPA), 2) Industry-standard data formats and protocols, 3) Common integrations and third-party systems, 4) Domain-specific security considerations, 5) Industry best practices for software in this space. Output a structured domain requirements report."
    },
    {
      "id": "architecture",
      "assignTo": "architect",
      "depends": ["research", "domain_research"],
      "description": "Design the system architecture based on research findings and domain requirements. Produce: component diagram, data model (if applicable), interface surface, and project structure.",
      "claudePrompt": "You are a system architect. Using the research findings and domain requirements, design a clean, modular architecture for {{PROJECT_NAME}} (archetype: {{ARCHETYPE}}). Produce: 1) High-level component diagram (ASCII), 2) Data model with entities and relationships (if applicable), 3) Interface surface — endpoints, commands, or public API depending on archetype, 4) Directory structure. Ensure the architecture satisfies domain-specific requirements (compliance, data formats, integration standards). Optimize for simplicity and maintainability. Tech stack: {{TECH_STACK}}."
    }
  ]
}
```

### Stage 2: Prototype Workflow

Small team, fast execution, minimal quality gates. The CTO includes or omits the `ui` task based on archetype.

```json
{
  "name": "stage-2-prototype",
  "description": "Prototype build for {{PROJECT_NAME}} ({{ARCHETYPE}})",
  "tasks": [
    {
      "id": "scaffold",
      "assignTo": "architect",
      "description": "Set up project structure, dependencies, and boilerplate based on the architecture doc.",
      "claudePrompt": "You are setting up the project scaffold for {{PROJECT_NAME}}. Create the directory structure, install dependencies, set up the build system, and create placeholder files. Tech stack: {{TECH_STACK}}. Output working boilerplate that builds and runs (even if it does nothing yet)."
    },
    {
      "id": "core",
      "assignTo": "coder",
      "depends": ["scaffold"],
      "description": "Implement the core logic: {{CORE_FEATURES}}",
      "claudePrompt": "You are a senior developer. Implement the core logic for {{PROJECT_NAME}}. Focus on making {{PRIMARY_FEATURE}} work end-to-end. It's OK to hardcode values, skip error handling, and use simple patterns. The goal is a working prototype, not production code. Tech: {{TECH_STACK}}. Log all shortcuts as comments: // TECH_DEBT: [description]"
    },
    {
      "id": "ui",
      "assignTo": "coder",
      "depends": ["scaffold"],
      "description": "Build minimal user-facing interface for {{UI_FEATURES}}",
      "claudePrompt": "You are a developer building the user-facing layer for {{PROJECT_NAME}}. It needs to: {{UI_REQUIREMENTS}}. Keep it simple — no complex state management or polish. Make it work, worry about aesthetics later. Tech: {{UI_STACK}}."
    }
  ]
}
```

**Note**: For archetypes without a UI (API, library, data pipeline), the CTO omits the `ui` task entirely. For CLIs, the `ui` task becomes command structure and output formatting.

### Stage 3: MVP Workflow

Full team, phased execution with quality gates between phases.

```json
{
  "name": "stage-3-mvp",
  "description": "MVP build for {{PROJECT_NAME}} ({{ARCHETYPE}}) — engineering standards enforced",
  "tasks": [
    {
      "id": "plan_features",
      "assignTo": "planner",
      "description": "Create implementation plan for all MVP features.",
      "claudePrompt": "You are a planner agent. For {{PROJECT_NAME}}, create an implementation plan: 1) Restate requirements from the product brief, 2) Identify risks and blockers, 3) Break into implementation phases with dependencies, 4) Estimate complexity per phase (Low/Medium/High). Include a tech debt resolution plan for items logged during prototype. Output format: Implementation Plan markdown with Overview, Requirements, Architecture Changes, and Implementation Steps sections."
    },
    {
      "id": "refactor_structure",
      "assignTo": "architect",
      "depends": ["plan_features"],
      "description": "Refactor prototype into clean, modular structure suitable for production development.",
      "claudePrompt": "You are a system architect. Take the prototype code and refactor it into a clean, modular structure. Produce ADRs (Architecture Decision Records) for significant choices. Separate concerns, create proper module boundaries, add type definitions, and ensure the build system is solid. Resolve structural tech debt from prototype. Don't add features — just restructure."
    },
    {
      "id": "core_features",
      "assignTo": "coder",
      "depends": ["refactor_structure"],
      "description": "Implement all remaining core features: {{ALL_CORE_FEATURES}}",
      "claudePrompt": "You are a senior developer following TDD workflow. For each feature: 1) Write failing tests first (RED), 2) Implement minimal code to pass (GREEN), 3) Refactor for quality (IMPROVE). Include proper error handling, input validation (no raw user input passes unchecked), and clean interfaces. Use conventional commits: feat:, fix:, refactor:. No hardcoded secrets. Target 80%+ test coverage."
    },
    {
      "id": "ui_features",
      "assignTo": "coder",
      "depends": ["refactor_structure"],
      "description": "Build complete user-facing layer with all features: {{ALL_UI_FEATURES}}",
      "claudePrompt": "You are a senior developer building the user-facing layer for {{PROJECT_NAME}}. Build the complete interface including: {{UI_FEATURE_LIST}}. Write component/integration tests first. Implement proper state management, error states, and responsive/accessible design as applicable. Use conventional commits."
    },
    {
      "id": "tests",
      "assignTo": "tester",
      "depends": ["core_features", "ui_features"],
      "description": "Comprehensive test suite.",
      "claudePrompt": "You are a QA engineer. Write unit tests, integration tests, and end-to-end tests for {{PROJECT_NAME}}. Target 80%+ code coverage. Focus on: core business logic, interface contracts, error handling paths, edge cases, and critical user flows. Verify no regressions from prototype behavior. Use {{TEST_FRAMEWORK}}."
    },
    {
      "id": "code_review",
      "assignTo": "reviewer",
      "depends": ["core_features", "ui_features"],
      "description": "Code review.",
      "claudePrompt": "You are a senior code reviewer. Review all code in {{PROJECT_NAME}} for: code quality, security (no hardcoded secrets, input validation, injection prevention), naming consistency, error handling completeness, test coverage, and conventional commit format. Rate each finding: CRITICAL / HIGH / MEDIUM / LOW. For each: describe issue, show location, suggest fix."
    },
    {
      "id": "cicd",
      "assignTo": "coder",
      "depends": ["tests"],
      "description": "Set up CI/CD pipeline.",
      "claudePrompt": "You are a DevOps engineer. Set up a CI/CD pipeline for {{PROJECT_NAME}} that: runs the full test suite, lints code, checks coverage (fail if below 80%), builds artifacts, and provides deployment/publish instructions as appropriate for the archetype. Use {{CI_TOOL}} if specified, otherwise choose the most natural CI for the project's ecosystem."
    },
    {
      "id": "domain_validation",
      "assignTo": "analyst",
      "depends": ["core_features", "ui_features"],
      "description": "Validate implementation against domain requirements.",
      "claudePrompt": "You are a domain validation specialist for the {{DOMAIN}} industry. Review the implementation of {{PROJECT_NAME}} against domain requirements: 1) Verify domain-specific workflows are correctly implemented, 2) Check that industry terminology is used correctly in UI/API/docs, 3) Validate compliance requirements are met ({{COMPLIANCE_REQUIREMENTS}}), 4) Verify data formats match industry standards, 5) Check that integrations follow domain conventions. Report any domain mismatches with severity ratings and specific fixes."
    },
    {
      "id": "documentation",
      "assignTo": "documenter",
      "depends": ["core_features", "ui_features", "tests", "domain_validation"],
      "description": "Write complete project documentation.",
      "claudePrompt": "You are a technical writer. Write documentation for {{PROJECT_NAME}} including: README with setup/run instructions, interface documentation (API docs, CLI help, library reference — per archetype), architecture overview (with ADRs), and contributing guide. Incorporate domain-specific terminology and context from the domain validation report. Ensure docs are synced with actual code — don't document features that don't exist or miss features that do. Make it clear enough that a new developer can get up and running in 10 minutes."
    }
  ]
}
```

**Note**: For archetypes without a UI, the CTO omits the `ui_features` task and adjusts dependencies accordingly.

### Stage 4: Production Workflow

All agents, including security and performance specialists.

```json
{
  "name": "stage-4-production",
  "description": "Production hardening for {{PROJECT_NAME}} ({{ARCHETYPE}})",
  "tasks": [
    {
      "id": "domain_compliance",
      "assignTo": "analyst",
      "description": "Domain compliance and standards audit.",
      "claudePrompt": "You are a domain compliance specialist for the {{DOMAIN}} industry. Perform a thorough domain compliance audit of {{PROJECT_NAME}}: 1) Regulatory compliance check ({{COMPLIANCE_REQUIREMENTS}}), 2) Industry data format standards compliance, 3) Domain workflow correctness — verify all domain-specific processes follow industry conventions, 4) Terminology audit — ensure all user-facing text uses correct domain language, 5) Integration standards — verify third-party integrations follow industry protocols, 6) Domain-specific security requirements beyond general OWASP (e.g., PHI handling for healthcare, PCI tokenization for payments). Rate each finding: CRITICAL / HIGH / MEDIUM / LOW."
    },
    {
      "id": "security_audit",
      "assignTo": "analyst",
      "depends": ["domain_compliance"],
      "description": "Security audit (informed by domain compliance findings).",
      "claudePrompt": "You are a security engineer. Perform a thorough security audit of {{PROJECT_NAME}}, incorporating domain-specific security requirements from the compliance audit: 1) OWASP Top 10 review (as applicable to archetype), 2) Dependency vulnerability scan (check for known CVEs), 3) Secret detection (grep for hardcoded API keys, tokens, passwords, connection strings), 4) Input validation review (all user inputs must be sanitized), 5) Authentication/authorization audit (if applicable), 6) Supply chain security (for libraries: safe defaults, no credential leaks in published packages), 7) Domain-specific security ({{DOMAIN_SECURITY_REQUIREMENTS}}). Rate each finding: CRITICAL / HIGH / MEDIUM / LOW. For each: describe the vulnerability, show the exact location, explain the attack vector, and provide a specific fix."
    },
    {
      "id": "performance_profile",
      "assignTo": "analyst",
      "description": "Performance profiling and benchmarking.",
      "claudePrompt": "You are a performance engineer. Profile {{PROJECT_NAME}} for performance characteristics relevant to its archetype ({{ARCHETYPE}}): response times, memory usage, throughput, resource utilization, startup time. Identify bottlenecks and produce a report with optimization recommendations ranked by impact."
    },
    {
      "id": "security_fixes",
      "assignTo": "coder",
      "depends": ["security_audit"],
      "description": "Fix all critical and high severity security findings.",
      "claudePrompt": "You are a senior developer focused on security. Fix all critical and high severity findings from the security audit. For each fix: explain what was vulnerable, what the fix does, and how to verify it."
    },
    {
      "id": "performance_optimization",
      "assignTo": "optimizer",
      "depends": ["performance_profile"],
      "description": "Optimize identified bottlenecks.",
      "claudePrompt": "You are a performance optimization specialist. Address the top bottlenecks identified in the performance report. Focus on the optimizations most impactful for this archetype ({{ARCHETYPE}}). Benchmark before and after each change."
    },
    {
      "id": "monitoring",
      "assignTo": "coder",
      "depends": ["security_fixes", "performance_optimization"],
      "description": "Add monitoring, logging, and alerting (if applicable to archetype).",
      "claudePrompt": "You are a DevOps engineer. Add production readiness to {{PROJECT_NAME}} as appropriate for its archetype: structured logging, health checks (for services), basic metrics, and alerting configuration. For libraries: add CI badges, publish workflow, changelog generation. Keep it simple — use built-in tools where possible."
    },
    {
      "id": "final_tests",
      "assignTo": "tester",
      "depends": ["security_fixes", "performance_optimization"],
      "description": "Full regression test suite.",
      "claudePrompt": "You are a QA engineer running final regression tests. Run the complete test suite, verify all security fixes don't break functionality, and add any missing edge case tests. Produce a test report with pass/fail summary and coverage metrics."
    },
    {
      "id": "final_docs",
      "assignTo": "documenter",
      "depends": ["monitoring", "final_tests"],
      "description": "Complete production documentation.",
      "claudePrompt": "You are a technical writer. Finalize all documentation for production: deployment/distribution guide (per archetype), operational runbook (for services), and update the README with production configuration. Include a changelog of all changes since MVP."
    },
    {
      "id": "final_review",
      "assignTo": "reviewer",
      "depends": ["monitoring", "final_tests", "final_docs"],
      "description": "Final code review and sign-off.",
      "claudePrompt": "You are the lead code reviewer doing a final review of {{PROJECT_NAME}} before production release. Check: all previous review items are addressed, security fixes are solid, performance changes don't introduce regressions, documentation is complete and accurate. Produce a final sign-off report."
    }
  ]
}
```

## Generating Workflow Configs

The CTO should customize these templates by replacing the `{{PLACEHOLDER}}` values with project-specific information from the product brief and architecture doc. Save the generated config as `project/workflow-stage-N.json`.

**Archetype adaptation checklist**:
- Remove `ui` / `ui_features` tasks for projects without a UI layer
- Adjust `monitoring` task for libraries (CI badges, publish workflow instead of health checks)
- Adjust `security_audit` prompts for libraries (supply chain focus) vs services (OWASP focus)
- Adjust `performance_profile` focus per archetype (latency for APIs, throughput for pipelines, startup for CLIs)

## Running Workflows

### Quick single-objective run (good for Stage 2)
```bash
$RUFLO_CMD hive-mind spawn "Build a prototype for [PROJECT]: [OBJECTIVE]" \
  --queen-type strategic \
  --claude \
  --non-interactive
```

### Full workflow run (good for Stages 3-4)
```bash
$RUFLO_CMD automation run-workflow project/workflow-stage-N.json \
  --claude \
  --non-interactive \
  --output-format stream-json
```

### Monitoring during execution
```bash
# Check status
$RUFLO_CMD hive-mind status

# View metrics
$RUFLO_CMD hive-mind metrics

# Check memory (shared context between agents)
$RUFLO_CMD hive-mind memory
```

## Fallback: When Ruflo Is Unavailable

If ruflo cannot be installed or fails to run (network issues, environment constraints), the CTO falls back to manual orchestration:

1. The CTO describes what each team member would do
2. Claude executes the tasks sequentially, role-playing each agent
3. The output quality is the same — just slower and without true parallelism
4. The CTO is transparent: "Ruflo isn't available in this environment, so I'm coordinating the team manually. Same result, just takes a bit longer."

This ensures the skill works even without ruflo installed — it degrades gracefully from parallel swarm execution to sequential single-agent execution.

## Shared Memory Pattern

For complex projects, agents need to share context. The CTO stores key decisions and artifacts in ruflo memory:

```bash
# Store the product brief for all agents to reference
$RUFLO_CMD memory store "product-brief" "$(cat project/product-brief.md)" --namespace project

# Store architecture decisions
$RUFLO_CMD memory store "architecture" "$(cat project/architecture.md)" --namespace project

# Store tech stack for consistent usage
$RUFLO_CMD memory store "tech-stack" '{"language":"...","framework":"...","database":"..."}' --namespace project

# Store domain context (from Riley) for all agents to reference
$RUFLO_CMD memory store "domain-context" '{"domain":"...","regulations":["..."],"data_formats":["..."],"integrations":["..."],"terminology":{"domain_term":"definition"}}' --namespace project

# Agents can query this during execution
$RUFLO_CMD memory query "tech stack" --namespace project
$RUFLO_CMD memory query "domain context" --namespace project
```
