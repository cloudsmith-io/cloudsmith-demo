package cloudsmith

default match := false

max_epss := 0.0004
max_cvss_score := 7
target_repository := "acme-nonprod"
older_than_days := -30
ignored_cves := {"CVE-2023-45853"}

#
# MAIN MATCH RULE
# A package "matches" (i.e., triggers quarantine) if:
#  1) It's in the target repository.
#  2) It has at least one vulnerability meeting all of these conditions:
#     - Has `patched_versions` (meaning there's a fix).
#     - Severity == HIGH.
#     - CVSS v3 >= `max_cvss_score`.
#     - Published at least `older_than_days` days ago.
#     - Not in the ignored CVE list.
#     - Exceeds our EPSS threshold.
#
match if {
    # Check repository
    input.v0["repository"]["name"] == target_repository

    # Iterate through all vulnerabilities in `v0["vulnerabilities"]`.
    some vulnerability in input.v0["vulnerabilities"]
    
    # Must not be in our ignored CVE list
    not ignored_cve(vulnerability)

    # Must have a known patch for this vulnerability
    vulnerability["patched_versions"]

    # Must exceed our EPSS score threshold
    exceeded_max_cvss(vulnerability)
    
    # Must exceed our CVSS score threshold
    exceeded_max_epss(vulnerability)

    # Check published date is older than (now + older_than_days).
    t := time.add_date(time.now_ns(), 0, 0, older_than_days)
    published_date := time.parse_rfc3339_ns(vulnerability.published_date)
    published_date <= t
}

#
# HELPER RULE: Exceeds EPSS threshold
#
exceeded_max_epss(vulnerability) if {
    vulnerability.epss.score > max_epss
}

#
# HELPER RULE: Exceeds CVSS threshold
#
exceeded_max_cvss(vulnerability) if {
    some _, val in vulnerability.cvss
    val.V3Score >= max_cvss_score
}

#
# HELPER RULE: Ignored CVEs
#
ignored_cve(vulnerability) if {
    vulnerability["identifier"] in ignored_cves
}