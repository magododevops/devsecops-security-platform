.PHONY: help setup security-check

help:
	@echo "Available commands:"
	@echo "  make setup           Install local security hooks"
	@echo "  make security-check  Run all local security checks"

setup:
	@bash scripts/bootstrap.sh

security-check:
	@pre-commit run --all-files
