#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-}"
TARGET="${2:-}"
REPORT_DIR="${REPORT_DIR:-reports/trivy}"

usage() {
  echo "Usage: $0 {sca|iac|image} <target>"
  exit 2
}

if [[ -z "$MODE" || -z "$TARGET" ]]; then
  usage
fi

if ! command -v trivy >/dev/null 2>&1; then
  echo "[ERROR] Trivy is not installed."
  exit 2
fi

mkdir -p "$REPORT_DIR"

case "$MODE" in
  sca)
    SCAN_TYPE="fs"
    SCANNERS="vuln"
    ;;
  iac)
    SCAN_TYPE="fs"
    SCANNERS="misconfig"
    ;;
  image)
    SCAN_TYPE="image"
    SCANNERS="vuln"
    ;;
  *)
    usage
    ;;
esac

REPORT_NAME="${REPORT_NAME:-$MODE}"

if [[ ! "$REPORT_NAME" =~ ^[a-zA-Z0-9_-]+$ ]]; then
  echo "[ERROR] Invalid report name."
  exit 2
fi

REPORT="${REPORT_DIR}/${REPORT_NAME}.json"

echo "[INFO] Mode: $MODE"
echo "[INFO] Target: $TARGET"
echo "[INFO] Output: $REPORT"

trivy "$SCAN_TYPE" \
  --scanners "$SCANNERS" \
  --format json \
  --output "$REPORT" \
  --exit-code 0 \
  "$TARGET"

echo "[SUCCESS] Trivy scan completed: $REPORT"
