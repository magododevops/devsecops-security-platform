#!/usr/bin/env bash
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

echo "=== DevSecOps Developer Setup ==="

for command in git docker pre-commit; do
  if ! command -v "$command" >/dev/null 2>&1; then
    echo "[ERROR] Missing dependency: $command"
    exit 1
  fi
done

if ! docker info >/dev/null 2>&1; then
  echo "[ERROR] Docker daemon unavailable."
  exit 1
fi

echo "[INFO] Installing Git hooks..."
pre-commit install --hook-type pre-commit

echo "[INFO] Validating configuration..."
pre-commit validate-config

echo "[INFO] Running baseline checks..."
pre-commit run --all-files

echo "[SUCCESS] Developer security environment ready."
