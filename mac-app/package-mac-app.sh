#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="QuotaStatus"
VERSION="1.0.4"
APP_DIR="${ROOT_DIR}/dist/${APP_NAME}.app"
PKG_PATH="${ROOT_DIR}/dist/${APP_NAME}-${VERSION}.pkg"
PKG_BUILD_DIR="${ROOT_DIR}/dist/pkgbuild"
PAYLOAD_ROOT="${PKG_BUILD_DIR}/payload"
COMPONENT_PLIST="${PKG_BUILD_DIR}/component.plist"
SCRIPTS_DIR="${PKG_BUILD_DIR}/scripts"

"${ROOT_DIR}/mac-app/build-mac-app.sh" >/dev/null
rm -f "$PKG_PATH"
rm -rf "$PKG_BUILD_DIR"
mkdir -p "$SCRIPTS_DIR" "${PAYLOAD_ROOT}/Applications"
ditto "$APP_DIR" "${PAYLOAD_ROOT}/Applications/${APP_NAME}.app"

cat > "$COMPONENT_PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<array>
  <dict>
    <key>BundleHasStrictIdentifier</key>
    <true/>
    <key>BundleIsRelocatable</key>
    <false/>
    <key>BundleIsVersionChecked</key>
    <false/>
    <key>BundleOverwriteAction</key>
    <string>upgrade</string>
    <key>RootRelativeBundlePath</key>
    <string>Applications/${APP_NAME}.app</string>
  </dict>
</array>
</plist>
EOF

cat > "${SCRIPTS_DIR}/preinstall" <<'EOF'
#!/bin/sh
/usr/bin/pkill -x QuotaStatus >/dev/null 2>&1 || true
exit 0
EOF

cat > "${SCRIPTS_DIR}/postinstall" <<'EOF'
#!/bin/sh
CONSOLE_USER="$(/usr/bin/stat -f %Su /dev/console 2>/dev/null || true)"
if [ -n "$CONSOLE_USER" ] && [ "$CONSOLE_USER" != "root" ]; then
  OLD_APP="/Users/${CONSOLE_USER}/Applications/QuotaStatus.app"
  if [ -d "$OLD_APP" ] && [ "$OLD_APP" != "/Applications/QuotaStatus.app" ]; then
    /bin/rm -rf "$OLD_APP"
  fi
  /usr/bin/sudo -u "$CONSOLE_USER" /usr/bin/open -a /Applications/QuotaStatus.app >/dev/null 2>&1 || /usr/bin/open -a /Applications/QuotaStatus.app >/dev/null 2>&1 || true
else
  /usr/bin/open -a /Applications/QuotaStatus.app >/dev/null 2>&1 || true
fi
exit 0
EOF
chmod +x "${SCRIPTS_DIR}/preinstall" "${SCRIPTS_DIR}/postinstall"

pkgbuild \
  --root "$PAYLOAD_ROOT" \
  --install-location "/" \
  --component-plist "$COMPONENT_PLIST" \
  --scripts "$SCRIPTS_DIR" \
  --identifier "app.quotastatus.desktop" \
  --version "$VERSION" \
  "$PKG_PATH"

rm -rf "$PKG_BUILD_DIR"
echo "$PKG_PATH"
