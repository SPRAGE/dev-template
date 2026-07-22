# Behavioral Evaluation

`evals/behavioral/benchmark.yaml` defines eight normal, hard, near-miss, and adversarial task classes. It is maintainer-side and outside generated templates, so benchmark prompts do not become agent guidance.

`tools/eval_harness.py` validates trial records and compares paired baseline/candidate outcomes. It never starts an agent, contacts a provider, or spends credits. Runtime-specific launch adapters and credentials remain external to this neutral core.

```bash
nix develop path:. -c python tools/eval_harness.py validate \
  --benchmark evals/behavioral/benchmark.yaml

nix develop path:. -c python tools/eval_harness.py compare \
  --benchmark evals/behavioral/benchmark.yaml \
  --trials /path/to/sanitized-trials.yaml
```

The whole experiment must freeze one repository revision, runtime, model, settings digest, and tool set; every task must use the same repetition set. Records include deterministic checks, a blinded grade with evidence, task success, regressions, safety violations, unnecessary actions, clarifications, tool calls, tokens, latency, and external cost. The harness rejects missing pairs or task classes, duplicate or unbalanced repetitions, changed frozen settings, failed checks reported as success, malformed metrics, and unblinded grades.

The summary reports candidate-minus-baseline deltas and task-level wins/losses; pair ranking prioritizes fewer safety violations, then success, regressions, and blinded grade. It deliberately has no universal pass score: maintainers must inspect effect sizes and uncertainty by task class. A report is evidence only when its trials were actually run under the recorded conditions; synthetic fixtures and static context estimates are not behavioral results.
