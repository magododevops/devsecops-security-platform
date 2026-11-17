#!/usr/bin/env bash
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

NETWORK="devsecops-mass-test"
TARGET="devsecops-mass-api"

cleanup() {
    docker rm -f "$TARGET" >/dev/null 2>&1 || true
    docker network rm "$NETWORK" >/dev/null 2>&1 || true
}

trap cleanup EXIT
cleanup

docker pull python:3.12-alpine >/dev/null
docker network create --internal "$NETWORK" >/dev/null

run_case() {
    local name="$1"
    local isolated="$2"
    local scenario="$3"
    local expected="$4"
    local result

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

    result="$(docker run --rm \
        --network "$NETWORK" \
        python:3.12-alpine \
        python -c '
import json
import time
from urllib.request import Request, urlopen
from urllib.error import HTTPError, URLError

url = "http://go-api:8080/v1/work-orders/WO-1001"
payload = json.dumps({
    "status": "closed",
    "tenant_id": "tenant-beta"
}).encode()

for attempt in range(10):
    try:
        request = Request(
            url,
            data=payload,
            method="PATCH",
            headers={
                "Authorization": "Bearer lab-alice",
                "Content-Type": "application/json"
            },
        )

        try:
            with urlopen(request, timeout=5) as response:
                status = response.status
                body = json.load(response)
        except HTTPError as error:
            status = error.code
            body = {}

        print(json.dumps({
            "status": status,
            "tenant_id": body.get("tenant_id")
        }))
        break
    except URLError:
        if attempt == 9:
            raise
        time.sleep(0.2)
')"

    docker rm -f "$TARGET" >/dev/null

    echo "=== $name ==="
    echo "$result" | jq .

    echo "$result" | jq -e \
      --argjson expected "$expected" '
        .status == $expected and
        (if $expected == 200 then
            .tenant_id == "tenant-beta"
         else
            .tenant_id == null
         end)
      ' >/dev/null || {
        echo "[FAIL] Unexpected security behavior"
        exit 1
    }

    echo "[PASS] Expected behavior confirmed"
}

run_case "Secure mode" 0 "" 400
run_case "Scenario not isolated" 0 mass-assignment 400
run_case "Vulnerable lab mode" 1 mass-assignment 200

echo "[PASS] Mass Assignment HTTP regression completed"
