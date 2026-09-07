---
name: agent-context
description: Maintain concise, accurate repository guidance and agent configuration for this template or a project using it.
---

# Agent Context

Use this optional maintainer workflow only for onboarding guidance, stale context, token cost, or runtime configuration. It is not active in generated projects unless explicitly enabled.

Inspect the working diff, project instructions, documented commands, manifests, generated markers, CI, and local overrides. Verify every recorded fact. Preserve user-owned guidance, secrets, overrides, and runtime state.

Give each fact one home: frequent facts and commands in the main guide; conditional architecture or decisions in routed context; recurring, evidence-backed procedures in an optional workflow; deterministic rules in scripts or tests. Delete generic advice, duplicated policy, and empty placeholders.

In this maintainer repository, regenerate project artifacts with `python tools/template.py generate` after editing authored sources. In a project created from this template, use `nix run github:SPRAGE/dev-template#ai-doctor` to check its agent configuration. Do not assume this repository's generation tooling exists in generated projects.

Report changed files, measured context cost, checks run, uncertainty, and any required paired trials. A smaller profile does not establish an outcome advantage without representative comparisons.
