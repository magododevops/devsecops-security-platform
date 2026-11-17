#!/usr/bin/env bash
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

NETWORK="devsecops-lab"
CONTAINER="devsecops-go-dast"
IMAGE="ghcr.io/zaproxy/zaproxy:stable"

mkdir -p reports/zap

# Prevent stale evidence from previous executions.
rm -f reports/zap/zap-api.json reports/zap/zap-api.html

cleanup() {
    docker rm -f "$CONTAINER" >/dev/null 2>&1 || true
    docker network rm "$NETWORK" >/dev/null 2>&1 || true
}

trap cleanup EXIT

echo "[INFO] Preparing isolated DAST environment"

docker network create --internal "$NETWORK"

docker run -d \
    --name "$CONTAINER" \
    --network "$NETWORK" \
    --network-alias go-api \
    -e LAB_INSECURE_HEADERS="${LAB_INSECURE_HEADERS:-0}" \
    --read-only \
    --cap-drop ALL \
    --security-opt no-new-privileges \
    --memory 128m \
    --pids-limit 64 \
    devsecops-go-api:lab >/dev/null

echo "[INFO] Executing ZAP API baseline scan"

set +e

docker run --rm \
    --network "$NETWORK" \
    -v "$PWD/reports/zap:/zap/wrk:rw" \
    -v "$PWD/apps/vulnerable-go-api/openapi.json:/zap/wrk/openapi.json:ro" \
    "$IMAGE" \
    zap-api-scan.py \
    -t /zap/wrk/openapi.json \
    -f openapi \
    -O http://go-api:8080 \
    -S \
    -J zap-api.json \
    -r zap-api.html

RESULT=$?

set -e

echo "[INFO] ZAP exit code: $RESULT"

if [[ ! -s reports/zap/zap-api.json ]]; then
    echo "[ERROR] ZAP report missing"
    exit 3
fi

jq -e '.site | type == "array"' \
    reports/zap/zap-api.json >/dev/null || {
    echo "[ERROR] Invalid ZAP report"
    exit 3
}

case "$RESULT" in
    0) echo "[PASS] No blocking alerts" ;;
    1) echo "[FINDINGS] ZAP reported FAIL alerts" ;;
    2) echo "[WARN] ZAP reported warnings" ;;
    *) echo "[ERROR] ZAP execution failed"; exit 3 ;;
esac

echo "[INFO] Reports saved in reports/zap"
exit "$RESULT"
