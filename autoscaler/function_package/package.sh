#!/bin/bash
set -e

unset CDPATH
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"

AUTOSCALER_ZIP_PATH="$1"
OUTPUT_ZIP="$2"

if [ -z "$AUTOSCALER_ZIP_PATH" ] || [ -z "$OUTPUT_ZIP" ]; then
  echo "Usage: $0 <autoscaler-zip-path> <output-zip-path>"
  exit 1
fi

# Convert relative paths to absolute
if [[ "$AUTOSCALER_ZIP_PATH" != /* ]]; then
  AUTOSCALER_ZIP_PATH="$PWD/$AUTOSCALER_ZIP_PATH"
fi
if [[ "$OUTPUT_ZIP" != /* ]]; then
  OUTPUT_ZIP="$PWD/$OUTPUT_ZIP"
fi

OUTPUT_DIR="$(dirname "$OUTPUT_ZIP")"
mkdir -p "$OUTPUT_DIR"

PACKAGE_DIR="$(mktemp -d)"
trap "rm -rf \"$PACKAGE_DIR\"" EXIT

echo "Packaging Azure Function autoscaler..."

mkdir -p "${PACKAGE_DIR}/AutoscalerTimer"

if [ ! -f "$AUTOSCALER_ZIP_PATH" ]; then
  echo "Error: autoscaler zip not found at $AUTOSCALER_ZIP_PATH"
  exit 1
fi

echo "Extracting autoscaler binary..."
unzip -o -q "$AUTOSCALER_ZIP_PATH" -d "$PACKAGE_DIR"

if [ -f "${PACKAGE_DIR}/bootstrap" ]; then
  chmod +x "${PACKAGE_DIR}/bootstrap"
elif [ -f "${PACKAGE_DIR}/azure-vmss-workerpool-autoscaler" ]; then
  mv "${PACKAGE_DIR}/azure-vmss-workerpool-autoscaler" "${PACKAGE_DIR}/bootstrap"
  chmod +x "${PACKAGE_DIR}/bootstrap"
else
  echo "Error: No bootstrap or azure-vmss-workerpool-autoscaler binary found in zip"
  ls -la "$PACKAGE_DIR"
  exit 1
fi

echo "Copying function configuration..."
cp "$SCRIPT_DIR/host.json" "$PACKAGE_DIR/host.json"
cp "$SCRIPT_DIR/AutoscalerTimer/function.json" "$PACKAGE_DIR/AutoscalerTimer/function.json"

echo "Creating deployment package..."
# Use python to zip the directory since zip cli isnt on spacelift public workers
python3 -c "
import zipfile, os, sys

source_dir = sys.argv[1]
output_zip = sys.argv[2]

with zipfile.ZipFile(output_zip, 'w', zipfile.ZIP_DEFLATED) as z:
    for root, dirs, files in os.walk(source_dir):
        for f in files:
            full_path = os.path.join(root, f)
            arc_name = os.path.relpath(full_path, source_dir)
            z.write(full_path, arc_name)
" "$PACKAGE_DIR" "$OUTPUT_ZIP"

echo "Package created successfully at $OUTPUT_ZIP"
echo "Package size: $(du -h "$OUTPUT_ZIP" | cut -f1)"
