---
name: cc-setup
description: Set up or optimize shared agent context and generated runtime assets. Use for repository onboarding, agent guidance, capability routing, or automation recommendations.
---

# Agent Setup

Create a concise, evidence-backed agent environment across supported runtimes.

## Modes

- **Greenfield:** infer the initial stack and populate starter guidance from the project brief.
- **Brownfield:** inspect code, manifests, CI, and conventions before writing guidance.
- **Recommend:** audit the existing setup and return ranked automation improvements without editing.

If the mode is unclear, infer it from repository contents. Ask only when a missing answer changes a material decision.

## Inspect

Inspect the tree, working state, manifests, entry points, build/test/lint commands, architecture boundaries, CI, security constraints, existing guidance, and runtime configuration. Verify commands where practical; never invent them. Preserve user-owned files and unrelated changes.

## Build

Populate the neutral source first:

- `AI.md`: one-line purpose, stack, exact commands, architecture map, non-obvious facts;
- `.ai/project.yaml`: project identity, context routes, budgets, and compiled-spec paths;
- `.ai/policy.yaml`: authorization, delivery routing, handoff fields, preservation, and completion rules;
- `.ai/instructions.md` and `.ai/methodology.md`: generated readable views of the policy;
- `.ai/context/`: architecture, conventions, active decisions, and real rolling state only;
- `.ai/skills/`: reusable project procedures, loaded on demand;
- capability and role-agent contracts only when recurring work benefits from them.

Keep personal preferences, credentials, and permissions in local runtime settings. Do not enable MCP servers globally by default; expose each tool only to the role that needs it. Load `references/mcp-catalog.md` only when an external connector is justified and `references/subagent-templates.md` only when adding a custom role.

Compile provider artifacts with:

```bash
python .ai/generators/compile.py --root .
```

Preserve customized adapters and native settings unless the user explicitly requests replacement. Treat generated runtime files as outputs, not additional policy sources.

## Validate

Run the compiler in check mode, documented project checks, and `ai-doctor` when available. Report generated files, assumptions, verified commands, and any manual configuration.
