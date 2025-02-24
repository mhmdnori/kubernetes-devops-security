#!/bin/bash
set -euo pipefail

# Configuration
JENKINS_URL="${JENKINS_URL:-http://localhost:8080}"
CREDENTIALS="${JENKINS_USER:-admin}:${JENKINS_PASSWORD:-admin}"
PLUGIN_FILE="plugins.txt"
COOKIE_JAR=$(mktemp /tmp/jenkins_cookies.XXXXXX)
RETRY_TIMEOUT=60  # seconds
MAX_RETRIES=3

# Cleanup temporary files on exit
trap 'rm -f "${COOKIE_JAR}"' EXIT

# Get Jenkins Crumb
get_crumb() {
    curl -fsS \
        --cookie-jar "${COOKIE_JAR}" \
        --user "${CREDENTIALS}" \
        "${JENKINS_URL}/crumbIssuer/api/json" | jq -r .crumb
}

# Generate API Token
generate_token() {
    local crumb="$1"
    curl -fsS \
        -X POST \
        -H "Jenkins-Crumb: ${crumb}" \
        --cookie "${COOKIE_JAR}" \
        --user "${CREDENTIALS}" \
        "${JENKINS_URL}/me/descriptorByName/jenkins.security.ApiTokenProperty/generateNewToken?newTokenName=cli-token" \
        | jq -r '.data.tokenValue'
}

# Install plugins with retry logic
install_plugins() {
    local token="$1"
    while read -r plugin; do
        [[ -z "${plugin}" || "${plugin}" =~ ^# ]] && continue  # Skip empty lines and comments
        
        echo "Installing ${plugin}..."
        local retry=0
        until curl -fsS \
            -X POST \
            -H "Jenkins-Crumb: ${JENKINS_CRUMB}" \
            -H "Content-Type: text/xml" \
            --user "admin:${token}" \
            --data "<jenkins><install plugin='${plugin}'/></jenkins>" \
            "${JENKINS_URL}/pluginManager/installNecessaryPlugins"; do
            
            if (( retry++ >= MAX_RETRIES )); then
                echo "Failed to install ${plugin} after ${MAX_RETRIES} attempts" >&2
                exit 1
            fi
            sleep "${RETRY_TIMEOUT}"
        done
    done < "${PLUGIN_FILE}"
}

# Main execution
JENKINS_CRUMB=$(get_crumb)
JENKINS_TOKEN=$(generate_token "${JENKINS_CRUMB}")

install_plugins "${JENKINS_TOKEN}"

# Safe restart Jenkins
echo "Initiating safe restart..."
curl -fsS -X POST \
    -H "Jenkins-Crumb: ${JENKINS_CRUMB}" \
    --user "admin:${JENKINS_TOKEN}" \
    "${JENKINS_URL}/safeRestart"

# Wait for Jenkins to come back online
echo "Waiting for Jenkins to restart..."
until curl -fsS --head "${JENKINS_URL}"; do
    sleep 10
done

echo "All plugins installed successfully and Jenkins restarted"


# How to run
# export JENKINS_USER=admin
# export JENKINS_PASSWORD=your_secure_password
# ./installer.sh
