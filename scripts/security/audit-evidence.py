#!/usr/bin/env python3
"""Validate local Docker image identity and record pipeline evidence."""

import argparse
import hashlib
import json
import re
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

IMAGE = "devsecops-go-api:lab"
SHA256 = re.compile(r"^sha256:[0-9a-f]{64}$")


def command(*args):
    return subprocess.check_output(
        args, text=True, stderr=subprocess.PIPE
    ).strip()


def read_json(path):
    value = json.loads(Path(path).read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise ValueError(f"Invalid JSON object: {path}")
    return value


def sha256(path):
    digest = hashlib.sha256()
    with Path(path).open("rb") as source:
        for block in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def verify_identity(report_id, docker_id):
    if not isinstance(report_id, str) or not SHA256.fullmatch(report_id):
        raise ValueError("Missing or invalid Trivy image ID")

    if not isinstance(docker_id, str) or not SHA256.fullmatch(docker_id):
        raise ValueError("Missing or invalid Docker image ID")

    if report_id != docker_id:
        raise ValueError(
            f"Image identity mismatch: Trivy={report_id}, "
            f"Docker={docker_id}"
        )


def verify_image(trivy):
    if trivy.get("SchemaVersion") != 2:
        raise ValueError("Unexpected Trivy schema")

    if trivy.get("ArtifactName") != IMAGE:
        raise ValueError("Unexpected Trivy image target")

    metadata = trivy.get("Metadata")
    if not isinstance(metadata, dict):
        raise ValueError("Missing Trivy metadata")

    docker_id = command(
        "docker", "image", "inspect", IMAGE,
        "--format", "{{.Id}}",
    )
    verify_identity(metadata.get("ImageID"), docker_id)
    return docker_id


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--trivy", required=True)
    parser.add_argument("--zap")
    parser.add_argument("--unified")
    parser.add_argument("--output")
    parser.add_argument(
        "--decision", choices=("ALLOW", "DENY")
    )
    args = parser.parse_args()

    try:
        trivy = read_json(args.trivy)
        image_id = verify_image(trivy)
        print(f"[PASS] Image identity verified: {image_id}")

        if args.decision is None:
            if any((args.zap, args.unified, args.output)):
                raise ValueError("Missing decision for audit manifest")
            return 0

        if not all((args.zap, args.unified, args.output)):
            raise ValueError("Missing audit manifest arguments")

        zap = read_json(args.zap)
        unified = read_json(args.unified)

        if not isinstance(zap.get("site"), list) or not zap["site"]:
            raise ValueError("Invalid ZAP evidence")

        findings = unified.get("findings")
        if not isinstance(findings, list):
            raise ValueError("Missing unified findings")

        for finding in findings:
            if not isinstance(finding, dict):
                raise ValueError("Invalid unified finding")

        blocking = sum(
            item.get("severity") in ("HIGH", "CRITICAL")
            for item in findings
        )

        if (args.decision == "ALLOW") != (blocking == 0):
            raise ValueError("OPA decision and findings disagree")

        manifest = {
            "schema_version": 1,
            "created_at": datetime.now(timezone.utc).isoformat(),
            "git_commit": command("git", "rev-parse", "HEAD"),
            "git_dirty": bool(command("git", "status", "--porcelain")),
            "image": {
                "name": IMAGE,
                "image_id": image_id,
            },
            "evidence": {
                "trivy": {
                    "file": Path(args.trivy).name,
                    "sha256": sha256(args.trivy),
                },
                "zap": {
                    "file": Path(args.zap).name,
                    "sha256": sha256(args.zap),
                },
                "unified": {
                    "file": Path(args.unified).name,
                    "sha256": sha256(args.unified),
                },
            },
            "findings_count": len(findings),
            "blocking_findings_count": blocking,
            "decision": args.decision,
        }

        destination = Path(args.output)
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_text(
            json.dumps(manifest, indent=2) + "\n",
            encoding="utf-8",
        )
        print(f"[PASS] Audit manifest: {destination}")
        return 0

    except (
        OSError,
        ValueError,
        subprocess.CalledProcessError,
    ) as error:
        print(f"[DENY] Audit validation failed: {error}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
