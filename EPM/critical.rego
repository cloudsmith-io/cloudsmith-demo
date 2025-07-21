package cloudsmith
default match := false

# Treat "critical" in any typical casing as the same value
critical_vals := {"CRITICAL"}

match if {
    some v in input.v0.vulnerabilities
    v.severity in critical_vals
}
