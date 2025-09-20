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

# Remove default arguments from protocol requirements (not supported in Swift)
python3 - <<'PY'
import os
import re
from pathlib import Path

source = Path(os.environ["TMP_SWIFT"])
dest = Path(os.environ["OUTPUT_PATH"])

text = source.read_text()

defaults = {
    r"func deepLinkToSubscriptions\(_ options: DeepLinkOptions\? = nil\)":
        "func deepLinkToSubscriptions(_ options: DeepLinkOptions?)",
    r"func finishTransaction\(purchase: PurchaseInput, isConsumable: Bool\? = nil\)":
        "func finishTransaction(purchase: PurchaseInput, isConsumable: Bool?)",
    r"func getActiveSubscriptions\(_ subscriptionIds: \[String\]\? = nil\)":
        "func getActiveSubscriptions(_ subscriptionIds: [String]?)",
    r"func getAvailablePurchases\(_ options: PurchaseOptions\? = nil\)":
        "func getAvailablePurchases(_ options: PurchaseOptions?)",
    r"func hasActiveSubscriptions\(_ subscriptionIds: \[String\]\? = nil\)":
        "func hasActiveSubscriptions(_ subscriptionIds: [String]?)",
}

for pattern, replacement in defaults.items():
    text = re.sub(pattern, replacement, text)

source.write_text(text)
source.replace(dest)
PY

echo "Wrote ${OUTPUT_PATH}"
