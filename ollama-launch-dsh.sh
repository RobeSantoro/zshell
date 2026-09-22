#!/bin/bash
#
# ollama-launch-dsh.sh
#
# Starts `ollama launch dsh` (DeepSeek Harness, web profile) with no visible
# Terminal window. It is meant to be run by the LaunchAgent
# ~/Library/LaunchAgents/com.robe.ollama-launch-dsh.plist at login, but it can
# also be run by hand.
#
# Compared with putting `ollama launch dsh` straight into the plist, this
# wrapper adds three things launchd cannot express:
#   1. a PATH that contains node/dsh (fnm globals) - launchd jobs otherwise get
#      only /usr/bin:/bin:/usr/sbin:/sbin and `ollama launch` would not find dsh;
#   2. a guard that stands down when DSH web is already listening, so a
#      hand-started instance and the login item never fight over the port;
#   3. a short wait for the Ollama server, which is itself a login item and may
#      still be coming up.

set -uo pipefail

log() { printf '%s [ollama-launch-dsh] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"; }

# --- Configuration (override via EnvironmentVariables in the plist) ----------
OLLAMA_BIN="${OLLAMA_BIN:-/usr/local/bin/ollama}"
OLLAMA_API="${OLLAMA_API:-http://127.0.0.1:11434}"
DSH_WEB_PORT="${DSH_WEB_PORT:-3080}"
DSH_WORKDIR="${DSH_WORKDIR:-$HOME}"

# --- PATH -------------------------------------------------------------------
# fnm's "default" alias keeps pointing at a valid Node across upgrades, so try
# it first and fall back to the newest node-versions entry. The fnm
# "multishells" directories are deliberately not used: they belong to one
# interactive shell and disappear with it.
fnm_root="${FNM_DIR:-$HOME/.local/share/fnm}"
node_bin=""
if [[ -x "$fnm_root/aliases/default/bin/dsh" ]]; then
  node_bin="$fnm_root/aliases/default/bin"
else
  for candidate in "$fnm_root"/node-versions/*/installation/bin; do
    if [[ -x "$candidate/dsh" ]]; then
      node_bin="$candidate"
    fi
  done
fi
[[ -n "$node_bin" ]] || log "warning: no dsh executable found under $fnm_root"

export PATH="${node_bin:+$node_bin:}/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

if [[ ! -x "$OLLAMA_BIN" ]]; then
  log "error: $OLLAMA_BIN is missing or not executable"
  exit 1
fi
if ! command -v dsh >/dev/null 2>&1; then
  log "error: dsh is not on PATH; install it with: npm install -g @deepseek-ai/dsh"
  exit 1
fi

# --- Stand down if DSH web is already running --------------------------------
# Exiting 0 keeps KeepAlive (SuccessfulExit=false) from restarting us in a loop.
if /usr/bin/nc -z 127.0.0.1 "$DSH_WEB_PORT" >/dev/null 2>&1; then
  log "DSH web is already listening on 127.0.0.1:$DSH_WEB_PORT; nothing to do"
  exit 0
fi

# --- Wait briefly for the Ollama server --------------------------------------
# Not fatal if it never shows up: DSH boots fine and Ollama is retried per
# request, and KeepAlive restarts us if `ollama launch` itself fails.
for _ in $(seq 1 30); do
  if /usr/bin/curl -fsS -o /dev/null --max-time 2 "$OLLAMA_API/api/version"; then
    break
  fi
  sleep 1
done

# DSH uses the working directory as its workspace.
cd "$DSH_WORKDIR" 2>/dev/null || { log "warning: cannot cd to $DSH_WORKDIR"; cd "$HOME" || exit 1; }

log "starting: $OLLAMA_BIN launch dsh -y (cwd=$PWD)"

# -y answers confirmation prompts, because a launchd job has no terminal to
# prompt on. Remove it if you would rather the job fail than auto-confirm.
exec "$OLLAMA_BIN" launch dsh -y </dev/null
