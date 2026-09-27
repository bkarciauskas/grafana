#!/usr/bin/env bash
# Tear down only what launch.sh started (tmux sessions + recorded pids) and delete scratch
# state in $VERIFY_RUN_DIR. Never touches $VERIFY_EVIDENCE_ROOT.
set -uo pipefail
. "$(dirname "$0")/lib.sh"

descendants() {
  local kids
  kids=$(ps -o pid= --ppid "$1" 2>/dev/null)
  for k in $kids; do echo "$k"; descendants "$k"; done
}

if [ -f "$VERIFY_RUN_DIR/state.env" ]; then
  . "$VERIFY_RUN_DIR/state.env"
  # air runs grafana-air in its own session, so a process-group kill misses it: collect the
  # whole tree under our tmux panes first, plus the listener pid recorded at launch.
  pids=""
  for pane in ${BACKEND_PANE_PID:-} ${FRONTEND_PANE_PID:-}; do
    kill -0 "$pane" 2>/dev/null && pids="$pids $pane $(descendants "$pane" | tr '\n' ' ')"
  done
  [ -n "${LISTENER_PID:-}" ] && kill -0 "$LISTENER_PID" 2>/dev/null && pids="$pids $LISTENER_PID"
  if [ -n "${pids// /}" ]; then
    log "stopping pids:$pids"
    kill -TERM $pids 2>/dev/null
    for _ in $(seq 1 15); do
      alive=""; for p in $pids; do kill -0 "$p" 2>/dev/null && alive="$alive $p"; done
      [ -z "$alive" ] && break; sleep 1
    done
    [ -n "$alive" ] && { log "force-killing:$alive"; kill -KILL $alive 2>/dev/null; }
  fi
fi
for s in "$TMUX_BACKEND" "$TMUX_FRONTEND"; do
  tmux_cmd has-session -t "=$s" 2>/dev/null && { log "killing tmux session $s"; tmux_cmd kill-session -t "=$s"; }
done

rm -rf "$VERIFY_RUN_DIR"
log "scratch state removed ($VERIFY_RUN_DIR). Evidence kept in $VERIFY_EVIDENCE_ROOT"
[ -n "$(port_listener_pid "${VERIFY_PORT:-3000}")" ] && log "WARNING: port ${VERIFY_PORT:-3000} still in use by pid $(port_listener_pid "${VERIFY_PORT:-3000}")"
exit 0
