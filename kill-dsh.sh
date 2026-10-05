#!/bin/bash
# kill-dsh.sh
# Stops the DSH LaunchAgent and any running DSH processes.

set -euo pipefail

LABEL="com.robe.ollama-launch-dsh"
DOMAIN="gui/$(id -u)"
DSH_PORT=3080

log() { printf '%s [kill-dsh] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"; }

log "Attempting to stop DSH LaunchAgent..."
# Try to bootout the service
# Use a subshell to prevent set -e from exiting on failure
(launchctl bootout "$DOMAIN/$LABEL" 2>/dev/null || true)
(launchctl bootout "$DOMAIN" "$HOME/Library/LaunchAgents/$LABEL.plist" 2>/dev/null || true)

log "Checking for DSH processes on port $DSH_PORT..."
# lsof returns non-zero if no processes found, so we handle it
PID=$(lsof -t -i :$DSH_PORT || true)

if [ -n "$PID" ]; then
  for p in $PID; do
    log "Killing process $p..."
    kill "$p" 2>/dev/null || true
  done
  
  # Wait and check if they are still running
  sleep 2
  STILL_RUNNING=$(lsof -t -i :$DSH_PORT || true)
  if [ -n "$STILL_RUNNING" ]; then
    log "Processes still running, force killing..."
    for p in $STILL_RUNNING; do
      log "Force killing process $p..."
      kill -9 "$p" 2>/dev/null || true
    done
  fi
  log "DSH processes stopped."
else
  log "No DSH processes found on port $DSH_PORT."
fi

log "Done."
