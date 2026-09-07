# Migration and recovery runbook template

This is a project-runbook template, not a default skill. Fill it from approved evidence; do not invent service endpoints, data stores, credentials, or recovery commands.

```md
## Boundary
- Data/schema/version transition:
- Owners and approval required:
- Source-of-truth and backup evidence:
- Explicit exclusions:

## Gates
- Preconditions and exact check commands:
- Compatibility window and client versions:
- Dry-run or staging evidence:
- Stop condition:

## Execution
- Ordered approved commands:
- Expected observable result for each command:
- Audit record location:

## Recovery
- Rollback or restore point:
- Exact recovery command and authorization boundary:
- Restore verification command and expected result:
```
