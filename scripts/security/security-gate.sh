#!/usr/bin/env bash
set -euo pipefail

REPORT="${1:?Usage: security-gate.sh <normalized-report>}"
OPA_IMAGE="openpolicyagent/opa:1.22.4"

cd "$(git rev-parse --show-toplevel)"

if [[ ! -f "$REPORT" ]]; then
    echo "[DENY] Report not found: $REPORT"
    exit 1
fi

if ! jq -e . "$REPORT" >/dev/null 2>&1; then
    echo "[DENY] Invalid JSON report"
    exit 1
fi

REPORT_ABS="$(realpath "$REPORT")"
ROOT="$PWD"

echo "=== SECURITY POLICY EVALUATION ==="

if ! DECISION=$(docker run --rm \
    -v "$ROOT/security/policies:/policies:ro" \
    -v "$REPORT_ABS:/input.json:ro" \
    "$OPA_IMAGE" eval \
    --format raw \
    --data /policies \
    --input /input.json \
    'data.security.gate.allow'); then
    echo "[DENY] Policy evaluation failed"
    exit 1
fi

if [[ "$DECISION" == "true" ]]; then
    echo "[ALLOW] Security policy approved"
    exit 0
fi

echo "[DENY] Security policy rejected"
exit 1
