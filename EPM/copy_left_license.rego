package cloudsmith
import rego.v1

default match := false
copyleft := {                             # SPDX identifiers
    "GPL-3.0", "GPLv3+", "GPL-3.0-only", "GPL-3.0-or-later",
    "GPL-2.0", "GPL-2.0-only", "GPL-2.0-or-later",
    "LGPL-3.0", "LGPL-2.1",
    "AGPL-3.0", "AGPL-3.0-only", "AGPL-3.0-or-later",
    "Apache-1.1",        # often treated as strong copyleft
    "CPOL-1.02", "NGPL", "OSL-3.0", "QPL-1.0", "Sleepycat"
}

match if {
    # licence string (SPDX or free-text) hits deny-list
    some l in copyleft
    licence_is(l)
}

licence_is(l) if l == input.v0["package"].license
licence_is(l) if contains(lower(input.v0["package"].license), lower(l))