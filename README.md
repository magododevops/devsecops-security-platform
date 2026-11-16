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

## Sample Applications

- Java / Spring Boot
- TypeScript / Next.js
- Python / FastAPI

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
