#!/bin/bash
# Desktop preview on macOS: clickable desktop refuses Docker Desktop, so run the app in the
# same build image on a virtual X display and view it over VNC (localhost only).
# Env: GU=<px per grid unit, default 10>  SCREEN=<virtual screen, default 1440x900>  DARK=1  SKIP_BUILD=1
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
INSTALL="$ROOT/build/aarch64-linux-gnu/app/install"
HOMEDIR="$HOME/.clickable/home"
IMAGE=serey-desktop-vnc:3
GU="${GU:-10}"
SCREEN="${SCREEN:-1440x900}"
PORT=5901

if ! docker image inspect "$IMAGE" >/dev/null 2>&1; then
  printf 'FROM clickable/arm64-ut24.04-1.x-arm64:latest\nRUN apt-get update && apt-get install -y --no-install-recommends x11vnc openbox pulseaudio && rm -rf /var/lib/apt/lists/*\n' \
    | docker build -t "$IMAGE" -
fi

[ "${SKIP_BUILD:-0}" = 1 ] || (cd "$ROOT" && clickable build --arch arm64 --skip-review)

mkdir -p "$HOMEDIR/.config/lomiri-ui-toolkit"
THEME=Ambiance; [ "${DARK:-0}" = 1 ] && THEME=SuruDark
printf '[General]\ntheme=Lomiri.Components.Themes.%s\n' "$THEME" > "$HOMEDIR/.config/lomiri-ui-toolkit/theme.ini"

LIBS="$INSTALL/lib/aarch64-linux-gnu:$INSTALL/lib"
docker rm -f serey-desktop >/dev/null 2>&1 || true
( sleep 5; open "vnc://:serey@127.0.0.1:$PORT" ) &

if [ -t 0 ]; then
  MODE=-it
else
  MODE=-d
  echo "Running in the background. Logs: docker logs -f serey-desktop  Stop: docker rm -f serey-desktop"
fi

# Without a bigger /dev/shm the web view renderer aborts at larger GU values.
# PulseAudio gives GStreamer a silent sink; with no audio device at all, media playback fails.
exec docker run --rm $MODE --name serey-desktop --shm-size=512m \
  -p "127.0.0.1:$PORT:5900" \
  -v "$ROOT:$ROOT" -v "$HOMEDIR:/home/phablet" -w "$INSTALL" \
  -e HOME=/home/phablet -e DISPLAY=:1 -e GRID_UNIT_PX="$GU" \
  -e APP_DIR="$INSTALL" -e APP_ID=serey.serey-io \
  -e QML2_IMPORT_PATH="$LIBS" -e LD_LIBRARY_PATH="$LIBS" \
  -e TEXTDOMAINDIR="$INSTALL/share/locale" -e UITK_ICON_THEME=suru \
  -e CLICKABLE_DESKTOP_MODE=1 -e LIBGL_ALWAYS_SOFTWARE=1 \
  -e QTWEBENGINE_DISABLE_SANDBOX=1 -e QTWEBENGINE_CHROMIUM_FLAGS="--disable-gpu" \
  -e XDG_RUNTIME_DIR=/tmp/xdg \
  -e LANG=C.UTF-8 -e TZ="$(readlink /etc/localtime | sed 's#.*/zoneinfo/##')" \
  "$IMAGE" bash -c "
    mkdir -p /tmp/xdg && chmod 700 /tmp/xdg
    pulseaudio --start --exit-idle-time=-1 2>/dev/null
    Xvfb :1 -screen 0 ${SCREEN}x24 -nolisten tcp &
    sleep 1
    openbox &
    x11vnc -display :1 -forever -shared -passwd serey -quiet -bg -o /tmp/x11vnc.log
    qmlscene qml/Main.qml"
