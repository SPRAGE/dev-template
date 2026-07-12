# MCP Selection Guide

MCP servers add external tools and their schemas to an agent runtime. Add one only when repository evidence and a recurring workflow justify its context, latency, permissions, and maintenance cost.

## Evidence To Capability

| Repository or workflow evidence | Candidate capability |
|---|---|
| Fast-moving third-party SDKs | Authoritative documentation search |
| Browser UI and end-to-end tests | Browser inspection and automation |
| Database schema or migration work | Read-scoped database access |
| Hosted issues, pull requests, or CI | Source-host integration |
| Production errors or traces | Observability integration |
| Cloud or deployment manifests | Provider-specific infrastructure tools |
| Design files used as implementation input | Design-system inspection |

Prefer existing installed tools over adding overlapping servers. Verify the server's current publisher, transport, authentication model, and runtime compatibility before recommending it; do not preserve package names or install commands from memory.

## Scope And Safety

- Bind documentation tools to research roles and browser tools to UI/test roles.
- Default data and infrastructure tools to read-only. Require explicit authorization for remote writes, deployments, or destructive operations.
- Keep credentials in environment variables or runtime-native secret storage, never checked-in guidance.
- Prefer project scope for team-required capabilities and local scope for personal tools.
- Do not enable a tool globally merely because the repository contains a related dependency.
- Remove servers that duplicate built-in capabilities or are no longer used.

## Recommendation Contract

For each proposed server, report:

1. evidence and concrete workflow;
2. expected value versus context/latency cost;
3. roles allowed to use it and read/write boundary;
4. authentication and secret handling;
5. runtime-specific setup still requiring current documentation;
6. a smoke test and removal path.

## Runtime-Specific Bindings

These are implementation locations, not shared policy:

| Runtime | Typical project binding |
|---|---|
| Codex | `.codex/config.toml` or the runtime's project configuration |
| Claude Code | `.mcp.json` and supported `.claude/` settings |

Generate or edit a binding only after checking the installed runtime's current schema. Preserve local overrides and do not put provider-native syntax in `.ai/` policy files.
