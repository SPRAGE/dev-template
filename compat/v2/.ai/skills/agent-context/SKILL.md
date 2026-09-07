---
name: agent-context
description: Maintain repository agent guidance for onboarding, stale context, token bloat, or runtime configuration. Use only for agent setup and maintenance.
---

# Agent Context

Infer the mode: initialize missing guidance, audit without edits, refresh requested guidance, or recommend configuration changes. Load `references/guidance-quality.md` for audit/refresh; load `references/connectors.md` only when considering an external tool.

Inspect the working diff, manifests, entry points, CI, documented commands, generated markers, and local overrides. Verify facts before recording them; preserve user-owned guidance and runtime state.

Give each fact one home:

- `AI.md`: frequent project facts, exact commands, and non-obvious constraints.
- Conditional context: architecture, decisions, or conventions needed by particular tasks.
- Shared policy: cross-task boundaries; runtime bindings: provider syntax.
- Skills: recurring procedures with demonstrated value; scripts/tests: deterministic enforcement.

Delete generic advice, repeated policy, and empty placeholders. Add no speculative skills or connectors. For this template, edit sources and regenerate with `python .ai/generators/compile.py --root .`; rerun with `--check` and run `nix run github:SPRAGE/dev-template#ai-doctor`. Elsewhere, use verified repository checks.

Report file evidence, changes or recommendations, measured context cost, verification, and remaining uncertainty. Static byte/word estimates measure prompt size; improved outcomes require representative task comparisons.
