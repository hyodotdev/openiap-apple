#!/usr/bin/env bash
set -euo pipefail

# Download the Swift type definitions from openiap-gql release assets
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSIONS_FILE="${REPO_ROOT}/openiap-versions.json"

# Read version from openiap-versions.json if it exists, otherwise use fallback
if [ -f "${VERSIONS_FILE}" ] && command -v jq &> /dev/null; then
    DEFAULT_VERSION=$(jq -r '.gql' "${VERSIONS_FILE}")
elif [ -f "${VERSIONS_FILE}" ] && command -v python3 &> /dev/null; then
    DEFAULT_VERSION=$(python3 -c "import json; print(json.load(open('${VERSIONS_FILE}'))['gql'])")
else
    DEFAULT_VERSION="1.0.10"
    echo "⚠️  Warning: openiap-versions.json not found or jq/python3 not available. Using fallback version ${DEFAULT_VERSION}"
fi

VERSION="${OPENIAP_GQL_VERSION:-${1:-${DEFAULT_VERSION}}}"
ZIP_NAME="openiap-swift.zip"
SWIFT_FILE="Types.swift"
DOWNLOAD_URL="https://github.com/hyodotdev/openiap-gql/releases/download/${VERSION}/${ZIP_NAME}"
OUTPUT_DIR="${REPO_ROOT}/Sources/Models"
OUTPUT_PATH="${OUTPUT_DIR}/${SWIFT_FILE}"
TMP_DIR="$(mktemp -d -t openiap-swift-XXXXXX)"

cleanup() {
    rm -rf "${TMP_DIR}"
}
trap cleanup EXIT

mkdir -p "${OUTPUT_DIR}"

echo "Downloading Swift types for openiap-gql ${VERSION}..."
curl -fL "${DOWNLOAD_URL}" -o "${TMP_DIR}/${ZIP_NAME}"

echo "Extracting ${SWIFT_FILE}..."
# Extract generated file
TMP_SWIFT="${TMP_DIR}/${SWIFT_FILE}"
unzip -p "${TMP_DIR}/${ZIP_NAME}" "${SWIFT_FILE}" > "${TMP_SWIFT}"

# Copy to output location
mv "${TMP_SWIFT}" "${OUTPUT_PATH}"

echo "✅ Successfully updated ${OUTPUT_PATH}"
