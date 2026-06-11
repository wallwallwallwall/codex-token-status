#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="QuotaStatus.app"
INSTALL_DIR="${HOME}/Applications"

"${ROOT_DIR}/mac-app/build-mac-app.sh" >/dev/null

mkdir -p "$INSTALL_DIR"
rm -rf "${INSTALL_DIR}/${APP_NAME}"
ditto "${ROOT_DIR}/dist/${APP_NAME}" "${INSTALL_DIR}/${APP_NAME}"

open "${INSTALL_DIR}/${APP_NAME}" --args --accountId="${1:-mac-codex}"

echo "已安装并打开：${INSTALL_DIR}/${APP_NAME}"
