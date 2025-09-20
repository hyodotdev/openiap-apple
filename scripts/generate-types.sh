#!/usr/bin/env bash
set -euo pipefail

# Download the Swift type definitions from openiap-gql release assets
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="${OPENIAP_GQL_VERSION:-${1:-1.0.8}}"
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
export TMP_SWIFT OUTPUT_PATH
