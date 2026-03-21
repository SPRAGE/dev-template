#!/usr/bin/env bash
# context-watchdog.sh — monitors session JSONL growth and nudges persistence
# Event: PostToolUse (matcher: .*)
set -euo pipefail

KNOWLEDGE_DIR=".claude/knowledge"
LAST_RUN_FILE="$KNOWLEDGE_DIR/.watchdog-last-run"
LAST_SIZE_FILE="$KNOWLEDGE_DIR/.watchdog-last-size"
THRESHOLD="${CLAUDE_WATCHDOG_THRESHOLD:-102400}"  # 100KB default

# Missing-file safe
[ -d "$KNOWLEDGE_DIR" ] || exit 0

# Gate: skip if last run was < 3 minutes ago
if [ -f "$LAST_RUN_FILE" ]; then
  LAST_RUN_TS=$(stat -c %Y "$LAST_RUN_FILE" 2>/dev/null || stat -f %m "$LAST_RUN_FILE" 2>/dev/null || echo "0")
  NOW_TS=$(date +%s)
  ELAPSED=$((NOW_TS - LAST_RUN_TS))
  [ "$ELAPSED" -lt 180 ] && exit 0
fi

# Find current session JSONL
PROJECT_DIR=$(echo "$PWD" | sed 's|/|-|g; s|^-||')
CLAUDE_PROJECT_DIR="$HOME/.claude/projects/${PROJECT_DIR}"

# Fragile dependency: if path doesn't exist, skip silently
[ -d "$CLAUDE_PROJECT_DIR" ] || exit 0

# Find the most recently modified JSONL (current session)
CURRENT_JSONL=""
LATEST_TS=0
for jsonl in "$CLAUDE_PROJECT_DIR"/*.jsonl; do
  [ -f "$jsonl" ] || continue
  JTS=$(stat -c %Y "$jsonl" 2>/dev/null || stat -f %m "$jsonl" 2>/dev/null || echo "0")
  if [ "$JTS" -gt "$LATEST_TS" ]; then
    LATEST_TS=$JTS
    CURRENT_JSONL=$jsonl
  fi
done

[ -n "$CURRENT_JSONL" ] || exit 0

# Get current size via stat (never read the file)
CURRENT_SIZE=$(stat -c %s "$CURRENT_JSONL" 2>/dev/null || stat -f %z "$CURRENT_JSONL" 2>/dev/null || echo "0")

# Compare to last known size
LAST_SIZE=0
if [ -f "$LAST_SIZE_FILE" ]; then
  LAST_SIZE=$(cat "$LAST_SIZE_FILE" 2>/dev/null || echo "0")
fi

DELTA=$((CURRENT_SIZE - LAST_SIZE))

# Update state
echo "$CURRENT_SIZE" > "$LAST_SIZE_FILE"
touch "$LAST_RUN_FILE"

# Nudge if growth exceeds threshold
if [ "$DELTA" -gt "$THRESHOLD" ]; then
  echo "$CURRENT_SIZE" > "$LAST_SIZE_FILE"
  touch "$KNOWLEDGE_DIR/.needs-persist"
  DELTA_KB=$((DELTA / 1024))
  echo "Context has grown ${DELTA_KB}KB since last check. Consider persisting key decisions and active work to the knowledge store (.claude/knowledge/active-context.md)."
fi
