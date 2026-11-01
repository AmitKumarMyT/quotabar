#!/bin/bash
set -e

echo "=========================================="
echo "    QuotaBar macOS Installer Script       "
echo "=========================================="

APP_NAME="QuotaBar.app"
SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_APP="${SOURCE_DIR}/${APP_NAME}"
TARGET_DIR="/Applications"
TARGET_APP="${TARGET_DIR}/${APP_NAME}"

# Fallback check
if [ ! -d "${SOURCE_APP}" ]; then
    SOURCE_APP="/Users/stalion/Downloads/QuotaBar/QuotaBar.app"
fi

if [ ! -d "${SOURCE_APP}" ]; then
    echo "Error: Cannot find ${APP_NAME} to install."
    exit 1
fi

echo "1. Stopping any currently running QuotaBar instances..."
pkill -f QuotaBar || true

echo "2. Installing ${APP_NAME} to ${TARGET_DIR}..."
rm -rf "${TARGET_APP}"
cp -R "${SOURCE_APP}" "${TARGET_APP}"

echo "3. Code signing installed application..."
codesign --force --deep --sign - "${TARGET_APP}"

echo "4. Removing macOS quarantine attributes..."
xattr -dr com.apple.quarantine "${TARGET_APP}" 2>/dev/null || true

echo "5. Launching QuotaBar from /Applications..."
open "${TARGET_APP}"

echo "=========================================="
echo "✓ QuotaBar installed and running successfully!"
echo "=========================================="
