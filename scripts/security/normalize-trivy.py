#!/usr/bin/env python3
"""Normalize Trivy findings into a security gate input."""

import json
import sys
from pathlib import Path

SEVERITIES = {
    "UNKNOWN", "LOW", "MEDIUM", "HIGH", "CRITICAL"
}


def main() -> int:
    if len(sys.argv) != 3:
        print(
            "Usage: normalize-trivy.py <report> <output>",
            file=sys.stderr,
        )
        return 2

    source = Path(sys.argv[1])
    destination = Path(sys.argv[2])

    try:
        report = json.loads(source.read_text())

        if not isinstance(report, dict):
            raise ValueError("Invalid Trivy report")

        results = report.get("Results")

        if not isinstance(results, list):
            raise ValueError("Missing Results array")

        findings = []

        for result in results:
            if not isinstance(result, dict):
                raise ValueError("Invalid result entry")

            for field, identifier in (
                ("Vulnerabilities", "VulnerabilityID"),
                ("Misconfigurations", "ID"),
            ):
                entries = result.get(field, [])

                if not isinstance(entries, list):
                    raise ValueError(f"Invalid {field} array")

                for entry in entries:
                    if not isinstance(entry, dict):
                        raise ValueError("Invalid finding")

                    if (
                        field == "Misconfigurations"
                        and entry.get("Status") != "FAIL"
                    ):
                        continue

                    severity = entry.get("Severity")
                    finding_id = entry.get(identifier)

                    if (
                        severity not in SEVERITIES
                        or not isinstance(finding_id, str)
                        or not finding_id
                    ):
                        raise ValueError("Invalid finding data")

                    findings.append({
                        "id": finding_id,
                        "severity": severity,
                    })

        normalized = {
            "scan_status": "success",
            "findings_complete": True,
            "findings": findings,
        }

        destination.parent.mkdir(
            parents=True,
            exist_ok=True,
        )

        destination.write_text(
            json.dumps(normalized, indent=2) + "\n"
        )

        print(
            f"[OK] Normalized {len(findings)} findings"
        )

        return 0

    except (OSError, ValueError, json.JSONDecodeError) as exc:
        print(f"[ERROR] {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
