#!/usr/bin/env bash
set -euo pipefail
export PYTHONDONTWRITEBYTECODE=1

REPO=${1:-$(git rev-parse --show-toplevel)}
REPO=$(cd "$REPO" && pwd)

echo "=== V3 template lifecycle ==="
python "$REPO/tools/template.py" --repo "$REPO" check
python "$REPO/tests/test-template-v3.py"
python "$REPO/tests/test-knowledge.py"

echo ""
echo "=== V2 compatibility provider contracts ==="
LEGACY_PROJECT=$(mktemp -d)
trap 'rm -rf "$LEGACY_PROJECT"' EXIT
cp -a "$REPO/compat/v2/." "$LEGACY_PROJECT/"
python "$LEGACY_PROJECT/.ai/generators/compile.py" --root "$LEGACY_PROJECT"
python "$LEGACY_PROJECT/.ai/generators/compile.py" --root "$LEGACY_PROJECT" --check
python "$REPO/tests/test-agent-contracts.py" --legacy-root "$LEGACY_PROJECT"

echo "Agent-system checks passed."
