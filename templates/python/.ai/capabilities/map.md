# Capability Map

<!-- Generated from .ai/ by .ai/generators/compile.py. Do not edit directly. -->

| Capability | Profile | Inputs | Output |
|---|---|---|---|
| `explore` | `read_only` | objective, scope, repository_facts, required_evidence, stop_conditions | `exploration_report` |
| `research` | `read_network` | objective, source_constraints, required_evidence, stop_conditions | `research_report` |
| `plan` | `read_only` | objective, task_mode, repository_facts, constraints, preserved_invariants | `plan` |
| `implement` | `workspace_write` | objective, task_mode, current_layer, plan_step, repository_facts, file_scope, success_criteria, preserved_invariants, required_evidence, stop_conditions | `change_report` |
| `test` | `verify` | objective, current_layer, change_scope, success_criteria, required_evidence, stop_conditions | `test_report` |
| `review.code` | `read_only` | objective, current_layer, diff, success_criteria, preserved_invariants, required_evidence | `review_report` |
| `review.security` | `read_only` | objective, current_layer, diff, threat_scope, success_criteria, required_evidence | `review_report` |
| `document` | `workspace_write` | objective, current_layer, change_scope, audience, verified_behavior, file_scope | `change_report` |
| `integrate` | `workspace_write` | objective, current_layer, plan, worker_reports, current_diff, success_criteria, preserved_invariants, required_evidence, stop_conditions | `integration_report` |

If a mapped runtime capability is unavailable, execute inline and state the limitation.
