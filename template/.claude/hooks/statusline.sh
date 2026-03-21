#!/usr/bin/env bash
# statusline.sh — renders a persistent status bar in Claude Code
# Shows: git branch | knowledge age | ruflo status | context tokens | session cost
set -euo pipefail

SEGMENTS=()

# --- Git branch ---
BRANCH=$(git branch --show-current 2>/dev/null || echo "")
if [ -n "$BRANCH" ]; then
  SEGMENTS+=("$BRANCH")
fi

# --- Knowledge store age ---
ACTIVE_CTX=".claude/knowledge/active-context.md"
if [ -f "$ACTIVE_CTX" ]; then
  # Skip if still a template
  if ! grep -q "TEMPLATE" "$ACTIVE_CTX" 2>/dev/null; then
    FILE_TS=$(stat -c %Y "$ACTIVE_CTX" 2>/dev/null || stat -f %m "$ACTIVE_CTX" 2>/dev/null || echo "0")
    NOW_TS=$(date +%s)
    DIFF=$((NOW_TS - FILE_TS))
    if [ "$DIFF" -lt 60 ]; then
      AGE="just now"
    elif [ "$DIFF" -lt 3600 ]; then
      AGE="$((DIFF / 60))m ago"
    elif [ "$DIFF" -lt 86400 ]; then
      AGE="$((DIFF / 3600))h ago"
    else
      AGE="$((DIFF / 86400))d ago"
    fi
    SEGMENTS+=("knowledge: $AGE")
  fi
fi

# --- Ruflo status ---
if pgrep -f "ruflo mcp" >/dev/null 2>&1; then
  SEGMENTS+=("ruflo: running")
fi

# --- Context tokens (best-effort) ---
if [ -n "${CLAUDE_CONTEXT_TOKENS_USED:-}" ] && [ -n "${CLAUDE_CONTEXT_WINDOW:-}" ]; then
  USED_K=$((CLAUDE_CONTEXT_TOKENS_USED / 1000))
  WINDOW_K=$((CLAUDE_CONTEXT_WINDOW / 1000))
  SEGMENTS+=("ctx: ${USED_K}k/${WINDOW_K}k")
fi

# --- Session cost (best-effort) ---
if [ -n "${CLAUDE_SESSION_COST:-}" ]; then
  SEGMENTS+=("\$${CLAUDE_SESSION_COST}")
fi

# --- Render ---
if [ ${#SEGMENTS[@]} -gt 0 ]; then
  IFS=" | "
  echo "${SEGMENTS[*]}"
fi
