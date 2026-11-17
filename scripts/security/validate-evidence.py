#!/usr/bin/env python3
"""Fail-closed validation of raw Trivy and ZAP evidence."""

import json
import sys
from pathlib import Path

EXPECTED_IMAGE = "devsecops-go-api:lab"
EXPECTED_ZAP_TARGET = "http://go-api:8080"


def read_report(path: str) -> dict:
    report = json.loads(Path(path).read_text(encoding="utf-8"))

    if not isinstance(report, dict):
        raise ValueError(f"Invalid report root: {path}")

    return report


def validate_trivy(report: dict) -> None:
    if report.get("SchemaVersion") != 2:
        raise ValueError("Unsupported Trivy schema")

    if report.get("ArtifactName") != EXPECTED_IMAGE:
        raise ValueError("Trivy scanned an unexpected image")

    results = report.get("Results")

    if not isinstance(results, list) or not results:
        raise ValueError("Trivy has no scan results")

    if not any(
        isinstance(result, dict)
        and isinstance(result.get("Target"), str)
        and result["Target"]
        for result in results
    ):
        raise ValueError("Trivy has no identified scan target")

    for result in results:
        if not isinstance(result, dict):
            raise ValueError("Malformed Trivy result")

        for key in ("Vulnerabilities", "Misconfigurations"):
            if key in result and not isinstance(result[key], list):
                raise ValueError(f"Invalid Trivy {key}")


def validate_zap(report: dict) -> None:
    sites = report.get("site")

    if not isinstance(sites, list) or not sites:
        raise ValueError("ZAP has no site results")

    for site in sites:
        if not isinstance(site, dict):
            raise ValueError("Malformed ZAP site")

        if site.get("@name") != EXPECTED_ZAP_TARGET:
            raise ValueError("ZAP scanned an unexpected target")

        alerts = site.get("alerts")

        if not isinstance(alerts, list):
            raise ValueError("Missing ZAP alerts array")

        for alert in alerts:
            if not isinstance(alert, dict):
                raise ValueError("Malformed ZAP alert")

            if not str(alert.get("pluginid", "")):
                raise ValueError("Missing ZAP rule identifier")

            if str(alert.get("riskcode")) not in ("0", "1", "2", "3"):
                raise ValueError("Invalid ZAP risk code")


def main() -> int:
    if len(sys.argv) != 3:
        print(
            "Usage: validate-evidence.py TRIVY_JSON ZAP_JSON",
            file=sys.stderr,
        )
        return 2

    try:
        validate_trivy(read_report(sys.argv[1]))
        print("[PASS] Trivy evidence validated")

        validate_zap(read_report(sys.argv[2]))
        print("[PASS] ZAP evidence validated")

        return 0

    except (OSError, ValueError) as error:
        print(f"[DENY] Invalid evidence: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
