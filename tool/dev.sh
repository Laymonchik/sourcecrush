#!/usr/bin/env bash
# Dev loop helper: keeps `flutter run` alive in the background, driven through
# a FIFO so hot reload/restart work without a foreground terminal.
#
#   tool/dev.sh start     build, install and attach (full rebuild)
#   tool/dev.sh restart   hot restart (Dart-only changes)
#   tool/dev.sh reload    hot reload
#   tool/dev.sh quit      stop the session
#   tool/dev.sh logs      tail the run log
#   tool/dev.sh shot NAME screenshot the device into /tmp/opencode/shots
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FIFO=/tmp/opencode/flutter-stdin
LOG=/tmp/opencode/run.log
PIDFILE=/tmp/opencode/flutter.pid
DEVICE="${SC_DEVICE:-7fdd67c5}"

# shellcheck disable=SC1091
source "$HOME/.sc-env.sh"

# NOTE: the bracket in the pattern keeps pgrep from matching this script itself.
_stop_existing() {
  pkill -f 'flutter_tool[s]' 2>/dev/null
  pkill -f "opencode/flutter-stdin" 2>/dev/null
  sleep 3
}

# Writing to the FIFO blocks forever if no session is attached to read it, so
# always write with a timeout and report instead of hanging.
_send() {
  if ! pgrep -f 'flutter_tool[s]' >/dev/null; then
    echo "no flutter run session - use '$0 start'"
    return 1
  fi
  if printf '%s\n' "$1" > "$FIFO" 2>/dev/null; then
    echo "sent '$1' to the running session"
  else
    echo "could not reach $FIFO"
    return 1
  fi
}

case "${1:-start}" in
  start)
    _stop_existing
    source "$HOME/.sc-env.sh"
    rm -f "$FIFO"
    mkfifo "$FIFO"
    cd "$ROOT"
    nohup bash -c "source \$HOME/.sc-env.sh; cd '$ROOT'; tail -f '$FIFO' | flutter run -d '$DEVICE' > '$LOG' 2>&1" >/dev/null 2>&1 &
    echo "started: tail -f $LOG   (echo r > $FIFO to hot reload)"
    ;;
  restart) _send R ;;
  reload)  _send r ;;
  quit)    _send q; _stop_existing; echo "stopped" ;;
  logs)    tail -n "${2:-40}" "$LOG" ;;
  shot)
    mkdir -p /tmp/opencode/shots
    name="${2:-shot}"
    adb -s "$DEVICE" exec-out screencap -p > "/tmp/opencode/shots/$name.png"
    echo "/tmp/opencode/shots/$name.png"
    ;;
  *) echo "usage: $0 {start|restart|reload|quit|logs|shot NAME}"; exit 1 ;;
esac
