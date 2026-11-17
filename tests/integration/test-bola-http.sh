#!/usr/bin/env bash
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

NETWORK="devsecops-bola-test"
TARGET="devsecops-bola-api"

cleanup() {
    docker rm -f "$TARGET" >/dev/null 2>&1 || true
    docker network rm "$NETWORK" >/dev/null 2>&1 || true
}

trap cleanup EXIT

# Download dependencies before creating the isolated network.
docker pull python:3.12-alpine >/dev/null

# Clean up any previous interrupted test run.
cleanup

docker network create --internal "$NETWORK" >/dev/null

run_case() {
    local name="$1"
    local isolated="$2"
    local scenario="$3"
    local expected="$4"
    local response

    docker run -d \
        --name "$TARGET" \
        --network "$NETWORK" \
        --network-alias go-api \
        --read-only \
        --cap-drop ALL \
        --security-opt no-new-privileges \
        -e LAB_ISOLATED="$isolated" \
        -e LAB_SCENARIO="$scenario" \
        devsecops-go-api:lab >/dev/null

    response="$(docker run --rm \
        --network "$NETWORK" \
        python:3.12-alpine \
        python -c '
import json
from urllib.request import Request, urlopen
from urllib.error import HTTPError

request = Request(
    "http://go-api:8080/v1/work-orders/WO-2001",
    headers={"Authorization": "Bearer lab-alice"},
)

try:
    with urlopen(request, timeout=10) as result:
        status = result.status
        body = json.load(result)
except HTTPError as error:
    status = error.code
    body = {}

print(json.dumps({
    "status": status,
    "tenant_id": body.get("tenant_id"),
}))
')"

    docker rm -f "$TARGET" >/dev/null

    echo "=== $name ==="
    echo "$response" | jq .

    if ! echo "$response" | jq -e \
        --argjson expected "$expected" '
        .status == $expected and
        (if $expected == 200 then
            .tenant_id == "tenant-beta"
         else
            .tenant_id == null
         end)
    ' >/dev/null; then
        echo "[FAIL] Unexpected authorization result"
        exit 1
    fi

    echo "[PASS] Expected authorization behavior confirmed"
}

run_case "Secure default" 0 "" 404
run_case "Scenario without isolation" 0 bola 404
run_case "Controlled BOLA" 1 bola 200

echo "[PASS] BOLA HTTP regression completed"
