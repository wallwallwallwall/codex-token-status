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
