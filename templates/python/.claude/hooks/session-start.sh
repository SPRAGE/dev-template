#!/usr/bin/env bash
# session-start.sh — loads knowledge store context at session start
# Event: SessionStart
set -euo pipefail

KNOWLEDGE_DIR=".claude/knowledge"

# Missing-file safe: if knowledge store doesn't exist, exit quietly
[ -d "$KNOWLEDGE_DIR" ] || exit 0

# --- Load active context ---
if [ -f "$KNOWLEDGE_DIR/active-context.md" ]; then
  # Skip if it's just the empty template
  if ! grep -q "TEMPLATE" "$KNOWLEDGE_DIR/active-context.md" 2>/dev/null; then
    echo "=== Active Context (from knowledge store) ==="
    cat "$KNOWLEDGE_DIR/active-context.md"
    echo ""
  fi
fi

# --- Surface active decisions ---
# Note: true date-range filtering in bash is complex; instead we surface
# all decisions marked "active". This is a practical simplification.
if [ -f "$KNOWLEDGE_DIR/decisions.md" ]; then
  if grep -q "^## " "$KNOWLEDGE_DIR/decisions.md" 2>/dev/null; then
    ACTIVE_DECISIONS=$(grep -B1 -A3 "active" "$KNOWLEDGE_DIR/decisions.md" 2>/dev/null | grep -v "^--$" || true)
    if [ -n "$ACTIVE_DECISIONS" ]; then
      echo "=== Active Decisions ==="
      echo "$ACTIVE_DECISIONS"
      echo ""
    fi
  fi
fi

# --- Surface recent agent outputs (last 3 days) ---
AGENT_OUTPUTS_DIR="$KNOWLEDGE_DIR/agent-outputs"
if [ -d "$AGENT_OUTPUTS_DIR" ]; then
  THREE_DAYS_AGO_TS=$(date -d "3 days ago" +%s 2>/dev/null || date -v-3d +%s 2>/dev/null || echo "0")
  RECENT_OUTPUTS=""
  for output_file in "$AGENT_OUTPUTS_DIR"/*.md; do
    [ -f "$output_file" ] || continue
    FILE_TS=$(stat -c %Y "$output_file" 2>/dev/null || stat -f %m "$output_file" 2>/dev/null || echo "0")
    if [ "$FILE_TS" -ge "$THREE_DAYS_AGO_TS" ] 2>/dev/null; then
      RECENT_OUTPUTS="${RECENT_OUTPUTS}\n- $(basename "$output_file")"
    fi
  done
  if [ -n "$RECENT_OUTPUTS" ]; then
    echo "=== Recent Agent Outputs ==="
    printf "%b\\n" "$RECENT_OUTPUTS"
    echo ""
  fi
fi

# --- Staleness checks ---
NUDGES=""

# Architecture snapshot age
if [ -f "$KNOWLEDGE_DIR/architecture-snapshot.md" ]; then
  SNAP_TS=$(stat -c %Y "$KNOWLEDGE_DIR/architecture-snapshot.md" 2>/dev/null || stat -f %m "$KNOWLEDGE_DIR/architecture-snapshot.md" 2>/dev/null || echo "0")
  FOURTEEN_DAYS_AGO_TS=$(date -d "14 days ago" +%s 2>/dev/null || date -v-14d +%s 2>/dev/null || echo "0")
  if [ "$SNAP_TS" -lt "$FOURTEEN_DAYS_AGO_TS" ] 2>/dev/null; then
    NUDGES="${NUDGES}\n- Architecture snapshot is stale (>14 days). Consider running /cc-refresh."
  fi
fi

# Auto-memory age check (30 days)
PROJECT_DIR=$(echo "$PWD" | sed 's|/|-|g; s|^-||')
CLAUDE_PROJECT_DIR="$HOME/.claude/projects/${PROJECT_DIR}"
MEMORY_DIR="$CLAUDE_PROJECT_DIR/memory"
if [ -d "$MEMORY_DIR" ]; then
  THIRTY_DAYS_AGO_TS=$(date -d "30 days ago" +%s 2>/dev/null || date -v-30d +%s 2>/dev/null || echo "0")
  STALE_MEMORIES=0
  for mem_file in "$MEMORY_DIR"/*.md; do
    [ -f "$mem_file" ] || continue
    MEM_TS=$(stat -c %Y "$mem_file" 2>/dev/null || stat -f %m "$mem_file" 2>/dev/null || echo "0")
    if [ "$MEM_TS" -lt "$THIRTY_DAYS_AGO_TS" ] 2>/dev/null; then
      STALE_MEMORIES=$((STALE_MEMORIES + 1))
    fi
  done
  if [ "$STALE_MEMORIES" -gt 0 ]; then
    NUDGES="${NUDGES}\n- ${STALE_MEMORIES} auto-memory file(s) older than 30 days. Consider running /cc-refresh."
  fi
fi

# Session JSONL total size
if [ -d "$CLAUDE_PROJECT_DIR" ]; then
  TOTAL_SIZE=0
  for jsonl in "$CLAUDE_PROJECT_DIR"/*.jsonl; do
    [ -f "$jsonl" ] || continue
    FSIZE=$(stat -c %s "$jsonl" 2>/dev/null || stat -f %z "$jsonl" 2>/dev/null || echo "0")
    TOTAL_SIZE=$((TOTAL_SIZE + FSIZE))
  done
  if [ "$TOTAL_SIZE" -gt 5242880 ]; then  # 5MB
    SIZE_MB=$((TOTAL_SIZE / 1048576))
    NUDGES="${NUDGES}\n- Session history is ${SIZE_MB}MB. Consider running /cc-refresh to archive old sessions."
  fi
fi

if [ -n "$NUDGES" ]; then
  echo "=== Maintenance Nudges ==="
  printf "%b\\n" "$NUDGES"
  echo ""
fi

# --- Ruflo pull (if available) ---
if [ -x ".claude/hooks/ruflo-sync.sh" ]; then
  .claude/hooks/ruflo-sync.sh pull 2>/dev/null || true
fi
