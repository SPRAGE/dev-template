# MCP Server Catalog & Claude Code Config Patterns

This reference maps project characteristics (from a brainstorm brief) to recommended MCP servers,
CLAUDE.md sections, and `.claude/rules/` files.

## MCP Server Recommendations by Stack/Domain

### Version Control & Code Management
| Server | When to recommend | Install command |
|--------|-------------------|-----------------|
| GitHub MCP | Any project using GitHub repos | `claude mcp add github --transport http https://api.githubcopilot.com/mcp/ -H "Authorization: Bearer $GITHUB_PAT"` |

### Databases
| Server | When to recommend | Install command |
|--------|-------------------|-----------------|
| PostgreSQL MCP | Postgres in stack | `claude mcp add postgres -- npx -y @modelcontextprotocol/server-postgres` |
| Supabase MCP | Supabase in stack | `claude mcp add supabase --transport http https://mcp.supabase.com` |
| SQLite MCP | SQLite in stack | `claude mcp add sqlite -- npx -y @modelcontextprotocol/server-sqlite` |

### Documentation & Research
| Server | When to recommend | Install command |
|--------|-------------------|-----------------|
| Context7 | Any project (up-to-date library docs) | `claude mcp add context7 -- npx -y @upstash/context7-mcp@latest` |

### Error Monitoring & Observability
| Server | When to recommend | Install command |
|--------|-------------------|-----------------|
| Sentry MCP | Production apps with error tracking | `claude mcp add sentry --transport http https://mcp.sentry.dev/mcp` |

### Testing & Browser Automation
| Server | When to recommend | Install command |
|--------|-------------------|-----------------|
| Playwright MCP | Web apps needing E2E tests | `claude mcp add playwright -- npx -y @anthropic/mcp-playwright` |

### Design
| Server | When to recommend | Install command |
|--------|-------------------|-----------------|
| Figma MCP | Projects with Figma design files | `claude mcp add figma --transport http https://mcp.figma.com` |

### Filesystem & Search
| Server | When to recommend | Install command |
|--------|-------------------|-----------------|
| Filesystem MCP | Projects needing broad file access | `claude mcp add filesystem -- npx -y @modelcontextprotocol/server-filesystem /path/to/allowed/dir` |

---

## .mcp.json Format (Project-Scoped)

```json
{
  "mcpServers": {
    "server-name": {
      "type": "stdio",
      "command": "npx",
      "args": ["-y", "@scope/package-name"],
      "env": {
        "API_KEY": "${ENV_VAR_NAME}"
      }
    }
  }
}
```

For HTTP/remote servers:
```json
{
  "mcpServers": {
    "server-name": {
      "type": "http",
      "url": "https://mcp.example.com/mcp",
      "headers": {
        "Authorization": "Bearer ${API_TOKEN}"
      }
    }
  }
}
```

Environment variable expansion is supported: `${VAR}` and `${VAR:-default}`.

---

## CLAUDE.md Best Practices (from official docs + community wisdom)

- Keep under 200 lines total (ideally 30-100 lines for the root file)
- Structure: project context (1 line), code style, commands, architecture, gotchas
- Use `.claude/rules/` for domain-specific rules that only apply in certain contexts
- Be specific and actionable: "Use 2-space indentation" not "Format code properly"
- Don't duplicate what linters/formatters already enforce
- Commands should be exact strings Claude can run

### Recommended sections for CLAUDE.md:
1. **Project summary** — one-liner: what it is, who it's for
2. **Tech stack** — languages, frameworks, key libraries
3. **Commands** — build, test, lint, deploy (exact commands)
4. **Architecture** — folder structure, key directories
5. **Conventions** — naming, patterns, gotchas
6. **Important notes** — things that would be easy to get wrong

---

## .claude/rules/ Patterns

Rules files are markdown files that provide targeted instructions. They can use glob patterns
to only activate in specific file contexts.

Common rule files by project type:

### Web App
- `api-rules.md` — API handler conventions, error shapes, auth patterns
- `testing-rules.md` — test framework, mocking conventions, coverage targets
- `component-rules.md` — UI component patterns, styling approach

### Rust Project
- `rust-conventions.md` — error handling style, crate preferences, unsafe policy
- `testing-rules.md` — test organization, integration test patterns

### Python Project
- `python-style.md` — type hints policy, docstring format, import ordering
- `testing-rules.md` — pytest conventions, fixture patterns

### Data Pipeline
- `schema-rules.md` — migration conventions, naming, index policies
- `query-rules.md` — query patterns, performance guardrails

### NixOS / Nix Flake
- `nix-conventions.md` — module patterns, overlay rules, flake structure

---

## Workflow Suggestions by Project Type

### Single-developer CLI/Library
- CLAUDE.md with stack + commands
- Context7 MCP for library docs
- GitHub MCP if using GitHub

### Full-stack Web App
- CLAUDE.md with full architecture section
- `.claude/rules/` split by frontend/backend/testing
- GitHub MCP + Playwright MCP + database MCP
- Context7 for framework docs

### Data Pipeline / ETL
- CLAUDE.md with schema + data flow
- Database MCP for direct querying
- `.claude/rules/` for schema and query conventions

### Multi-service / Microservice
- CLAUDE.md per service (use directory-level CLAUDE.md files)
- GitHub MCP for cross-repo work
- `--add-dir` for multi-repo sessions

### Nix-managed System Config
- CLAUDE.md with module structure + rebuild commands
- `.claude/rules/` for nix conventions
- Context7 for nixpkgs docs
