#!/bin/bash
# On attach: keep AdvantageScope Lite up and print the public HTTPS URL.
# On Codespaces, also register the WPILib VSIX (postCreate runs before `code`
# exists; the Dockerfile already unpacks the extension for local Dev Containers).
set -euo pipefail

# shellcheck source=codespace-urls.sh
source "$(cd "$(dirname "$0")" && pwd)/codespace-urls.sh"
ascope_codespace_urls

bash "$(dirname "$0")/start-advantagescope-lite.sh" || true

# Wait briefly so the clickable URL is live when printed.
for _ in $(seq 1 20); do
  if python3 -c 'import socket; s=socket.socket(); s.settimeout(0.5); raise SystemExit(0 if s.connect_ex(("127.0.0.1", 5808)) == 0 else 1)' 2>/dev/null; then
    break
  fi
  sleep 0.25
done

cat <<EOF

AdvantageScope Lite: ${ASCOPE_LITE_URL}
  Open that link (Ports → 5808, or the URL above).
  With sim running, Lite auto-connects to NT at ${ASCOPE_NT_HOST} over WSS.
  Port 5810 must be public (set below on Codespaces attach).

EOF

if [ "${CODESPACES:-}" != "true" ]; then
  exit 0
fi

# portsAttributes.visibility is ignored by Codespaces; set NT public at runtime
# so the Lite page can reach WSS on *-5810.app.github.dev without auth headers.
echo "Making NetworkTables port 5810 public..."
gh codespace ports visibility 5810:public -c "$CODESPACE_NAME" || \
  echo "Warning: could not set 5810 public; toggle it in the Ports panel."

WPILIB_VSIX_VERSION="2027.0.0-alpha-8"
echo "Installing WPILib VS Code extension ${WPILIB_VSIX_VERSION}..."
wget -q "https://github.com/wpilibsuite/vscode-wpilib/releases/download/v${WPILIB_VSIX_VERSION}/vscode-wpilib-${WPILIB_VSIX_VERSION}.vsix" \
  -O /tmp/vscode-wpilib.vsix
code --install-extension /tmp/vscode-wpilib.vsix --force
rm -f /tmp/vscode-wpilib.vsix
