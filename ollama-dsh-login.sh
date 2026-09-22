#!/bin/bash
#
# ollama-dsh-login.sh
#
# Manages the silent login item that runs `ollama launch dsh` at login on
# macOS. "Silent" means a LaunchAgent: it runs as you in the background with no
# Terminal window and no Dock icon.
#
#   ./ollama-dsh-login.sh install     # install and load (default)
#   ./ollama-dsh-login.sh uninstall   # stop and remove
#   ./ollama-dsh-login.sh status      # show loaded state, port, log
#   ./ollama-dsh-login.sh restart     # stop then start now
#   ./ollama-dsh-login.sh open        # authenticate a browser window
#
# The agent shows up in System Settings > General > Login Items & Extensions
# under "Allow in the Background" as com.robe.ollama-launch-dsh.

set -uo pipefail

LABEL="com.robe.ollama-launch-dsh"
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WRAPPER="$REPO_DIR/ollama-launch-dsh.sh"
SRC_PLIST="$REPO_DIR/$LABEL.plist"
AGENT_DIR="$HOME/Library/LaunchAgents"
DST_PLIST="$AGENT_DIR/$LABEL.plist"
LOG_FILE="$HOME/Library/Logs/ollama-launch-dsh.log"
DOMAIN="gui/$(id -u)"

# Keep these in step with the wrapper's defaults.
DSH_WEB_HOST="${DSH_WEB_HOST:-127.0.0.1}"
DSH_WEB_PORT="${DSH_WEB_PORT:-3080}"
# Name of the Chrome App shortcut to hand the authenticated URL to.
DSH_APP_NAME="${DSH_APP_NAME:-DeepSeek Harness}"

die() { printf 'error: %s\n' "$*" >&2; exit 1; }
info() { printf '%s\n' "$*"; }

usage() {
  cat <<'USAGE'
Usage: ollama-dsh-login.sh [command]

Manages the silent login item (LaunchAgent) that runs `ollama launch dsh` at
login, with no Terminal window.

Commands:
  install      Install the LaunchAgent and load it (default)
  uninstall    Unload the LaunchAgent and remove its plist
  status       Show launchd state, DSH web port, and the last log lines
  restart      Unload and load the LaunchAgent again
  open         Open the current authenticated URL in the Chrome App, for when
               the GUI answers "dsh web authentication required"
  -h, --help   Show this help
USAGE
}

check_environment() {
  [ "$(uname -s)" = Darwin ] || die "this installer targets macOS"
  for dependency in cp launchctl plutil nc open; do
    command -v "$dependency" >/dev/null 2>&1 \
      || die "required command not found: $dependency"
  done
}

require_sources() {
  [ -f "$SRC_PLIST" ] || die "missing $SRC_PLIST"
  [ -f "$WRAPPER" ] || die "missing $WRAPPER"
}

stop_agent() {
  # Failures are ignored: the agent may simply not be loaded yet.
  launchctl bootout "$DOMAIN/$LABEL" 2>/dev/null
  launchctl bootout "$DOMAIN" "$DST_PLIST" 2>/dev/null
  return 0
}

# The authenticated URL appears in the log as the `dsh web:` readiness line.
latest_url() {
  local pattern
  pattern="http://${DSH_WEB_HOST//./\\.}:${DSH_WEB_PORT}/\\?token=[A-Za-z0-9_-]+"
  grep -oE "$pattern" "$LOG_FILE" 2>/dev/null | tail -1
}

# Print the Chrome App shortcut for DSH, if one is installed.
find_dsh_app() {
  local candidate
  for candidate in "$HOME/Applications/Chrome Apps.localized/$DSH_APP_NAME.app" \
                   "/Applications/Chrome Apps.localized/$DSH_APP_NAME.app"; do
    if [ -d "$candidate" ]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done
  return 1
}

cmd_install() {
  check_environment
  require_sources
  mkdir -p "$AGENT_DIR" "$(dirname "$LOG_FILE")" || die "cannot create $AGENT_DIR"
  chmod +x "$WRAPPER" || die "cannot make $WRAPPER executable"

  # Replace any previous copy, then load the new one.
  stop_agent
  cp "$SRC_PLIST" "$DST_PLIST" || die "cannot write $DST_PLIST"
  plutil -lint "$DST_PLIST" >/dev/null || die "invalid plist: $DST_PLIST"

  launchctl bootstrap "$DOMAIN" "$DST_PLIST" \
    || die "launchctl bootstrap failed for $DST_PLIST"
  launchctl enable "$DOMAIN/$LABEL" 2>/dev/null

  info "Installed $LABEL"
  info "  plist:   $DST_PLIST"
  info "  wrapper: $WRAPPER"
  info "  log:     $LOG_FILE"
  info ""
  info "It starts at every login. To confirm it is loaded right now:"
  info "  $0 status"
}

cmd_uninstall() {
  check_environment
  stop_agent
  if [ -f "$DST_PLIST" ]; then
    rm -f "$DST_PLIST" || die "cannot remove $DST_PLIST"
    info "Removed $DST_PLIST"
  else
    info "Nothing to remove: $DST_PLIST does not exist"
  fi
}

cmd_status() {
  check_environment
  info "== launchctl =="
  launchctl print "$DOMAIN/$LABEL" 2>&1 | grep -E \
    '^[[:space:]]*(state|pid|last exit code|program|path) =' || info "not loaded"
  info ""
  info "== DSH web port $DSH_WEB_PORT =="
  if nc -z "$DSH_WEB_HOST" "$DSH_WEB_PORT" >/dev/null 2>&1; then
    info "listening (http://$DSH_WEB_HOST:$DSH_WEB_PORT)"
  else
    info "not listening"
  fi
  info ""
  info "== last lines of $LOG_FILE =="
  if [ -f "$LOG_FILE" ]; then
    tail -n 15 "$LOG_FILE"
  else
    info "no log yet"
  fi
}

cmd_restart() {
  check_environment
  [ -f "$DST_PLIST" ] || die "not installed; run: $0 install"
  stop_agent
  launchctl bootstrap "$DOMAIN" "$DST_PLIST" || die "launchctl bootstrap failed"
  info "Restarted $LABEL"
}

# Hand the current per-process authenticated URL to a browser. The cookie it
# grants lasts 30 days, so this is only needed after the cookie expires, after
# cookies are cleared, or when an open window kept its old connection state.
cmd_open() {
  check_environment
  nc -z "$DSH_WEB_HOST" "$DSH_WEB_PORT" >/dev/null 2>&1 \
    || die "nothing is listening on $DSH_WEB_HOST:$DSH_WEB_PORT; start it with: $0 restart"

  local url app
  url="$(latest_url)"
  [ -n "$url" ] || die "no authenticated URL in $LOG_FILE; restart DSH web with: $0 restart"

  info "Authenticated URL:"
  info "  $url"

  app="$(find_dsh_app)"
  if [ -n "$app" ]; then
    info "  opening in: $app"
    if ! open -a "$app" "$url"; then
      info "  the app refused the URL; trying the default browser"
      open "$url" || die "could not open $url"
    fi
  else
    info "  no Chrome App shortcut found; opening in the default browser"
    open "$url" || die "could not open $url"
  fi

  info ""
  info "If the window still asks for authentication, quit it and run this again."
}

case "${1:-install}" in
  install)    cmd_install ;;
  uninstall)  cmd_uninstall ;;
  status)     cmd_status ;;
  restart)    cmd_restart ;;
  open)       cmd_open ;;
  -h|--help)  usage ;;
  *)          usage >&2; die "unknown command: $1" ;;
esac
