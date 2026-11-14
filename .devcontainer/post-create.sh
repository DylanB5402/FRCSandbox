#!/bin/bash
# Fake a 2027 WPILib installer layout, download desktop tools, and warm Gradle
# so IntelliSense works on a cold Codespace.
set -euo pipefail

WPILIB_YEAR="2027_alpha8"
WPILIB_VER="2027.0.0-alpha-8"
FRCMAVEN="https://frcmaven.wpi.edu/artifactory/release/org/wpilib/tools"
# WSS Lite for Codespaces: https/wss on public *-5810 forward (:443 at edge).
ADVANTAGESCOPE_REPO="DylanB5402/AdvantageScope"
ADVANTAGESCOPE_VER="codespace-wss-2"
ELASTIC_VER="2027.0.0-alpha10"

# shellcheck source=codespace-urls.sh
source "$(cd "$(dirname "$0")" && pwd)/codespace-urls.sh"
ascope_codespace_urls

if [ -n "${XDG_DATA_HOME:-}" ] && [[ "$XDG_DATA_HOME" == /* ]]; then
  WPILIB_HOME="${XDG_DATA_HOME}/wpilib/${WPILIB_YEAR}"
else
  WPILIB_HOME="${HOME}/.local/share/wpilib/${WPILIB_YEAR}"
fi
TOOLS_DIR="${WPILIB_HOME}/tools"

if [ -n "${JAVA_HOME:-}" ] && [ -d "$JAVA_HOME" ]; then
  WPILIB_JDK="$JAVA_HOME"
else
  WPILIB_JDK="$(readlink -f "$(command -v java)" | sed 's|/bin/java$||')"
fi
echo "WPILib home: ${WPILIB_HOME}"
echo "Using JDK at: ${WPILIB_JDK}"

mkdir -p "${WPILIB_HOME}/maven" "$TOOLS_DIR"
ln -sfn "$WPILIB_JDK" "${WPILIB_HOME}/jdk"

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

install_native_tool() {
  local artifact="$1"
  local zip_bin="$2"
  echo "Installing ${artifact}..."
  wget -q "${FRCMAVEN}/${artifact}/${WPILIB_VER}/${artifact}-${WPILIB_VER}-linuxx86-64.zip" \
    -O "/tmp/${artifact}.zip"
  unzip -p "/tmp/${artifact}.zip" "linux/x86-64/${zip_bin}" > "${TOOLS_DIR}/${artifact}"
  chmod +x "${TOOLS_DIR}/${artifact}"
  local lower
  lower="$(printf '%s' "$artifact" | tr '[:upper:]' '[:lower:]')"
  if [ "$lower" != "$artifact" ]; then
    ln -sfn "$artifact" "${TOOLS_DIR}/${lower}"
  fi
  rm -f "/tmp/${artifact}.zip"
}

# GradleRIO looks up PascalCase names; vscode-wpilib on Linux uses lowercased tools.json names.
install_native_tool "OutlineViewer" "outlineviewer"
install_native_tool "Glass" "glass"
install_native_tool "SysId" "sysid"
install_native_tool "DataLogTool" "datalogtool"
install_native_tool "wpical" "wpical"

echo "Installing Elastic..."
mkdir -p "${WPILIB_HOME}/elastic"
wget -q "https://github.com/Gold872/elastic_dashboard/releases/download/v${ELASTIC_VER}/Elastic-WPILib-Linux.zip" \
  -O /tmp/elastic.zip
unzip -qo /tmp/elastic.zip -d "${WPILIB_HOME}/elastic"
chmod +x "${WPILIB_HOME}/elastic/elastic_dashboard"
cat > "${TOOLS_DIR}/Elastic" <<LAUNCHER
#!/bin/bash
cd "${WPILIB_HOME}/elastic"
exec ./elastic_dashboard "\$@"
LAUNCHER
chmod +x "${TOOLS_DIR}/Elastic"
ln -sfn Elastic "${TOOLS_DIR}/elastic"
rm -f /tmp/elastic.zip

# AdvantageScope Lite: extract the Systemcore IPK (ar + data.tar.gz). Do not run
# postinst/systemd — those assume User=systemcore. Serve with a local venv.
echo "Installing AdvantageScope Lite..."
ASCOPE_LITE_DIR="${WPILIB_HOME}/advantagescope-lite"
ASCOPE_LITE_STAGE="/tmp/ascope-lite-ipk"
rm -rf "$ASCOPE_LITE_DIR" "$ASCOPE_LITE_STAGE"
mkdir -p "$ASCOPE_LITE_DIR" "$ASCOPE_LITE_STAGE"
wget -q "https://github.com/${ADVANTAGESCOPE_REPO}/releases/download/${ADVANTAGESCOPE_VER}/advantagescope-lite-${ADVANTAGESCOPE_VER}.ipk" \
  -O "${ASCOPE_LITE_STAGE}/lite.ipk"
(
  cd "$ASCOPE_LITE_STAGE"
  ar x lite.ipk
  tar -xzf data.tar.gz
)
cp -a "${ASCOPE_LITE_STAGE}/usr/local/bin/advantagescope-lite/." "$ASCOPE_LITE_DIR/"
chmod +x "${ASCOPE_LITE_DIR}/lite_server.py"
python3 -m venv "${ASCOPE_LITE_DIR}/.venv"
"${ASCOPE_LITE_DIR}/.venv/bin/pip" install --quiet --disable-pip-version-check "multipart==1.3.0"

# Current WSS Lite auto-connects via preferences.robotAddress (default robot.local).
# Point that default at the public Codespaces NT host so open → WSS works.
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

START_LITE_SCRIPT="$(cd "$(dirname "$0")" && pwd)/start-advantagescope-lite.sh"
cat > "${TOOLS_DIR}/AdvantageScope" <<LAUNCHER
#!/bin/bash
# WPILib tool entry: ensure Lite is listening, then print the Codespaces HTTPS URL.
bash "${START_LITE_SCRIPT}"
echo "AdvantageScope Lite: ${ASCOPE_LITE_URL}"
echo "With sim running, Lite auto-connects to NT at ${ASCOPE_NT_HOST} (WSS :443)."
LAUNCHER
chmod +x "${TOOLS_DIR}/AdvantageScope"
ln -sfn AdvantageScope "${TOOLS_DIR}/advantagescope"
rm -rf "$ASCOPE_LITE_STAGE"

cat > "${TOOLS_DIR}/tools.json" <<EOF
[
  {"name": "OutlineViewer", "version": "${WPILIB_VER}"},
  {"name": "Glass", "version": "${WPILIB_VER}"},
  {"name": "SysId", "version": "${WPILIB_VER}"},
  {"name": "DataLogTool", "version": "${WPILIB_VER}"},
  {"name": "wpical", "version": "${WPILIB_VER}"},
  {"name": "AdvantageScope", "version": "${ADVANTAGESCOPE_VER}"},
  {"name": "Elastic", "version": "${ELASTIC_VER}"}
]
EOF

PATH_LINE="export PATH=\"${TOOLS_DIR}:\$PATH\""
for rc in "${HOME}/.bashrc" "${HOME}/.zshrc"; do
  if [ -f "$rc" ] && grep -Fq "$TOOLS_DIR" "$rc"; then
    continue
  fi
  printf '\n# WPILib 2027 tools\n%s\n' "$PATH_LINE" >> "$rc"
done

bash "$(dirname "$0")/start-advantagescope-lite.sh" || true

if [ -f gradlew ]; then
  chmod +x gradlew
  echo "Warming Gradle cache (first run downloads WPILib + vendor JARs)..."
  ./gradlew compileJava --no-daemon
fi

cat <<EOF

WPILib 2027 sim container is ready.

  Desktop:          open forwarded port 6080 (password: vscode)
  AdvantageScope:   ${ASCOPE_LITE_URL}
                    (public HTTPS forward; ports 5808 + 5810 must stay public)
                    With sim running, Lite auto-connects to NT (${ASCOPE_NT_HOST})
  Build:            ./gradlew compileJava
  Sim:              ./gradlew run
                    or Command Palette → WPILib: Simulate Robot Code

The sim GUI appears on the noVNC desktop. AdvantageScope Lite opens over HTTPS and
talks to sim NT over WSS via the public 5810 forward.

EOF
