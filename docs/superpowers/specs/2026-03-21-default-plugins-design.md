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

Both use `npx -y` which downloads on first use.

**Node.js requirement:** `npx` must be on PATH for these servers to start. The template devShells currently do not include Node.js. Fix: add `pkgs.nodejs` to each template's `flake.nix` devShell packages list. This is a one-line addition per template. MCP servers are launched by Claude Code's runtime directly (not via the Bash tool), so the `Bash(node*)` deny rule in permissions does not affect them.

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
- **Knowledge age** — relative time since last `active-context.md` update (via `stat`, format as "2h ago", "3d ago")
- **Ruflo status** — check if ruflo MCP process is running (`pgrep -f "ruflo mcp" >/dev/null`)
- **Context/tokens** — from `$CLAUDE_CONTEXT_TOKENS_USED` / `$CLAUDE_CONTEXT_WINDOW` env vars if available. Note: these env var names must be verified during implementation — Claude Code may use different names or may not expose token counts to statusline commands. If unavailable, omit this segment.
- **Session cost** — from `$CLAUDE_SESSION_COST` env var if available. Same caveat as tokens — verify during implementation.

Each segment is independently optional — if data or env vars are unavailable, that segment is omitted. The script must be fast (target < 100ms) since it runs frequently.

**Guaranteed segments:** Git branch, knowledge age, ruflo status (these use only git and filesystem — always available).
**Best-effort segments:** Context tokens, session cost (depend on Claude Code exposing env vars to statusline commands — may not be available).

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
| `template/flake.nix` | Add `pkgs.nodejs` to devShell packages |
| `templates/rust/flake.nix` | Add `pkgs.nodejs` to devShell packages |
| `templates/python/flake.nix` | Add `pkgs.nodejs` to devShell packages |

## Integration

- `nix run .#onboard` copies `settings.json` and `.mcp.json` on first bootstrap — new projects get these defaults automatically.
- `nix run .#sync-skills` syncs hooks — the statusline.sh script propagates to existing projects.
- **Limitation:** `sync-skills` does NOT sync `settings.json` or `.mcp.json`. Existing projects that already have these files will not automatically get the new `enabledPlugins`, `statusLine`, or MCP server entries. These must be added manually to existing projects. This is by design — `settings.json` and `.mcp.json` may have user customizations that should not be overwritten.

### Template flake.nix changes

Add `pkgs.nodejs` to each template's devShell packages to ensure `npx` is available for MCP servers:

- `template/flake.nix` — add `pkgs.nodejs` after ruflo package
- `templates/rust/flake.nix` — add `pkgs.nodejs`
- `templates/python/flake.nix` — add `pkgs.nodejs`

### MCP tool permissions

Add default allow rules for context7 and sequential-thinking MCP tools so users don't get prompted on every call:

```json
"mcp__context7__resolve-library-id",
"mcp__context7__query-docs",
"mcp__sequential-thinking__sequentialthinking"
```

Add these to the `permissions.allow` array in each template's `settings.json`.

## Build Order

Single phase — all changes are independent and can ship together:

1. Add `pkgs.nodejs` to all three template flake.nix devShells
2. Add `enabledPlugins` to template settings.json
3. Add MCP tool permissions to template settings.json allow list
4. Add MCP servers to template .mcp.json
5. Create statusline.sh hook script
6. Add `statusLine` config to template settings.json
7. Sync all changes to rust/python templates (settings.json, .mcp.json, statusline.sh)
8. Validate with `nix flake check`
