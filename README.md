# Quota Display

Native macOS status app for viewing local Codex quota. It reads quota data from the locally installed Codex app-server only; it does not call any remote quota API.

## Install

```bash
./mac-app/install-mac-app.sh
```

The app is installed to:

```text
~/Applications/QuotaStatus.app
```

By default it calls:

```text
/Applications/Codex.app/Contents/Resources/codex
```

If Codex is installed elsewhere, override the local command path:

```bash
QUOTA_STATUS_CODEX_COMMAND=/path/to/codex ./mac-app/install-mac-app.sh
```

Optional custom display title:

```bash
QUOTA_STATUS_TITLE="My Codex" ./mac-app/install-mac-app.sh
```

## Package

Create a shareable installer package:

```bash
./mac-app/package-mac-app.sh
```

Output:

```text
dist/QuotaStatus-1.0.0.pkg
```

Create a zipped `.app`:

```bash
./mac-app/build-mac-app.sh
cd dist
ditto -c -k --sequesterRsrc --keepParent QuotaStatus.app QuotaStatus-mac.zip
```

Builds are ad-hoc signed and not notarized. On another Mac, the first launch may require allowing the app in macOS security settings.
