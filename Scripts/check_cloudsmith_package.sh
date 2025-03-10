#!/usr/bin/env bash
#
# Script: check_cloudsmith_maven_deps.sh
#
# Usage:
#   ./check_cloudsmith_maven_deps.sh <ORG> <REPO> <API_KEY> <PACKAGE_NAME> [<PACKAGE_VERSION>]
#
# Example:
#   ./check_cloudsmith_maven_deps.sh ciara-demo acme-nonprod MY-API-KEY my-app 1.0-SNAPSHOT
#
# Description:
#   1. Locates the parent Maven package in Cloudsmith (by name & optional version).
#   2. Checks if the parent is vulnerable or quarantined.
#   3. Fetches parent dependencies using the Dependencies API.
#   4. Checks each dependency for vulnerabilities/policy violations.
#   5. If any vulnerabilities are found, script exits with code 1 (fail).
#   6. Otherwise, script exits 0 (pass).
#
# Notes:
#   - If the package is a snapshot, you must match the *exact* timestamped version
#     (e.g. 1.0-20250303.122130-7) OR omit the version to just pick the latest.
#   - If you want multi-level recursion (dependencies-of-dependencies), you can
#     adapt the script with a recursive function or nested loops.

set -euo pipefail

if [[ $# -lt 4 ]]; then
  echo "❌ Missing required arguments."
  echo "Usage: $0 <ORG> <REPO> <API_KEY> <PACKAGE_NAME> [<PACKAGE_VERSION>]"
  exit 1
fi

ORG="$1"
REPO="$2"
API_KEY="$3"
PKG_NAME="$4"
PKG_VERSION="${5:-}"  # optional

# Helper function: URL-encode a query string
urlencode() {
  local raw="$1"
  echo -n "$raw" | sed 's/ /%20/g'
}

echo "🔍 Checking Maven package + dependencies in Cloudsmith..."

###############################################################################
# Step 1: Find the Parent Package
###############################################################################
QUERY="format:maven and name:$PKG_NAME"
if [[ -n "$PKG_VERSION" ]]; then
  QUERY="$QUERY and version:$PKG_VERSION"
fi

ENCODED_QUERY=$(urlencode "$QUERY")

echo "ℹ️ Searching for parent package with query: $QUERY"

# Fetch the newest match
PKG_SEARCH=$(curl -s -H "X-Api-Key: $API_KEY" \
  "https://api.cloudsmith.io/v1/packages/$ORG/$REPO/?query=$ENCODED_QUERY&sort=-date" \
  -H "accept: application/json")

if [[ -z "$PKG_SEARCH" || "$PKG_SEARCH" == "[]" ]]; then
  echo "❌ No package found for '$PKG_NAME' (version='$PKG_VERSION')."
  exit 1
fi

# We only take the first result
PARENT_PKG=$(echo "$PKG_SEARCH" | jq '.[0]')
PARENT_SLUG=$(echo "$PARENT_PKG" | jq -r '.slug_perm')
PARENT_NAME=$(echo "$PARENT_PKG" | jq -r '.name')
PARENT_VERSION=$(echo "$PARENT_PKG" | jq -r '.version')
PARENT_STATUS=$(echo "$PARENT_PKG" | jq -r '.security_scan_status')
PARENT_QUARANTINED=$(echo "$PARENT_PKG" | jq -r '.is_quarantined')

echo "🔎 Parent: $PARENT_NAME:$PARENT_VERSION (slug=$PARENT_SLUG)"
echo "🔎 Parent Security Scan: $PARENT_STATUS"
echo "🔒 Parent Quarantined: $PARENT_QUARANTINED"

# If the parent is quarantined or has vulnerabilities, fail immediately
if [[ "$PARENT_QUARANTINED" == "true" ]]; then
  echo "🚨 Parent package is quarantined (policy violated). Failing build..."
  exit 1
fi

if [[ "$PARENT_STATUS" == "Scan Detected Vulnerabilities" ]]; then
  echo "🚨 Parent package has vulnerabilities. Failing build..."
  exit 1
fi

###############################################################################
# Step 2: Get Dependencies
###############################################################################
echo "🔗 Fetching dependencies for parent slug: $PARENT_SLUG"

DEPS_JSON=$(curl -s -H "X-Api-Key: $API_KEY" \
  "https://api.cloudsmith.io/v1/packages/$ORG/$REPO/$PARENT_SLUG/dependencies/" \
  -H "accept: application/json")

# If there's an error or no data, the script might get an empty or null response
if [[ -z "$DEPS_JSON" || "$DEPS_JSON" == "null" ]]; then
  echo "⚠️  No dependencies found for $PARENT_NAME:$PARENT_VERSION. Possibly a jar-only package?"
  echo "✅ No vulnerabilities found in dependencies. Good to go!"
  exit 0
fi

NUM_DEPS=$(echo "$DEPS_JSON" | jq '.dependencies | length')
echo "🔍 Found $NUM_DEPS dependencies."

# If no dependencies, we can skip
if [[ "$NUM_DEPS" -eq 0 ]]; then
  echo "✅ No dependencies to check. Good to go!"
  exit 0
fi

VULNS_FOUND=0

###############################################################################
# Step 3: Check Each Dependency
###############################################################################
# The API returns e.g.:
#   "name": "com.fasterxml.jackson.core:jackson-databind",
#   "version": "2.9.10.1"
# We'll look for a matching package with that name & version in Cloudsmith.
echo "🔎 Checking each dependency for vulnerabilities..."

echo "$DEPS_JSON" | jq -r '.dependencies[] | "\(.name)|\(.version)"' | while read -r line; do
  DEP_NAME=$(echo "$line" | cut -d'|' -f1)
  DEP_VERSION=$(echo "$line" | cut -d'|' -f2)

  DEP_GROUP=$(echo "$DEP_NAME" | cut -d':' -f1)
  DEP_ARTIFACT=$(echo "$DEP_NAME" | cut -d':' -f2)
  # For searching in Cloudsmith
  CS_NAME="$DEP_ARTIFACT"

  # Some dependencies might not exist in your Cloudsmith repo if not proxied/cached
  #DEP_QUERY="format:maven and name:$DEP_NAME and version:$DEP_VERSION"
  DEP_QUERY="format:maven and name:$CS_NAME and version:$DEP_VERSION"
  DEP_ENCODED=$(urlencode "$DEP_QUERY")

  DEP_SEARCH=$(curl -s -H "X-Api-Key: $API_KEY" \
    "https://api.cloudsmith.io/v1/packages/$ORG/$REPO/?query=$DEP_ENCODED&sort=-date" \
    -H "accept: application/json")

  # If empty, means that dependency wasn't found. Possibly not proxied or is a jar only package
  if [[ -z "$DEP_SEARCH" || "$DEP_SEARCH" == "[]" ]]; then
    echo "⚠️  Dependency not found in Cloudsmith: $DEP_NAME:$DEP_VERSION. Skipping."
    continue
  fi

  DEP_PKG=$(echo "$DEP_SEARCH" | jq '.[0]')
  DEP_SLUG=$(echo "$DEP_PKG" | jq -r '.slug_perm')
  DEP_STATUS=$(echo "$DEP_PKG" | jq -r '.security_scan_status')
  DEP_QUARANTINED=$(echo "$DEP_PKG" | jq -r '.is_quarantined')
  DEP_NAME_CLOUDSMITH=$(echo "$DEP_PKG" | jq -r '.name')
  DEP_VER_CLOUDSMITH=$(echo "$DEP_PKG" | jq -r '.version')

  echo "   -> Found dependency in Cloudsmith: $DEP_NAME_CLOUDSMITH:$DEP_VER_CLOUDSMITH (slug=$DEP_SLUG)"
  echo "      SecurityScan=$DEP_STATUS, Quarantined=$DEP_QUARANTINED"

  # If quarantined or vulnerabilities found, mark failure
  if [[ "$DEP_QUARANTINED" == "true" ]]; then
    echo "🚨 Dependency $DEP_NAME:$DEP_VERSION is quarantined. Marking build as failed..."
    VULNS_FOUND=1
    continue
  fi

  if [[ "$DEP_STATUS" == "Scan Detected Vulnerabilities" ]]; then
    echo "🚨 Dependency $DEP_NAME:$DEP_VERSION is vulnerable. Marking build as failed..."
    VULNS_FOUND=1
    continue
  fi
done

# If any vulnerabilities found, we fail
if [[ "$VULNS_FOUND" -eq 1 ]]; then
  echo "❌ Vulnerabilities/policy violations found in dependencies!"
  exit 1
else
  echo "✅ No vulnerabilities found in dependencies. Good to go!"
  exit 0
fi
