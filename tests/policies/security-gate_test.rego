package security.gate_test

import rego.v1

import data.security.gate

test_allow_clean_report if {
    gate.allow with input as {
        "scan_status": "success",
        "findings_complete": true,
        "findings": [],
    }
}

test_allow_low_finding if {
    gate.allow with input as {
        "scan_status": "success",
        "findings_complete": true,
        "findings": [
            {"id": "LOW-001", "severity": "LOW"},
        ],
    }
}

test_deny_high_finding if {
    not gate.allow with input as {
        "scan_status": "success",
        "findings_complete": true,
        "findings": [
            {"id": "HIGH-001", "severity": "HIGH"},
        ],
    }
}

test_deny_missing_report_metadata if {
    not gate.allow with input as {
        "findings": [],
    }
}

test_deny_failed_scan if {
    not gate.allow with input as {
        "scan_status": "failed",
        "findings_complete": false,
        "findings": [],
    }
}
