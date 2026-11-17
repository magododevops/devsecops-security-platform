#!/usr/bin/env bash
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

echo "=== DAST REGRESSION ==="
python3 tests/integration/validate_zap_regression.py

echo "=== NORMALIZE SECURE REPORT ==="
python3 scripts/security/normalize-zap.py \
    reports/zap/zap-secure.json \
    reports/normalized/zap-secure.json

echo "=== NORMALIZE INSECURE REPORT ==="
python3 scripts/security/normalize-zap.py \
    reports/zap/zap-insecure.json \
    reports/normalized/zap-insecure.json

echo "=== SECURE POLICY ==="
bash scripts/security/security-gate.sh \
    reports/normalized/zap-secure.json

echo "=== LOW RISK POLICY ==="
bash scripts/security/security-gate.sh \
    reports/normalized/zap-insecure.json

echo "[PASS] DAST evidence and policy checks completed"
