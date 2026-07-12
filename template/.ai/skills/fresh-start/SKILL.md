---
name: fresh-start
description: Reset managed agent configuration to current dev-template defaults while preserving local runtime state. Use for “fresh start,” “clean slate,” or explicit requests to replace existing Codex/Claude setup.
---

# Fresh Start

This workflow is destructive. It replaces the project flake and managed agent configuration, removes the lock file, and restores current defaults.

## Preserve

- Claude auto-memory outside the repository;
- `.ai/{local,tmp,sessions,logs}/`;
- `.agents/{local,tmp,sessions,logs}/`;
- `.claude/settings.local.json`;
- `.codex/{local,tmp,sessions,logs}/`;
- user work outside the explicitly listed managed paths.

## Replace

`flake.nix`, `flake.lock`, managed `.ai/`, `.agents/`, `.claude/`, and `.codex/` content, `AI.md`, `AGENTS.md`, `CODEX.md`, `CLAUDE.md`, `.claude.local.md`, and `.mcp.json`.

## Procedure

1. Inspect and show the exact paths present.
2. Warn that language-specific flake customization and agent guidance will be replaced.
3. Obtain explicit confirmation immediately before deletion. A general cleanup request is not sufficient confirmation for this reset.
4. Prefer the tested app:

   ```bash
   nix run --refresh github:SPRAGE/dev-template#fresh-start
   ```

5. If the app is unavailable, stop and give the exact command to run after Nix/network access is restored. Do not reconstruct hundreds of lines of defaults from memory.
6. Run `ai-doctor`, confirm preserved local state, and report every restored or failed artifact.

Never run this workflow to fix one stale file; use `cc-refresh` for scoped maintenance.
