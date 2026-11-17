.DEFAULT_GOAL := help

APP_DIR := apps/vulnerable-go-api
APP_IMAGE := devsecops-go-api:lab
OPA_IMAGE := openpolicyagent/opa:1.22.4
GO_IMAGE := golang:1.25-alpine

.PHONY: help setup check test security-check \
        gitleaks semgrep \
        go-test go-build go-scan \
        trivy-sca trivy-iac trivy-image \
        security-sca security-iac security-image \
        opa-test policy-test opa-gate \
        zap dast-regression-test dast-gate-test \
        lab-clean

# --------------------------------------------------
# Developer Experience
# --------------------------------------------------

help:
	@echo ""
	@echo "DevSecOps Security Platform"
	@echo "==========================="
	@echo ""
	@echo "Development:"
	@echo "  make setup                  Configure local environment"
	@echo "  make check                  Run fast validations"
	@echo "  make test                   Run application and policy tests"
	@echo ""
	@echo "Security Scanners:"
	@echo "  make gitleaks               Secrets scanning"
	@echo "  make semgrep                Static application security testing"
	@echo "  make trivy-sca              Dependency vulnerability scanning"
	@echo "  make trivy-iac              Infrastructure configuration scanning"
	@echo "  make trivy-image            Build and scan Go container"
	@echo "  make zap                    Run isolated OWASP ZAP API scan"
	@echo ""
	@echo "Security Policies:"
	@echo "  make opa-test               Run Rego unit tests"
	@echo "  make opa-gate REPORT=path   Evaluate normalized evidence"
	@echo "  make dast-regression-test   Validate saved DAST regression evidence"
	@echo "  make dast-gate-test         Evaluate saved DAST evidence"
	@echo ""
	@echo "Application:"
	@echo "  make go-test                Run Go unit tests"
	@echo "  make go-build               Build Go container image"
	@echo ""
	@echo "Maintenance:"
	@echo "  make lab-clean              Stop known lab containers"
	@echo ""

setup:
	@bash scripts/bootstrap.sh

check: security-check test

test: go-test opa-test

security-check: gitleaks semgrep

# --------------------------------------------------
# Security Scanners
# --------------------------------------------------

gitleaks:
	@pre-commit run gitleaks-docker --all-files

semgrep:
	@pre-commit run semgrep --all-files

trivy-sca:
	@bash scripts/security/trivy-scan.sh \
		sca examples/dependency-security

trivy-iac:
	@bash scripts/security/trivy-scan.sh \
		iac examples/container-security

trivy-image: go-build
	@REPORT_NAME=go-image \
		bash scripts/security/trivy-scan.sh \
		image $(APP_IMAGE)

zap:
	@bash scripts/security/zap-api-scan.sh

# --------------------------------------------------
# Application
# --------------------------------------------------

go-test:
	@docker run --rm \
		-v "$(CURDIR)/$(APP_DIR):/src:ro" \
		-w /src \
		$(GO_IMAGE) \
		go test -v ./...

go-build:
	@docker build \
		-t $(APP_IMAGE) \
		$(APP_DIR)

# --------------------------------------------------
# Policy as Code
# --------------------------------------------------

opa-test:
	@docker run --rm \
		-v "$(CURDIR)/security/policies:/policies:ro" \
		-v "$(CURDIR)/tests/policies:/tests:ro" \
		$(OPA_IMAGE) \
		test -v /policies /tests

opa-gate:
	@test -n "$(REPORT)" || \
		(echo "Usage: make opa-gate REPORT=reports/normalized/file.json"; exit 2)
	@bash scripts/security/security-gate.sh "$(REPORT)"

# --------------------------------------------------
# Integration Tests
# --------------------------------------------------

dast-regression-test:
	@python3 tests/integration/validate_zap_regression.py

dast-gate-test:
	@bash scripts/security/validate-dast-gate.sh

# --------------------------------------------------
# Backward-Compatible Aliases
# --------------------------------------------------

security-sca: trivy-sca
security-iac: trivy-iac
security-image: trivy-image
go-scan: trivy-image
policy-test: opa-test

# --------------------------------------------------
# Maintenance
# --------------------------------------------------

lab-clean:
	@docker rm -f devsecops-go-api devsecops-go-dast \
		2>/dev/null || true
	@docker network rm devsecops-lab \
		2>/dev/null || true
	@echo "[OK] Known lab containers stopped"
	@echo "[INFO] Security reports were preserved"

# --------------------------------------------------
# API Security Regression
# --------------------------------------------------

.PHONY: api-security-test

api-security-test: go-build
	@bash tests/integration/test-bola-http.sh

.PHONY: mass-assignment-test api-regression

mass-assignment-test: go-build
	@bash tests/integration/test-mass-assignment-http.sh

api-regression: go-build
	@bash tests/integration/test-bola-http.sh
	@bash tests/integration/test-mass-assignment-http.sh
