# Default Plugins, MCP Servers, and Statusline

**Date:** 2026-03-21
**Status:** Approved
**Approach:** Template-Only (Approach A)

## Problem Statement

New projects scaffolded from dev-template get no plugins, only a ruflo MCP server, and no statusline. Users must manually configure superpowers, context7, sequential thinking, and other useful defaults every time.

## What Gets Added

### 1. Plugins

Add `enabledPlugins` to `template/.claude/settings.json`:

```json
"enabledPlugins": {
  "superpowers@claude-plugins-official": true,
  "code-simplifier@claude-plugins-official": true
}
```

Both from the official Claude plugins marketplace. No custom marketplace config needed.

- **superpowers** — structured workflows for brainstorming, planning, TDD, debugging, code review, and more
- **code-simplifier** — auto-reviews changed code for reuse, quality, and efficiency

### 2. MCP Servers

Add to `template/.mcp.json` alongside the existing ruflo server:

```json
{
  "mcpServers": {
    "ruflo": {
      "type": "stdio",
      "command": "ruflo",
      "args": ["mcp", "start"]
    },
    "context7": {
      "type": "stdio",
      "command": "npx",
      "args": ["-y", "@upstash/context7-mcp@latest"]
    },
    "sequential-thinking": {
      "type": "stdio",
      "command": "npx",
      "args": ["-y", "@anthropic/sequential-thinking-mcp@latest"]
    }
  }
}
```

- **context7** — retrieves up-to-date library documentation and code examples
- **sequential-thinking** — structured step-by-step reasoning for complex problems

Both use `npx -y` which downloads on first use. If Node.js is not available, the servers silently fail to start — graceful degradation.

### 3. Statusline

Add `statusLine` config to `template/.claude/settings.json`:

```json
"statusLine": {
  "type": "command",
  "command": ".claude/hooks/statusline.sh"
}
```

New script `template/.claude/hooks/statusline.sh` renders a single-line status bar:

```
main | knowledge: 2h ago | ruflo: running | ctx: 45k/200k | $0.32
```

Segments:
- **Git branch** — `git branch --show-current`
- **Knowledge age** — relative time since last `active-context.md` update (via `stat`)
- **Ruflo status** — whether ruflo MCP process is running
- **Context/tokens** — from Claude Code environment variables passed to statusline commands
- **Session cost** — from Claude Code environment variables

Each segment is independently optional — if data is unavailable, that segment is omitted. The script must be fast (target < 100ms) since it runs frequently.

## Files Changed

| File | Change |
|------|--------|
| `template/.claude/settings.json` | Add `enabledPlugins` + `statusLine` |
| `template/.mcp.json` | Add context7 + sequential-thinking MCP servers |
| `template/.claude/hooks/statusline.sh` | New — statusline rendering script |
| `templates/rust/.claude/settings.json` | Same plugin + statusline additions |
| `templates/python/.claude/settings.json` | Same plugin + statusline additions |
| `templates/rust/.mcp.json` | Same MCP server additions |
| `templates/python/.mcp.json` | Same MCP server additions |
| `templates/rust/.claude/hooks/statusline.sh` | Copy from template |
| `templates/python/.claude/hooks/statusline.sh` | Copy from template |

## Integration

- `nix run .#onboard` already copies `settings.json` and `.mcp.json` from template — new bootstrapped projects get these defaults automatically.
- `nix run .#sync-skills` already syncs hooks — the statusline script propagates to existing projects.
- No changes needed to flake.nix or the onboard/sync-skills apps.

## Build Order

Single phase — all changes are independent and can ship together:

1. Add `enabledPlugins` to template settings.json
2. Add MCP servers to template .mcp.json
3. Create statusline.sh hook script
4. Add `statusLine` config to template settings.json
5. Sync all changes to rust/python templates
