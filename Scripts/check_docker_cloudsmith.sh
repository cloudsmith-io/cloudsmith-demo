#!/bin/bash

# Script to monitor the status of a Docker package in a Cloudsmith repository.

# Usage: ./check_cloudsmith.sh <ORG> <REPO> <API_KEY> <IMAGE_TAG>
# Example: ./check_cloudsmith.sh my-org my-repo my-api-key docker.cloudsmith.io/my-org/my-repo/my-image:latest

if [[ $# -lt 4 ]]; then
    echo "❌ Missing required input. Usage: ./check_cloudsmith.sh <ORG> <REPO> <API_KEY> <IMAGE_TAG>"
    exit 1
fi

# Inputs
ORG="$1"
REPO="$2"
CLOUDSMITH_API_KEY="$3"
IMAGE_TAG="$4"
MAX_RETRIES=${MAX_RETRIES:-20}
SLEEP_TIME=${SLEEP_TIME:-10}

# Extract image name and tag
if [[ ! "$IMAGE_TAG" =~ ^.*/.*/.*/.*:.*$ ]]; then
    echo "❌ Invalid IMAGE_TAG format. Expected 'docker.cloudsmith.io/org/repo/image:tag'."
    exit 1
fi
IMAGE_NAME=$(echo "$IMAGE_TAG" | cut -d'/' -f4 | cut -d':' -f1)
TAG_NAME=$(echo "$IMAGE_TAG" | cut -d':' -f2)

echo "🔍 Checking package status for $IMAGE_NAME:$TAG_NAME in $ORG/$REPO..."

for ((i=1; i<=MAX_RETRIES; i++)); do
    echo "🔄 Attempt $i of $MAX_RETRIES..."

    RESPONSE=$(curl -s --request GET \
         --url "https://api.cloudsmith.io/v1/packages/$ORG/$REPO/?query=tag%3A$TAG_NAME%20and%20format%3Adocker%20and%20name%3A$IMAGE_NAME&sort=-date" \
         --header "X-Api-Key: $CLOUDSMITH_API_KEY" \
         --header "accept: application/json")

    if [[ $? -ne 0 || -z "$RESPONSE" ]]; then
        echo "❌ Failed to fetch package data. Check your network or API key."
        exit 1
    fi

    PACKAGE=$(echo "$RESPONSE" | jq -r --arg IMAGE_NAME "$IMAGE_NAME" '.[] | select(.name == $IMAGE_NAME)')
    if [[ -z "$PACKAGE" ]]; then
        echo "❌ Package $IMAGE_NAME:$TAG_NAME not found. Retrying..."
        sleep $SLEEP_TIME
        continue
    fi

    PACKAGE_STATUS=$(echo "$PACKAGE" | jq -r '.status_str')
    SECURITY_SCAN_STATUS=$(echo "$PACKAGE" | jq -r '.security_scan_status')
    IS_QUARANTINED=$(echo "$PACKAGE" | jq -r '.is_quarantined')
    IS_SYNC_COMPLETED=$(echo "$PACKAGE" | jq -r '.is_sync_completed')

    echo "ℹ️ Package Status: $PACKAGE_STATUS"
    echo "🔎 Security Scan Status: $SECURITY_SCAN_STATUS"
    echo "🔒 Is Quarantined: $IS_QUARANTINED"

    if [[ "$IS_SYNC_COMPLETED" == "true" ]]; then
        echo "✅ Package sync completed."
    else
        echo "⏳ Sync in progress. Retrying..."
        sleep $SLEEP_TIME
        continue
    fi

    if [[ "$IS_QUARANTINED" == "true" ]]; then
        echo "🚨 Package is quarantined. Build failed."
        exit 1
    fi

    case "$SECURITY_SCAN_STATUS" in
        "Scan Detected No Vulnerabilities")
            echo "✅ No vulnerabilities detected."
            exit 0
            ;;
        "Scan Detected Vulnerabilities")
            echo "⚠️ Vulnerabilities detected."
            exit 1
            ;;
        "Awaiting Security Scan"|"Security Scanning in Progress")
            echo "⏳ Security scan in progress. Retrying..."
            ;;
        *)
            echo "❌ Unexpected status: $SECURITY_SCAN_STATUS. Retrying..."
            ;;
    esac

    sleep $SLEEP_TIME
done

echo "❗ Package status did not stabilize after $MAX_RETRIES attempts."
exit 1
Shared in
