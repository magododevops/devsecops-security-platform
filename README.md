# DevSecOps Security Platform

An open-source DevSecOps laboratory designed to demonstrate
reusable security pipelines, automated vulnerability detection,
Policy as Code, and software supply chain security.

## Objectives

- Standardize security checks across multiple technology stacks.
- Shift security testing left in the development lifecycle.
- Enforce auditable, automated security policies.
- Generate software bills of materials (SBOMs).
- Centralize security findings and remediation workflows.
- Demonstrate secure and vulnerable scenarios.

## Technology Stack

| Capability | Technology |
|---|---|
| CI/CD | GitHub Actions |
| SAST | Semgrep CE |
| Secrets | Gitleaks |
| SCA / IaC / Containers | Trivy |
| DAST | OWASP ZAP |
| Policy as Code | Open Policy Agent |
| SBOM | Syft |
| Vulnerability Management | DefectDojo OSS |
| Runtime | Docker Compose |

## Laboratory Application

The platform uses a single Go application as its primary
security testing target.

The application will contain controlled vulnerabilities
to demonstrate detection, remediation, and security gates.

Python, Bash, and Rego are used for platform automation
and policies, not as additional application stacks.

See [ADR-0002](docs/adr/0002-single-lab-application.md)
for the architectural rationale.

## Project Status

Foundation setup in progress.

Security tools, policies, applications, and CI workflows
will be implemented and verified incrementally.

## Security Notice

This repository is intended for security education and
controlled testing. Intentionally vulnerable applications
must only run in isolated, authorized environments.

Do not commit real credentials or expose vulnerable
lab services to public networks.

## Local Development Commands

The root Makefile provides a consistent interface for
application testing, security scanning, and policy validation.

| Command | Purpose |
|---|---|
| `make setup` | Configure local security hooks |
| `make check` | Run fast local security and unit tests |
| `make gitleaks` | Detect leaked credentials |
| `make semgrep` | Run static security checks |
| `make trivy-sca` | Scan vulnerable dependency fixtures |
| `make trivy-iac` | Analyze IaC and Dockerfile fixtures |
| `make trivy-image` | Build and scan the Go image |
| `make zap` | Run isolated ZAP API scanning |
| `make opa-test` | Test security policies |
| `make lab-clean` | Stop known lab containers |

Use `make help` to discover all commands.

Security reports are generated under `reports/` and are not
committed to Git.

The full end-to-end security pipeline will be introduced
after scanner evidence and coverage validation are hardened.
