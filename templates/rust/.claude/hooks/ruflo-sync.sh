#!/usr/bin/env bash
# ruflo-sync.sh — bidirectional sync between knowledge store and ruflo memory
# Usage: ruflo-sync.sh [push|pull|both]
set -euo pipefail

KNOWLEDGE_DIR=".claude/knowledge"
MODE="${1:-both}"

# Graceful degradation — skip if ruflo not available
command -v ruflo >/dev/null 2>&1 || { echo "ruflo not available, skipping sync"; exit 0; }

# Verify knowledge store exists
[ -d "$KNOWLEDGE_DIR" ] || { echo "No knowledge store found at $KNOWLEDGE_DIR, skipping sync"; exit 0; }

push_to_ruflo() {
  local file key
  for file in "$KNOWLEDGE_DIR"/{active-context,decisions,architecture-snapshot,conventions}.md; do
    [ -f "$file" ] || continue
    key=$(basename "$file" .md)
    ruflo memory store "$key" "$(cat "$file")" --namespace project 2>/dev/null || true
  done
  ruflo memory store "last-sync" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" --namespace project 2>/dev/null || true
}

pull_from_ruflo() {
  local output_dir="$KNOWLEDGE_DIR/agent-outputs"
  mkdir -p "$output_dir"

  # Query for agent outputs
  local agent_output
  agent_output=$(ruflo memory query "agent-output" --namespace project 2>/dev/null) || return 0

  if [ -n "$agent_output" ]; then
    local timestamp
    timestamp=$(date -u +%Y%m%d-%H%M%S)
    echo "$agent_output" > "$output_dir/agent-output-${timestamp}.md"

    # Update active-context with agent activity note
    if [ -f "$KNOWLEDGE_DIR/active-context.md" ]; then
      local marker="## Recent Agent Activity"
      if ! grep -q "$marker" "$KNOWLEDGE_DIR/active-context.md" 2>/dev/null; then
        printf "\n%s\n" "$marker" >> "$KNOWLEDGE_DIR/active-context.md"
      fi
      printf "- [%s] Agent output captured\\n" "$(date -u +%Y-%m-%d)" >> "$KNOWLEDGE_DIR/active-context.md"
    fi
  fi
}

sync_with_overwrite_logging() {
  # For bidirectional files, log overwrites to stale-log
  local stale_log="$KNOWLEDGE_DIR/stale-log.md"
  for file in architecture-snapshot conventions; do
    local local_file="$KNOWLEDGE_DIR/${file}.md"
    [ -f "$local_file" ] || continue

    local remote_content
    remote_content=$(ruflo memory query "$file" --namespace project 2>/dev/null) || continue
    [ -n "$remote_content" ] || continue

    local local_content
    local_content=$(cat "$local_file")

    if [ "$local_content" != "$remote_content" ]; then
      # Log the overwrite
      {
        echo ""
        echo "---"
        echo "### $(date -u +%Y-%m-%dT%H:%M:%SZ) [sync-overwrite] ${file}.md overwritten by ruflo"
        echo "**Source:** ruflo memory → local file"
        echo "**Previous local content:**"
        echo "$local_content"
        echo "---"
      } >> "$stale_log"

      echo "$remote_content" > "$local_file"
    fi
  done
}

case "$MODE" in
  push)
    push_to_ruflo
    ;;
  pull)
    pull_from_ruflo
    ;;
  both)
    push_to_ruflo
    sync_with_overwrite_logging
    pull_from_ruflo
    ;;
  *)
    echo "Usage: ruflo-sync.sh [push|pull|both]"
    exit 1
    ;;
esac
