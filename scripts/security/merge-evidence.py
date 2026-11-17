#!/usr/bin/env python3
"""Merge validated Trivy image and normalized ZAP evidence."""

import json
import sys
from pathlib import Path

SEVERITIES = {
    "UNKNOWN", "LOW", "MEDIUM", "HIGH", "CRITICAL"
}

IMAGE_NAME = "devsecops-go-api:lab"


def read_json(path: str) -> dict:
    value = json.loads(Path(path).read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise ValueError(f"Expected JSON object: {path}")
    return value


def normalize_trivy(report: dict) -> list[dict]:
    if report.get("SchemaVersion") != 2:
        raise ValueError("Unexpected Trivy JSON schema")

    artifact = report.get("ArtifactName")
    if not isinstance(artifact, str) or IMAGE_NAME not in artifact:
        raise ValueError("Unexpected Trivy image target")

    results = report.get("Results")
    if not isinstance(results, list):
        raise ValueError("Missing Trivy Results array")

    findings = []

    for result in results:
        if not isinstance(result, dict):
            raise ValueError("Invalid Trivy result")

        for field, id_field in (
            ("Vulnerabilities", "VulnerabilityID"),
            ("Misconfigurations", "ID"),
        ):
            entries = result.get(field, [])
            if not isinstance(entries, list):
                raise ValueError(f"Invalid Trivy {field}")

            for entry in entries:
                if not isinstance(entry, dict):
                    raise ValueError("Invalid Trivy finding")

                if field == "Misconfigurations":
                    if entry.get("Status") != "FAIL":
                        continue

                identifier = entry.get(id_field)
                severity = entry.get("Severity")

                if not isinstance(identifier, str) or not identifier:
                    raise ValueError("Missing Trivy finding identifier")

                if severity not in SEVERITIES:
                    raise ValueError("Invalid Trivy severity")

                findings.append({
                    "id": f"TRIVY-{identifier}",
                    "severity": severity,
                })

    return findings


def normalize_zap(report: dict) -> list[dict]:
    if (
        report.get("scan_status") != "success"
        or report.get("findings_complete") is not True
    ):
        raise ValueError("Invalid ZAP normalization metadata")

    findings = report.get("findings")

    if not isinstance(findings, list):
        raise ValueError("Missing ZAP findings")

    for finding in findings:
        if not isinstance(finding, dict):
            raise ValueError("Invalid ZAP finding")

        identifier = finding.get("id")
        severity = finding.get("severity")

        if not isinstance(identifier, str) or not identifier.startswith("ZAP-"):
            raise ValueError("Invalid ZAP finding identifier")

        if severity not in SEVERITIES:
            raise ValueError("Invalid ZAP severity")

    return findings


def main() -> int:
    if len(sys.argv) != 4:
        print(
            "Usage: merge-evidence.py TRIVY ZAP OUTPUT",
            file=sys.stderr,
        )
        return 2

    try:
        trivy = read_json(sys.argv[1])
        zap = read_json(sys.argv[2])

        findings = (
            normalize_trivy(trivy)
            + normalize_zap(zap)
        )

        evidence = {
            "scan_status": "success",
            "findings_complete": True,
            "sources": [
                "trivy-image",
                "zap-api-passive",
            ],
            "findings": findings,
        }

        destination = Path(sys.argv[3])
        destination.parent.mkdir(
            parents=True, exist_ok=True
        )

        destination.write_text(
            json.dumps(evidence, indent=2) + "\n",
            encoding="utf-8",
        )

        print("=== UNIFIED EVIDENCE ===")
        print(f"Total findings: {len(findings)}")

        for severity in (
            "CRITICAL", "HIGH", "MEDIUM", "LOW", "UNKNOWN"
        ):
            count = sum(
                item["severity"] == severity
                for item in findings
            )
            print(f"{severity}: {count}")

        return 0

    except (OSError, ValueError) as error:
        print(f"[ERROR] {error}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
