#!/usr/bin/env bash
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

RUN_DIR="$(mktemp -d reports/pipeline/run-XXXXXXXX)"

echo "========================================"
echo "  DEVSECOPS LOCAL SECURITY PIPELINE"
echo "========================================"
echo "[INFO] Evidence directory: $RUN_DIR"

echo
echo "=== 1. FAST SECURITY + UNIT TESTS ==="
make check

echo
echo "=== 2. API AUTHORIZATION REGRESSIONS ==="
make api-regression

echo
echo "=== 3. CONTAINER VULNERABILITY SCAN ==="

# Remove only this pipeline's expected output.
rm -f reports/trivy/go-image.json

make trivy-image

test -s reports/trivy/go-image.json || {
    echo "[ERROR] Trivy report is missing"
    exit 3
}

cp reports/trivy/go-image.json \
    "$RUN_DIR/trivy-image.json"

echo
echo "=== 4. OWASP ZAP PASSIVE API SCAN ==="

rm -f reports/zap/zap-api.json

# A ZAP exit code of 1 or 2 represents findings.
# Missing or malformed reports still cause pipeline failure.
if LAB_INSECURE_HEADERS=0 \
   LAB_ISOLATED=0 \
   LAB_SCENARIO="" \
   make zap; then
    ZAP_EXIT=0
else
    ZAP_EXIT=$?
fi

case "$ZAP_EXIT" in
    0|1|2)
        echo "[INFO] ZAP completed with status $ZAP_EXIT"
        ;;
    *)
        echo "[ERROR] ZAP execution failed: $ZAP_EXIT"
        exit 3
        ;;
esac

test -s reports/zap/zap-api.json || {
    echo "[ERROR] ZAP report is missing"
    exit 3
}

cp reports/zap/zap-api.json \
    "$RUN_DIR/zap-api.json"

echo
echo "=== 5. VALIDATE RAW EVIDENCE ==="

python3 scripts/security/validate-evidence.py \
    "$RUN_DIR/trivy-image.json" \
    "$RUN_DIR/zap-api.json"

echo
echo "=== 6. VERIFY IMAGE IDENTITY ==="

python3 scripts/security/audit-evidence.py \
    --trivy "$RUN_DIR/trivy-image.json"

echo
echo "=== 7. NORMALIZE ZAP ==="

python3 scripts/security/normalize-zap.py \
    "$RUN_DIR/zap-api.json" \
    "$RUN_DIR/zap-normalized.json"

echo
echo "=== 6. CONSOLIDATE EVIDENCE ==="

python3 scripts/security/merge-evidence.py \
    "$RUN_DIR/trivy-image.json" \
    "$RUN_DIR/zap-normalized.json" \
    "$RUN_DIR/unified-evidence.json"

echo
echo "=== 7. OPA SECURITY GATE ==="

if make opa-gate \
    REPORT="$RUN_DIR/unified-evidence.json"; then
    DECISION="ALLOW"
else
    DECISION="DENY"
fi

echo
echo "=== 8. WRITE AUDIT MANIFEST ==="

python3 scripts/security/audit-evidence.py \
    --trivy "$RUN_DIR/trivy-image.json" \
    --zap "$RUN_DIR/zap-api.json" \
    --unified "$RUN_DIR/unified-evidence.json" \
    --decision "$DECISION" \
    --output "$RUN_DIR/manifest.json"

echo "[INFO] Decision: $DECISION"
echo "[INFO] Evidence: $RUN_DIR"

if [[ "$DECISION" != "ALLOW" ]]; then
    echo "[DENY] Artifact blocked by security policy"
    exit 1
fi

echo
echo "[PASS] Security pipeline completed"
echo "[INFO] Evidence: $RUN_DIR"
