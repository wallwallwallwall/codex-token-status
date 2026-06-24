#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="QuotaStatus"
VERSION="1.0.0"
APP_DIR="${ROOT_DIR}/dist/${APP_NAME}.app"
PKG_PATH="${ROOT_DIR}/dist/${APP_NAME}-${VERSION}.pkg"

"${ROOT_DIR}/mac-app/build-mac-app.sh" >/dev/null
rm -f "$PKG_PATH"

pkgbuild \
  --component "$APP_DIR" \
  --install-location "/Applications" \
  --identifier "app.quotastatus.desktop" \
  --version "$VERSION" \
  "$PKG_PATH"

echo "$PKG_PATH"
