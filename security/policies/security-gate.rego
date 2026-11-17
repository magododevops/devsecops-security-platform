package security.gate

import rego.v1

default allow := false

deny contains "Invalid or incomplete scan input" if {
    not valid_input
}

deny contains reason if {
    valid_input

    some finding in input.findings

    finding.severity in {"HIGH", "CRITICAL"}

    reason := sprintf(
        "Blocked: %s finding detected (%s)",
        [finding.severity, finding.id],
    )
}

valid_input if {
    input.scan_status == "success"
    input.findings
    is_array(input.findings)
    input.findings_complete == true

    every finding in input.findings {
        is_object(finding)
        is_string(finding.id)
        finding.id != ""
        finding.severity in {
            "UNKNOWN",
            "LOW",
            "MEDIUM",
            "HIGH",
            "CRITICAL",
        }
    }
}

allow if {
    valid_input
    count(deny) == 0
}
