#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="QuotaStatus"
APP_DIR="${ROOT_DIR}/dist/${APP_NAME}.app"
CONTENTS_DIR="${APP_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"
SOURCE_FILE="${ROOT_DIR}/mac-app/QuotaStatus/QuotaStatusApp.swift"
PLIST_FILE="${ROOT_DIR}/mac-app/QuotaStatus/Info.plist"
ICON_SCRIPT="${ROOT_DIR}/mac-app/generate-icon.swift"
BUILD_DIR="${ROOT_DIR}/dist/build"

rm -rf "$APP_DIR"
rm -rf "$BUILD_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR" "$BUILD_DIR"
cp "$PLIST_FILE" "${CONTENTS_DIR}/Info.plist"
xcrun swift "$ICON_SCRIPT" "${RESOURCES_DIR}/QuotaStatus.icns"

xcrun swiftc \
  -parse-as-library \
  -O \
  -target arm64-apple-macosx13.0 \
  -framework SwiftUI \
  -framework AppKit \
  "$SOURCE_FILE" \
  -o "${BUILD_DIR}/${APP_NAME}-arm64"

xcrun swiftc \
  -parse-as-library \
  -O \
  -target x86_64-apple-macosx13.0 \
  -framework SwiftUI \
  -framework AppKit \
  "$SOURCE_FILE" \
  -o "${BUILD_DIR}/${APP_NAME}-x86_64"

lipo -create \
  "${BUILD_DIR}/${APP_NAME}-arm64" \
  "${BUILD_DIR}/${APP_NAME}-x86_64" \
  -output "${MACOS_DIR}/${APP_NAME}"

chmod +x "${MACOS_DIR}/${APP_NAME}"
codesign --force --deep --sign - "$APP_DIR" >/dev/null
rm -rf "$BUILD_DIR"

echo "$APP_DIR"
