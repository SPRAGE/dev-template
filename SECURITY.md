# Security Policy

## Reporting Vulnerabilities

If you discover a security vulnerability in this repository or its templates, please **do not open a public issue**. Instead, report it privately:

- **GitHub Security Advisories**: Use the [Report a vulnerability](../../security/advisories/new) button on the Security tab of this repository.
- **Email**: Contact the maintainers directly via the email listed on the organization profile.

Please include as much detail as possible: steps to reproduce, potential impact, and any suggested mitigations. You can expect an acknowledgement within 48 hours.

---

## AI Agent Safety Model

This repository scaffolds projects that include [Claude Code](https://github.com/sadjow/claude-code-nix) and [Ruflo](https://github.com/SPRAGE/ruflo-nix) as AI coding assistants. The `.claude/settings.json` file in each template defines an **allow/deny permission model** to constrain what the AI agent may do autonomously.

### Allow List (what the agent CAN do)

Each template restricts the agent to a minimal set of safe commands:

| Template | Allowed commands |
|----------|-----------------|
| Base     | `nix develop/build/flake`, specific `ruflo mcp` subcommands |
| Rust     | Above + `cargo build/test/check/clippy/fmt/doc` |
| Python   | Above + `uv run pytest`, `uv run ruff`, `uv sync` |

MCP tool access is scoped to read-only Ruflo plan/task tools: `mcp__ruflo__read_plan`, `mcp__ruflo__list_tasks`, `mcp__ruflo__get_task`, `mcp__ruflo__update_task`.

### Deny List (what the agent CANNOT do)

The deny list explicitly blocks high-risk operations regardless of the allow list:

- **Secret exfiltration**: `cat/head/tail/less/more/grep/sed/awk` on `.env*` files; `Read(.env*)`
- **Arbitrary code execution**: `python`, `node`, `ruby`, `perl` invocations
- **Destructive filesystem ops**: `rm -rf`, `rm -r`
- **Unauthorized git ops**: `git push`, `git push --force`
- **Network exfiltration**: `curl`, `wget`
- **Remote access**: `ssh`, `scp`
- **Privilege escalation**: `sudo`, `chmod`, `chown`
- **Nix store manipulation**: `nix-store --delete`

### Hooks (PreToolUse / PostToolUse)

The `hooks` section in `.claude/settings.json` provides placeholders for `PreToolUse` and `PostToolUse` hooks. It is strongly recommended to populate these with auditing or validation logic before deploying agents in production.

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

The template `flake.nix` files include comments showing how to pin `claude-code-nix` and `ruflo-nix` to a specific revision:

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

The default allow list is intentionally minimal. Review `.claude/settings.json` in your scaffolded project and remove any entries not needed for your specific workflow.

### 5. Populate Audit Hooks

Add `PreToolUse` hooks to log or validate every tool call before the agent executes it. This creates an audit trail and can serve as a last line of defense against unexpected operations.
