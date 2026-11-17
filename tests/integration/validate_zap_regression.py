#!/usr/bin/env python3
"""Validate secure and insecure ZAP scan results."""

import json
import sys
from pathlib import Path

REPORTS = {
    "secure": Path("reports/zap/zap-secure.json"),
    "insecure": Path("reports/zap/zap-insecure.json"),
}

EXPECTED_RULE = "10037"


def load_alerts(path: Path) -> list[dict]:
    report = json.loads(path.read_text(encoding="utf-8"))

    sites = report.get("site")
    if not isinstance(sites, list) or not sites:
        raise ValueError(f"Invalid or empty ZAP report: {path}")

    alerts = []
    for site in sites:
        entries = site.get("alerts")
        if not isinstance(entries, list):
            raise ValueError(f"Missing alerts array: {path}")
        alerts.extend(entries)

    return alerts


def main() -> int:
    try:
        secure = load_alerts(REPORTS["secure"])
        insecure = load_alerts(REPORTS["insecure"])

        secure_matches = [
            alert for alert in secure
            if str(alert.get("pluginid")) == EXPECTED_RULE
        ]

        insecure_matches = [
            alert for alert in insecure
            if str(alert.get("pluginid")) == EXPECTED_RULE
        ]

        print("=== DAST REGRESSION TEST ===")
        print(f"Secure alerts: {len(secure)}")
        print(f"Insecure alerts: {len(insecure)}")
        print(f"Expected rule: {EXPECTED_RULE}")

        if secure_matches:
            print("[FAIL] Secure mode triggered the expected rule")
            return 1

        if not insecure_matches:
            print("[FAIL] Insecure mode was not detected")
            return 1

        if secure:
            print("[FAIL] Secure baseline contains unexpected alerts")
            return 1

        print("[PASS] Security regression detected correctly")
        return 0

    except (OSError, ValueError, KeyError) as exc:
        print(f"[ERROR] Invalid DAST evidence: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
