.PHONY: help setup security-check

help:
	@echo "Available commands:"
	@echo "  make setup           Install local security hooks"
	@echo "  make security-check  Run all local security checks"

setup:
	@bash scripts/bootstrap.sh

security-check:
	@pre-commit run --all-files

.PHONY: security-sca security-iac security-image

security-sca:
	@bash scripts/security/trivy-scan.sh sca examples/dependency-security

security-iac:
	@bash scripts/security/trivy-scan.sh iac examples/container-security

security-image:
	@bash scripts/security/trivy-scan.sh image devsecops-secure-demo:lab
