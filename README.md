# Quota Display

Local status viewer for a square non-touch quota display. The page reads quota status from the NAS API through the local proxy and refreshes the display every five minutes.

## Run

```bash
node status-viewer/server.mjs
```

Open:

```text
http://localhost:53141/?accountId=mac-codex
```

The server proxies:

```text
/api/token-usage/status?accountId=<account-id>
```

to `https://api.wals.top` by default. Override with `TOKEN_USAGE_READ_API` if needed.

原生 Mac 应用:

```bash
./mac-app/install-mac-app.sh [accountId]
```

默认账户为 `mac-codex`。安装后应用位于：

```text
~/Applications/QuotaStatus.app
```

这个版本是 SwiftUI 原生窗口，直接请求 NAS 接口，不依赖浏览器。
