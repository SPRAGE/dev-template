# Security Policy

## Reporting Vulnerabilities

If you discover a security vulnerability in this repository or its templates, please **do not open a public issue**. Instead, report it privately:

- **GitHub Security Advisories**: Use the [Report a vulnerability](../../security/advisories/new) button on the Security tab of this repository.
- **Email**: Contact the maintainers directly via the email listed on the organization profile.

Please include as much detail as possible: steps to reproduce, potential impact, and any suggested mitigations. You can expect an acknowledgement within 48 hours.

---

## AI Agent Safety Model

This repository scaffolds projects with a provider-neutral specification under `.ai/`, generated Codex and Claude subagents, shared skills, and provider-native settings. Neutral profiles and task contracts state intended access, but only each runtime's sandbox and permission system is an enforcement boundary. Guidance, generated prompts, and deterministic policy fixtures are not security boundaries.

No global MCP server, web catalog, or optional Claude plugin is enabled by default. Add external tools only when a project needs them, and scope them to the specialized role that uses them so unrelated sessions do not inherit their permissions or schemas.

### Authorization Boundary

The shared policy distinguishes intent before acting:

- **Explain, review, diagnose, or plan:** inspect and report without editing.
- **Build, change, or fix:** make in-scope local edits and run non-destructive validation without repeated confirmation.
- **Confirm first:** destructive operations, external writes or deployments, purchases, permission expansion, and material scope expansion.

Repository instructions may narrow these boundaries but must not silently broaden them. Worker write access is bounded by an assigned file scope, success criteria, preserved invariants, and stop conditions. A worker stops and reports when a dependency or required change would exceed that contract.

### Runtime Permissions

The template does not treat a blanket command allow list as an authorization policy. Add project-specific allowances only after identifying the exact command family and its external or destructive variants. In particular, do not broadly preauthorize version-control pushes, package publication, deployment commands, arbitrary package runners, or destructive cleanup.

Read-only, network-read, workspace-write, verification, and privileged profiles map separately into each provider. Privileged access always requires a human decision; it must never degrade to an unrestricted runtime merely because a capability is unavailable.

### Default Deny List

The deny list blocks several high-risk operations regardless of the allow list:

- **Secret files**: `Edit(//.env)`, `Edit(//.env.*)`, `Read(//.env)`, `Read(//.env.*)`
- **Git internals**: `Edit(//.git/**)`
- **Force push**: `Bash(git push --force:*)`
- **Privilege escalation**: `Bash(sudo:*)`
- **Network/file transfer**: `Bash(curl:*)`, `Bash(wget:*)`, `Bash(ssh:*)`, `Bash(scp:*)`
- **Nix store deletion**: `Bash(nix-store --delete:*)`

If your project should block all pushes, destructive filesystem operations, or additional network tools, add explicit provider-native deny rules as defense in depth.

### Hooks

The default hook is a display-only status line. For sensitive projects, add narrow `PreToolUse` or `PostToolUse` validation around the specific commands or paths that need enforcement. Avoid hooks that inject broad project context into every session.

---

## Recommendations for Repositories Scaffolded from This Template

### 1. Enable Branch Protection on `main`

Configure your repository's `main` branch with:
- Require pull request reviews before merging (at least 1 approver)
- Require status checks to pass before merging (CI must be green)
- Disallow force pushes
- Disallow branch deletion

### 2. Enable Commit Sign-off

Enable `web_commit_signoff_required` in your repository settings to ensure commit authorship can be verified.

### 3. Review Locked Dependencies

Commit `flake.lock` in generated projects and review lock updates before merging them. The lock records immutable revisions even when an input URL names a branch. CI actions in this repository are pinned to full commit SHAs; update their version comments and SHAs together after reviewing the upstream release.

### 4. Review Provider Permissions

Review `.claude/settings.json`, `.codex/config.toml`, generated agent profiles, and any local overrides. Remove tools and command patterns that the project does not need, and keep external-write commands behind confirmation.

### 5. Keep Secrets Out Of Ambient Agent Environments

Generated `.envrc` files enter the Nix shell but do not load `.env` or `.env.mcp`. Export only the variables needed by a specific developer-controlled command. File-read deny rules do not protect a secret that was already inherited through the process environment.

### 6. Populate Audit Hooks

Add narrow `PreToolUse` hooks around the commands or paths that carry material risk. Logging every harmless read can create noise and false confidence; audit external writes, privilege changes, secret access, and destructive operations first.
