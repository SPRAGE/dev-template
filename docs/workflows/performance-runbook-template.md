# Performance runbook template

This is a project-runbook template, not a default skill. Fill every field from repository or user evidence; do not invent workloads, budgets, hosts, endpoints, or commands.

```md
## Objective and boundary
- User-visible concern:
- In-scope component/data path:
- Explicitly excluded systems:
- Source and owner:

## Reproducible workload
- Dataset/fixture and provenance:
- Load shape, duration, concurrency, and warm-up:
- Baseline revision and command:
- Candidate revision and command:

## Measurement
- Metrics, units, collection command, and environment:
- Acceptance budget and source:
- Correctness checks:

## Decision and rollback
- Result and variance:
- Change decision:
- Rollback trigger and command:
```
