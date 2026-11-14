#!/bin/bash
# Resolve AdvantageScope Lite / NT URLs for Codespaces HTTPS forwards.
# Lite UI:  https://<name>-5808.<domain> (can stay private; owner-auth is enough)
# NT (WSS): host <name>-5810.<domain> on :443 (edge) → container :5810
#           must be public so the Lite page can connect without auth headers
ascope_codespace_urls() {
  if [ "${CODESPACES:-}" = "true" ] && [ -n "${CODESPACE_NAME:-}" ]; then
    local domain="${GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN:-app.github.dev}"
    ASCOPE_LITE_URL="https://${CODESPACE_NAME}-5808.${domain}"
    ASCOPE_NT_HOST="${CODESPACE_NAME}-5810.${domain}"
  else
    ASCOPE_LITE_URL="http://localhost:5808"
    ASCOPE_NT_HOST="127.0.0.1"
  fi
}
