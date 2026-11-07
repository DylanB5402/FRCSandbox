#!/bin/bash
# Start AdvantageScope Lite detached from the caller.
# setsid so Dev Container lifecycle scripts cannot reap it with their process group.
set -euo pipefail

WPILIB_YEAR="2027_alpha8"
if [ -n "${XDG_DATA_HOME:-}" ] && [[ "$XDG_DATA_HOME" == /* ]]; then
  WPILIB_HOME="${XDG_DATA_HOME}/wpilib/${WPILIB_YEAR}"
else
  WPILIB_HOME="${HOME}/.local/share/wpilib/${WPILIB_YEAR}"
fi
ASCOPE_LITE_DIR="${WPILIB_HOME}/advantagescope-lite"
PYTHON="${ASCOPE_LITE_DIR}/.venv/bin/python3"
LOG="/tmp/advantagescope-lite.log"

if [ ! -x "$PYTHON" ] || [ ! -f "${ASCOPE_LITE_DIR}/lite_server.py" ]; then
  echo "AdvantageScope Lite is not installed at ${ASCOPE_LITE_DIR}; skipping."
  exit 0
fi

if pgrep -f "${ASCOPE_LITE_DIR}/lite_server.py" >/dev/null; then
  echo "AdvantageScope Lite is already running."
  exit 0
fi

# Port already bound (e.g. stale listener without matching cmdline).
if python3 -c 'import socket; s=socket.socket(); s.settimeout(0.5); raise SystemExit(0 if s.connect_ex(("127.0.0.1", 5808)) == 0 else 1)' 2>/dev/null; then
  echo "AdvantageScope Lite port 5808 is already in use."
  exit 0
fi

cd "$ASCOPE_LITE_DIR"
setsid "$PYTHON" lite_server.py >"$LOG" 2>&1 </dev/null &
echo "AdvantageScope Lite started on http://localhost:5808 (log: ${LOG})."
