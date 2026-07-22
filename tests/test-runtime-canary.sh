#!/usr/bin/env bash
set -euo pipefail
export PYTHONDONTWRITEBYTECODE=1

REPO=${1:-$(git rev-parse --show-toplevel)}
REPO=$(cd "$REPO" && pwd)

python "$REPO/tools/runtime_canary.py" --repo "$REPO" --contract "$REPO/tests/runtime-compatibility.yaml"
