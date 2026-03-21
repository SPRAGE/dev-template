#!/usr/bin/env bash
# post-commit-persist.sh — appends commit info to active-context after git commits
# Event: PostToolUse (matcher: Bash)
set -euo pipefail

KNOWLEDGE_DIR=".claude/knowledge"
ACTIVE_CONTEXT="$KNOWLEDGE_DIR/active-context.md"

# Missing-file safe
[ -d "$KNOWLEDGE_DIR" ] || exit 0
[ -f "$ACTIVE_CONTEXT" ] || exit 0

# Check if the tool input was a git commit
# Hook receives tool input on stdin as JSON
INPUT=$(cat)
COMMAND=$(echo "$INPUT" | grep -o '"command"[[:space:]]*:[[:space:]]*"[^"]*"' 2>/dev/null | head -1 | sed 's/.*"command"[[:space:]]*:[[:space:]]*"//;s/"$//' || true)

# Exit if not a git commit
case "$COMMAND" in
  *"git commit"*) ;;
  *) exit 0 ;;
esac

# Extract commit info
COMMIT_MSG=$(git log -1 --pretty=%s 2>/dev/null || echo "unknown")
COMMIT_HASH=$(git log -1 --pretty=%h 2>/dev/null || echo "unknown")
FILES_CHANGED=$(git diff --name-only HEAD~1 2>/dev/null | head -10 || echo "unknown")
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# Append to Recent Changes section
MARKER="## Recent Changes"
if ! grep -q "$MARKER" "$ACTIVE_CONTEXT" 2>/dev/null; then
  printf "\n%s\n" "$MARKER" >> "$ACTIVE_CONTEXT"
fi

{
  echo "- [$TIMESTAMP] \`$COMMIT_HASH\` $COMMIT_MSG"
  echo "$FILES_CHANGED" | sed 's/^/  - /'
} >> "$ACTIVE_CONTEXT"

# Update frontmatter timestamp (portable sed -i: try GNU, fall back to macOS)
sed_inplace() {
  if sed -i "s|$1|$2|" "$3" 2>/dev/null; then
    return 0
  else
    # macOS sed requires backup extension
    sed -i '' "s|$1|$2|" "$3" 2>/dev/null || true
  fi
}
if grep -q "^last_updated:" "$ACTIVE_CONTEXT" 2>/dev/null; then
  sed_inplace "^last_updated:.*" "last_updated: $TIMESTAMP" "$ACTIVE_CONTEXT"
fi
if grep -q "^last_updated_by:" "$ACTIVE_CONTEXT" 2>/dev/null; then
  sed_inplace "^last_updated_by:.*" "last_updated_by: post-commit-hook" "$ACTIVE_CONTEXT"
fi

# Clear needs-persist marker
rm -f "$KNOWLEDGE_DIR/.needs-persist" 2>/dev/null || true

# Ruflo push sync if knowledge files were in the commit
if echo "$FILES_CHANGED" | grep -q ".claude/knowledge/" 2>/dev/null; then
  if [ -x ".claude/hooks/ruflo-sync.sh" ]; then
    .claude/hooks/ruflo-sync.sh push 2>/dev/null || true
  fi
fi
