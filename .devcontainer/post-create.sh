#!/bin/bash
# Runtime (create): JDK settings, Codespace NT host patch, warm Gradle, start Lite.
# Tool downloads live in install-tools.sh (image build).
set -euo pipefail

WPILIB_YEAR="2027_alpha8"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# shellcheck source=codespace-urls.sh
source "${SCRIPT_DIR}/codespace-urls.sh"
ascope_codespace_urls

if [ -n "${XDG_DATA_HOME:-}" ] && [[ "$XDG_DATA_HOME" == /* ]]; then
  WPILIB_HOME="${XDG_DATA_HOME}/wpilib/${WPILIB_YEAR}"
else
  WPILIB_HOME="${HOME}/.local/share/wpilib/${WPILIB_YEAR}"
fi
ASCOPE_LITE_DIR="${WPILIB_HOME}/advantagescope-lite"

if [ -n "${JAVA_HOME:-}" ] && [ -d "$JAVA_HOME" ]; then
  WPILIB_JDK="$JAVA_HOME"
else
  WPILIB_JDK="$(readlink -f "$(command -v java)" | sed 's|/bin/java$||')"
fi

merge_java_settings() {
  local settings_path="$1"
  mkdir -p "$(dirname "$settings_path")"
  python3 - "$settings_path" "$WPILIB_JDK" <<'PY'
import json, os, sys
path, jdk = sys.argv[1], sys.argv[2]
settings = {}
if os.path.exists(path):
    with open(path, encoding="utf-8") as f:
        try:
            settings = json.load(f)
        except json.JSONDecodeError:
            settings = {}
settings["java.jdt.ls.java.home"] = jdk
settings["java.configuration.runtimes"] = [
    {"name": "JavaSE-25", "path": jdk, "default": True}
]
with open(path, "w", encoding="utf-8") as f:
    json.dump(settings, f, indent=2)
    f.write("\n")
PY
}

# Keep container JDK paths out of the repo's .vscode/settings.json.
merge_java_settings "${HOME}/.vscode-server/data/User/settings.json"
if [ -d "${HOME}/.vscode-remote/data/User" ] || [ "${CODESPACES:-}" = "true" ]; then
  merge_java_settings "${HOME}/.vscode-remote/data/User/settings.json"
fi

rm -rf "${HOME}/.vscode-server/data/User/workspaceStorage/"*/redhat.java
rm -rf "${HOME}/.vscode-remote/data/User/workspaceStorage/"*/redhat.java

# Point Lite's default preferences.robotAddress at this environment's NT host.
if [ -d "$ASCOPE_LITE_DIR" ]; then
  echo "AdvantageScope Lite default NT host: ${ASCOPE_NT_HOST}"
  python3 - "$ASCOPE_LITE_DIR" "$ASCOPE_NT_HOST" <<'PY'
import pathlib, sys
root, host = pathlib.Path(sys.argv[1]), sys.argv[2]
old = "robot.local"
for path in root.rglob("*"):
    if not path.is_file() or path.suffix.lower() in {
        ".png", ".glb", ".wasm", ".jpg", ".jpeg", ".ico", ".woff", ".woff2"
    }:
        continue
    try:
        data = path.read_text(encoding="utf-8")
    except (UnicodeDecodeError, OSError):
        continue
    if old not in data:
        continue
    path.write_text(data.replace(old, host), encoding="utf-8")
    print(f"  patched {path.relative_to(root)}")
PY
fi

bash "${SCRIPT_DIR}/start-advantagescope-lite.sh" || true

if [ -f gradlew ]; then
  chmod +x gradlew
  echo "Warming Gradle cache (first run downloads WPILib + vendor JARs)..."
  ./gradlew compileJava --no-daemon
fi

cat <<EOF

Unofficial WPILib Dev Container is ready.

  Desktop:          open forwarded port 6080 (password: vscode)
  AdvantageScope:   ${ASCOPE_LITE_URL}
                    (Codespaces forward URL; 5808 can stay private for you)
                    With sim running, Lite auto-connects to NT (${ASCOPE_NT_HOST})
                    Port 5810 is made public on attach (required for browser WSS)
  Build:            ./gradlew compileJava
  Sim:              ./gradlew run
                    or Command Palette → WPILib: Simulate Robot Code

The sim GUI appears on the noVNC desktop. AdvantageScope Lite talks to sim NT over
WSS via the public 5810 Codespaces forward.

EOF
