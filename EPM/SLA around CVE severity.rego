package cloudsmith

import rego.v1

default match := false

t := time.add_date(
	time.now_ns(),
	0,
	0,
	-90,
)

match if {
	some vulnerability in input.v0.security_scan.Vulnerabilities
	vulnerability.Severity == "MEDIUM"
	published_date := time.parse_rfc3339_ns(vulnerability.PublishedDate)
	published_date <= t
}

reason contains msg if {
	some vulnerability in input.v0.security_scan.Vulnerabilities
	vulnerability.Severity == "MEDIUM"
	published_date := time.parse_rfc3339_ns(vulnerability.PublishedDate)
	published_date <= t
	msg := sprintf("Medium vulnerability detected: Package '%v' has VulnerabilityID '%v' with Severity '%v', and Published At '%v'", [input.v0["package"].name, vulnerability.VulnerabilityID, vulnerability.Severity, vulnerability.PublishedDate])
}