#!/usr/bin/env bash
# session-end.sh — pushes knowledge store to ruflo on session close
# Event: SessionEnd
set -euo pipefail

# Lightweight — just trigger ruflo sync if available
if [ -x ".claude/hooks/ruflo-sync.sh" ]; then
  .claude/hooks/ruflo-sync.sh push 2>/dev/null || true
fi
