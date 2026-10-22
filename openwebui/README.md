# openwebui

Open WebUI chat front-end

Backends (both OpenAI-compatible):
- LM Studio on work mac
- llama.cpp `llama-server` on lintendo

## Configuration

`credentials.env`
- `WEBUI_SECRET_KEY`: signs login sessions. Generate with `openssl rand -hex 32`.
- `OPENAI_API_KEYS`: one key per backend URL, `;`-separated, in the same order as `OPENAI_API_BASE_URLS` (LM Studio first). llama-server doesn't check keys, but still needs a placeholder like `none`.

## Deploy

    kubectl apply -k .

The first account to sign up becomes admin. Do that straight away, because the UI is reachable from the whole LAN.

## Storage

Everything (SQLite DB with users/chats/settings, uploads, RAG vectors) is on the `openwebui-data` PVC. Hopefully semi-disposable.

## Non-obvious things

**`ENABLE_PERSISTENT_CONFIG=false`, so the manifests win.** By default Open WebUI copies settings like `OPENAI_API_BASE_URLS` into its DB on first start and ignores the env vars after that. With this off, env vars are re-read on every start, and admin-UI changes to those settings are lost on restart. Change backends and keys here, not in the UI.

**`WEBUI_SECRET_KEY` is set explicitly.** If it's unset, the image generates one outside the data dir, so every pod restart would log everyone out.
