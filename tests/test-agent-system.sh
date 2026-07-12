#!/usr/bin/env bash
set -euo pipefail
export PYTHONDONTWRITEBYTECODE=1

REPO=${1:-$(git rev-parse --show-toplevel)}
REPO=$(cd "$REPO" && pwd)

echo "=== Neutral agent specification and generated runtime assets ==="
for root in . template templates/python templates/rust; do
  python "$REPO/$root/.ai/generators/compile.py" --root "$REPO/$root" --check
  [ ! -f "$REPO/$root/.ai/context/active-context.md" ] || {
    echo "FAIL: $root seeds placeholder active-context.md"
    exit 1
  }
  echo "PASS: $root"
done

python "$REPO/tests/test-agent-contracts.py" --repo "$REPO"

echo "Agent-system checks passed."
