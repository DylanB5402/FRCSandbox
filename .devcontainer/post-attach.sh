#!/bin/bash
# On attach: keep AdvantageScope Lite up and print a clickable URL (opens in the
# integrated browser when workbench.browser.openLocalhostLinks is enabled).
# On Codespaces, also register the WPILib VSIX (postCreate runs before `code`
# exists; the Dockerfile already unpacks the extension for local Dev Containers).
set -euo pipefail

bash "$(dirname "$0")/start-advantagescope-lite.sh" || true

# Wait briefly so the clickable URL is live when printed.
for _ in $(seq 1 20); do
  if python3 -c 'import socket; s=socket.socket(); s.settimeout(0.5); raise SystemExit(0 if s.connect_ex(("127.0.0.1", 5808)) == 0 else 1)' 2>/dev/null; then
    break
  fi
  sleep 0.25
done

cat <<EOF

AdvantageScope Lite: http://localhost:5808
  Open that link (or Run and Debug → "AdvantageScope Lite").
  With sim running: File → Connect to Simulator (NT on localhost:5810).
  Integrated browser uses remote proxy — 3D renders on your machine.

EOF

if [ "${CODESPACES:-}" != "true" ]; then
  exit 0
fi

WPILIB_VSIX_VERSION="2027.0.0-alpha-8"
echo "Installing WPILib VS Code extension ${WPILIB_VSIX_VERSION}..."
wget -q "https://github.com/wpilibsuite/vscode-wpilib/releases/download/v${WPILIB_VSIX_VERSION}/vscode-wpilib-${WPILIB_VSIX_VERSION}.vsix" \
  -O /tmp/vscode-wpilib.vsix
code --install-extension /tmp/vscode-wpilib.vsix --force
rm -f /tmp/vscode-wpilib.vsix
