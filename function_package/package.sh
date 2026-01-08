#!/bin/bash
set -e

# Script to package the Azure Function with the bootstrap binary
# This creates a deployment package suitable for Azure Function deployment

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGE_DIR="${SCRIPT_DIR}/package"
BOOTSTRAP_BINARY="${SCRIPT_DIR}/../bootstrap"
OUTPUT_ZIP="${SCRIPT_DIR}/autoscaler-function.zip"

echo "Packaging Azure Function autoscaler..."

# Clean and create package directory
rm -rf "${PACKAGE_DIR}"
mkdir -p "${PACKAGE_DIR}"
mkdir -p "${PACKAGE_DIR}/AutoscalerTimer"

# Check if bootstrap binary exists
if [ ! -f "${BOOTSTRAP_BINARY}" ]; then
  echo "Error: bootstrap binary not found at ${BOOTSTRAP_BINARY}"
  exit 1
fi

# Copy bootstrap binary to package root
echo "Copying bootstrap binary..."
cp "${BOOTSTRAP_BINARY}" "${PACKAGE_DIR}/bootstrap"
chmod +x "${PACKAGE_DIR}/bootstrap"

# Copy host.json
echo "Copying host.json..."
cp "${SCRIPT_DIR}/host.json" "${PACKAGE_DIR}/host.json"

# Copy function.json
echo "Copying function.json..."
cp "${SCRIPT_DIR}/AutoscalerTimer/function.json" "${PACKAGE_DIR}/AutoscalerTimer/function.json"

# Create zip package
echo "Creating deployment package..."
cd "${PACKAGE_DIR}"
zip -r "${OUTPUT_ZIP}" ./*

# Cleanup
cd "${SCRIPT_DIR}"
rm -rf "${PACKAGE_DIR}"

echo "Package created successfully at ${OUTPUT_ZIP}"
echo "Package size: $(du -h "${OUTPUT_ZIP}" | cut -f1)"
