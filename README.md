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

默认标题账户为 `mac-codex`。安装后应用位于：

```text
~/Applications/QuotaStatus.app
```

这个版本是 SwiftUI 原生窗口，直接读取本机 Codex 的 rate limit 数据，不依赖浏览器，也不依赖 NAS 接口。默认会调用：

```text
/Applications/Codex.app/Contents/Resources/codex
```

如果 Codex 安装路径不同，可通过环境变量覆盖：

```bash
TOKEN_USAGE_CODEX_COMMAND=/path/to/codex ./mac-app/install-mac-app.sh mac-codex
```

打分享安装包:

```bash
./mac-app/package-mac-app.sh
```

输出文件：

```text
dist/QuotaStatus-1.0.0.pkg
```

构建时会自动生成深青色液态额度风格的应用图标。安装包会把应用安装到 `/Applications/QuotaStatus.app`。这是未公证的本地分享包，其他 Mac 首次打开时可能需要在系统设置里允许打开。
