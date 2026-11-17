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

.PHONY: policy-test

policy-test:
	@docker run --rm \
		-v "$(CURDIR)/security/policies:/policies:ro" \
		-v "$(CURDIR)/tests/policies:/tests:ro" \
		openpolicyagent/opa:1.22.4 \
		test -v /policies /tests

.PHONY: go-test go-build go-scan

go-test:
	@docker run --rm \
		-v "$(CURDIR)/apps/vulnerable-go-api:/src:ro" \
		-w /src \
		golang:1.25-alpine \
		go test -v ./...

go-build:
	@docker build \
		-t devsecops-go-api:lab \
		apps/vulnerable-go-api

go-scan:
	@REPORT_NAME=go-image \
		bash scripts/security/trivy-scan.sh \
		image devsecops-go-api:lab

.PHONY: dast-regression-test

dast-regression-test:
	@python3 tests/integration/validate_zap_regression.py

.PHONY: dast-gate-test

dast-gate-test:
	@bash scripts/security/validate-dast-gate.sh
