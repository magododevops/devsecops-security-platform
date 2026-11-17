# ADR-0002: Single Go Application for Security Validation

Status: Accepted

## Context

The platform demonstrates security controls across the
software development lifecycle.

Maintaining multiple applications in different languages
would introduce unnecessary development and maintenance
complexity.

## Decision

Use a single Go application as the primary security
testing target.

The application will contain controlled security scenarios
and demonstrate secure and vulnerable implementations.

The security platform will remain language-independent.

## Architecture

- Go: primary laboratory application.
- Python: auxiliary security automation scripts.
- Rego: security policies.
- Bash: CLI orchestration.
- Docker: isolated execution.
- JSON: normalized security evidence.

## Consequences

Benefits:
- Less application maintenance.
- Greater focus on DevSecOps.
- Faster and reproducible security testing.
- Clearer portfolio documentation.

Trade-offs:
- Only one application language is tested end-to-end.
- Multi-stack integration remains an architectural
  capability, not a fully demonstrated implementation.

## Security Constraints

Intentionally vulnerable configurations must only be
executed in isolated, authorized lab environments.

Vulnerabilities must not be exposed through publicly
accessible services.
