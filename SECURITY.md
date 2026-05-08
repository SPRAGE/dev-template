# Security Policy

## Reporting Vulnerabilities

If you discover a security vulnerability in this repository or its templates, please **do not open a public issue**. Instead, report it privately:

- **GitHub Security Advisories**: Use the [Report a vulnerability](../../security/advisories/new) button on the Security tab of this repository.
- **Email**: Contact the maintainers directly via the email listed on the organization profile.

Please include as much detail as possible: steps to reproduce, potential impact, and any suggested mitigations. You can expect an acknowledgement within 48 hours.

---

## AI Agent Safety Model

This repository scaffolds projects that include provider-neutral `AI.md` and `.ai/` context, shared `.ai/skills/`, official Codex repo skills under `.agents/skills/`, [Claude Code](https://github.com/sadjow/claude-code-nix), Codex-compatible `AGENTS.md` and `CODEX.md` guidance, Codex project config/custom agents, Claude Code skill links, hooks, and a Context7 MCP server. The `.claude/settings.json` file in each template defines a starter **allow/deny permission model** to constrain what Claude Code may do autonomously, while `.codex/config.toml` defines trusted project-scoped Codex defaults. `AI.md`, `.ai/`, `.ai/skills/`, `.agents/skills/`, `AGENTS.md`, `CODEX.md`, and `CLAUDE.md` are shared guidance, not permission boundaries.

### Default Allow List

The templates currently allow broad project-development commands so `/cc-setup`, `/cc-refresh`, and stack-specific workflows can run without excessive prompts:

| Category | Allowed by default |
|----------|--------------------|
| Version control | `git:*` |
| Nix | `nix:*` |
| MCP/runtime helpers | `npx:*` |
| Rust workflows | `cargo:*` |
| Python workflows | `uv:*` |
| Context7 MCP | `mcp__context7__resolve-library-id`, `mcp__context7__query-docs` |

Review and tighten this list for production or sensitive repositories. For example, replace broad `git:*`, `cargo:*`, or `uv:*` permissions with the exact commands your project needs.

### Default Deny List

The deny list blocks several high-risk operations regardless of the allow list:

- **Secret files**: `Edit(//.env)`, `Edit(//.env.*)`, `Read(//.env)`, `Read(//.env.*)`
- **Git internals**: `Edit(//.git/**)`
- **Force push**: `Bash(git push --force:*)`
- **Privilege escalation**: `Bash(sudo:*)`
- **Network/file transfer**: `Bash(curl:*)`, `Bash(wget:*)`, `Bash(ssh:*)`, `Bash(scp:*)`
- **Nix store deletion**: `Bash(nix-store --delete:*)`

If your project should block all pushes, destructive filesystem operations, or additional network tools, add explicit deny rules in `.claude/settings.json`.

### Hooks

The default hooks include `SessionStart` for surfacing active decisions and a `statusLine` command for persistent context. For production agents, consider adding `PreToolUse` or `PostToolUse` hooks to log, audit, or validate sensitive tool calls.

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

### 3. Pin Flake Inputs for Production

The template `flake.nix` files include comments showing how to pin `claude-code-nix` to a specific revision:

```nix
claude-code = {
  # SECURITY: Pin to a specific rev for production use
  # url = "github:sadjow/claude-code-nix/<rev>";
  url = "github:sadjow/claude-code-nix";
  inputs.nixpkgs.follows = "nixpkgs";
};
```

For production environments, replace the `url` with a pinned revision to prevent supply chain attacks from upstream changes.

### 4. Review and Tighten the Allow List

The default allow list is intentionally broad enough for setup and common development workflows. Review `.claude/settings.json` and `.codex/config.toml` in your scaffolded project and remove any entries not needed for your specific workflow.

### 5. Review `.envrc` Secret Loading

Generated templates load `.env.mcp` and `.env` through direnv when those files exist. This is convenient for local development, but Claude Code launched from that shell may inherit those variables. Remove or customize the dotenv lines in `.envrc` for sensitive projects.

### 6. Populate Audit Hooks

Add `PreToolUse` hooks to log or validate every tool call before the agent executes it. This creates an audit trail and can serve as a last line of defense against unexpected operations.
