#!/usr/bin/env python3
"""Normalize OWASP ZAP traditional JSON reports for OPA."""

import json
import sys
from pathlib import Path

RISK_LEVELS = {
    "0": "UNKNOWN",
    "1": "LOW",
    "2": "MEDIUM",
    "3": "HIGH",
}

EXPECTED_TARGET = "http://go-api:8080"


def normalize(report: dict) -> dict:
    sites = report.get("site")

    if not isinstance(sites, list) or not sites:
        raise ValueError("Missing or empty site list")

    findings = []
    target_found = False

    for site in sites:
        if not isinstance(site, dict):
            raise ValueError("Invalid site entry")

        if site.get("@name") != EXPECTED_TARGET:
            raise ValueError("Unexpected ZAP target")

        target_found = True

        alerts = site.get("alerts")

        if not isinstance(alerts, list):
            raise ValueError("Missing alerts array")

        for alert in alerts:
            if not isinstance(alert, dict):
                raise ValueError("Invalid alert")

            rule_id = alert.get("pluginid")
            risk = str(alert.get("riskcode", ""))

            if (
                not isinstance(rule_id, (str, int))
                or str(rule_id) == ""
                or risk not in RISK_LEVELS
            ):
                raise ValueError("Invalid alert metadata")

            findings.append({
                "id": f"ZAP-{rule_id}",
                "severity": RISK_LEVELS[risk],
            })

    if not target_found:
        raise ValueError("Expected target not found")

    return {
        "scan_status": "success",
        "findings_complete": True,
        "findings": findings,
    }


def main() -> int:
    if len(sys.argv) != 3:
        print(
            "Usage: normalize-zap.py <input> <output>",
            file=sys.stderr,
        )
        return 2

    source = Path(sys.argv[1])
    destination = Path(sys.argv[2])

    try:
        raw = json.loads(source.read_text(encoding="utf-8"))

        if not isinstance(raw, dict):
            raise ValueError("Invalid report root")

        normalized = normalize(raw)

        destination.parent.mkdir(
            parents=True,
            exist_ok=True,
        )

        destination.write_text(
            json.dumps(normalized, indent=2) + "\n",
            encoding="utf-8",
        )

        print(
            f"[OK] ZAP: {len(normalized['findings'])} findings"
        )

        return 0

    except (OSError, ValueError) as exc:
        print(f"[ERROR] {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
