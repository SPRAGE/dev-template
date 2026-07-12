---
name: skill-creator
description: Create, improve, validate, package, or benchmark agent skills and deterministic hook rules.
---

# Skill Creator

Build small, triggerable skills whose entry context contains only the procedure needed to start. Put detailed schemas, examples, and optional workflows in references or scripts.

## Choose The Artifact

- **Skill:** judgment, multi-step reasoning, tool use, or a reusable workflow.
- **Hook/rule:** deterministic event-response enforcement that should not consume model reasoning.
- **Project instruction:** a durable fact or constraint that applies to most work in one repository.

Do not create a skill when a linter, formatter, command, or short instruction already solves the problem.

## Create Or Improve

1. Collect 3-5 realistic trigger prompts and 2-3 near misses.
2. Define the outcome, inputs, constraints, tools/capabilities, failure behavior, and proof.
3. Use a concise frontmatter description that says what the skill does and when it should trigger.
4. Write `SKILL.md` as an imperative workflow. Keep the happy path in the entry file; move optional depth to `references/`.
5. Add scripts only for deterministic, repeated work. Scripts must expose useful usage errors and avoid hidden environment assumptions.
6. Add `manifest.yaml` with capability requirements, references, and token budgets.
7. Validate trigger precision, procedure quality, and packaging before declaring the skill complete.

Minimum structure:

```text
skill-name/
  SKILL.md
  manifest.yaml
  references/   # optional, loaded on demand
  scripts/      # optional, deterministic helpers
  assets/       # optional output resources
```

See `references/schemas.md` for evaluation and manifest formats.

## Validate And Package

From the `skill-creator` directory or with the project root on `PYTHONPATH`:

```bash
python -m scripts.quick_validate <skill-directory>
python -m scripts.package_skill <skill-directory> <output-directory>
```

The bundled live trigger evaluator is a Claude Code runtime helper. Use it only when that CLI and credentials are available:

```bash
python -m scripts.run_eval --help
python -m scripts.run_loop --help
```

Deterministic validation and packaging work for every runtime. For Codex, use a separate live harness or manual trigger set until the bundled evaluator gains a Codex event adapter; do not treat a Claude-only score as provider parity.

If a helper cannot display `--help` without optional dependencies or external state, fix that before relying on it in a workflow.

## Quality Gate

- The description triggers on intended prompts and stays quiet on near misses.
- The entry file is within its manifest budget and has no copied reference material.
- Provider-specific mechanics are isolated to a clearly marked runtime section or adapter.
- Every referenced path and command exists.
- Examples match the current schema.
- The archive is deterministic and contains exactly the source files intended for distribution.

Report the skill path, trigger cases, validation commands/results, archive path when requested, and remaining limitations.
