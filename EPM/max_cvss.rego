package cloudsmith

import rego.v1

# Default match rule
default match := false

# Define maximum CVSS score threshold
max_cvss_score := 6

# Target repository for the policy
target_repository := "REPO_NAME"

# Policy match criteria
match if {
    in_target_repository
    count(reason) != 0
}

# Check if the package belongs to the specified repository
in_target_repository if {
    input.v0.repository.name == target_repository
}

# Generate reasons for matching vulnerabilities
reason contains msg if {
    # Loop through all vulnerabilities
    some vulnerability in input.v0.security_scan.Vulnerabilities

    # Check if the vulnerability has a fixed version and is resolved
    vulnerability.FixedVersion
    vulnerability.Status == "fixed"

    # Ensure the CVSS score exceeds the threshold
    some _, val in vulnerability.CVSS
    val.V3Score >= max_cvss_score

    # Message for the reason
    msg := sprintf(
        "CVSS Score > %v",
        [max_cvss_score]
    )
}
