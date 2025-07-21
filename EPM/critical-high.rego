package cloudsmith
default match := false

# Treat "critical" in any typical casing as the same value
critical_high_vals := {"CRITICAL", "HIGH"}

match if {
    some v in input.v0.vulnerabilities
    v.severity in critical_high_vals
}
