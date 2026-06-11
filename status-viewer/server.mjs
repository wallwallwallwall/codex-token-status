import fs from "node:fs/promises";
import http from "node:http";
import path from "node:path";
import { fileURLToPath } from "node:url";

const rootDir = path.dirname(fileURLToPath(import.meta.url));
const port = Number(process.env.PORT || 53141);
const apiBase = process.env.TOKEN_USAGE_READ_API || "https://api.wals.top";

const mimeTypes = {
  ".html": "text/html; charset=utf-8",
  ".js": "application/javascript; charset=utf-8",
  ".css": "text/css; charset=utf-8",
};

const server = http.createServer(async (request, response) => {
  try {
    const url = new URL(request.url || "/", `http://${request.headers.host || "localhost"}`);

    if (request.method === "GET" && url.pathname === "/api/token-usage/status") {
      await proxyStatus(url, response);
      return;
    }

    if (request.method === "GET" && (url.pathname === "/" || url.pathname === "/index.html")) {
      await sendFile("clean.html", response);
      return;
    }

    response.writeHead(404, { "content-type": "application/json; charset=utf-8" });
    response.end(JSON.stringify({ error: "not_found" }));
  } catch (error) {
    response.writeHead(500, { "content-type": "application/json; charset=utf-8" });
    response.end(JSON.stringify({ error: "server_error", message: error.message }));
  }
});

async function proxyStatus(url, response) {
  const accountId = String(url.searchParams.get("accountId") || "").trim();
  if (!accountId) {
    response.writeHead(400, { "content-type": "application/json; charset=utf-8" });
    response.end(JSON.stringify({ error: "missing_account_id" }));
    return;
  }

  const upstream = new URL("/api/token-usage/status", apiBase);
  upstream.searchParams.set("accountId", accountId);
  const upstreamResponse = await fetch(upstream, {
    headers: {
      accept: "application/json",
    },
  });
  const body = await upstreamResponse.text();

  response.writeHead(upstreamResponse.status, {
    "cache-control": "no-store",
    "content-type": "application/json; charset=utf-8",
  });
  response.end(body);
}

async function sendFile(fileName, response) {
  const filePath = path.join(rootDir, fileName);
  const content = await fs.readFile(filePath);
  response.writeHead(200, {
    "cache-control": "no-store",
    "content-type": mimeTypes[path.extname(fileName)] || "application/octet-stream",
  });
  response.end(content);
}

server.listen(port, "127.0.0.1", () => {
  console.log(JSON.stringify({
    ok: true,
    url: `http://localhost:${port}/?accountId=mac-codex`,
    apiBase,
  }));
});
