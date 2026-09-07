#!/usr/bin/env bash
set -euo pipefail
export PYTHONDONTWRITEBYTECODE=1

REPO=${1:-$(git rev-parse --show-toplevel)}
REPO=$(cd "$REPO" && pwd)

python "$REPO/tools/runtime_canary.py" --repo "$REPO" --contract "$REPO/tests/runtime-compatibility.yaml"

FIXTURE=$(mktemp -d)
trap 'rm -rf "$FIXTURE"' EXIT
touch "$FIXTURE/flake.nix"

python "$REPO/tools/template.py" --repo "$REPO" onboard --root "$FIXTURE"
python "$REPO/tools/runtime_canary.py" \
  --repo "$REPO" \
  --contract "$REPO/tests/runtime-compatibility.yaml" \
  --project "$FIXTURE"

python "$REPO/tools/template.py" profile --root "$FIXTURE" enable roles
python "$REPO/tools/runtime_canary.py" \
  --repo "$REPO" \
  --contract "$REPO/tests/runtime-compatibility.yaml" \
  --project "$FIXTURE" \
  --require-roles
