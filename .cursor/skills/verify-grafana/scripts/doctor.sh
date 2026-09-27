#!/usr/bin/env bash
# Read-only: is the verification instance worth driving? Exit 0 = yes.
# Checks: our processes alive, port owned by our backend, health + DB ok, build matches
# checkout HEAD, frontend bundle served, admin/admin auth works, webpack not in error.
set -uo pipefail
. "$(dirname "$0")/lib.sh"

fail=0
ok() { printf '  ok    %s\n' "$*"; }
bad() { printf '  FAIL  %s\n' "$*"; fail=1; }
warn() { printf '  warn  %s\n' "$*"; }

if [ ! -f "$VERIFY_RUN_DIR/state.env" ]; then
  echo "no instance: $VERIFY_RUN_DIR/state.env missing (run launch.sh)"; exit 1
fi
. "$VERIFY_RUN_DIR/state.env"
VERIFY_URL="http://localhost:$VERIFY_PORT"
echo "verify-grafana doctor: $VERIFY_URL (run dir $VERIFY_RUN_DIR)"

kill -0 "$BACKEND_PANE_PID" 2>/dev/null && ok "backend session alive (pid $BACKEND_PANE_PID)" || bad "backend session gone"
if [ -n "$FRONTEND_PANE_PID" ]; then
  kill -0 "$FRONTEND_PANE_PID" 2>/dev/null && ok "frontend watcher alive (pid $FRONTEND_PANE_PID)" || bad "frontend watcher gone"
  # webpackbar logs "Compiling Grafana" at the start of each (re)build and "Grafana: Compiled ..." at the end.
  last=$(grep -E 'Grafana: Compil|Compiling Grafana' "$VERIFY_RUN_DIR/frontend.log" 2>/dev/null | tail -1)
  case "$last" in
    *rror*) bad "webpack last compile has errors: $last" ;;
    *"Compiling Grafana"*) bad "webpack rebuild in progress; re-run doctor when it finishes" ;;
    "") bad "webpack has not finished a compile yet" ;;
    *) ok "webpack: ${last#*] }" ;;
  esac
else
  warn "frontend watcher not running (--backend-only): UI reflects the existing public/build"
fi

listener=$(port_listener_pid "$VERIFY_PORT")
if [ -z "$listener" ]; then
  bad "nothing listening on :$VERIFY_PORT"
else
  # Ours if the listener descends from the backend tmux pane.
  p=$listener; owned=0
  while [ -n "$p" ] && [ "$p" -gt 1 ]; do
    [ "$p" = "$BACKEND_PANE_PID" ] && { owned=1; break; }
    p=$(ps -o ppid= -p "$p" 2>/dev/null | tr -d ' ')
  done
  [ "$owned" = 1 ] && ok "port $VERIFY_PORT owned by our backend (pid $listener, $(ps -o comm= -p "$listener"))" \
    || bad "port $VERIFY_PORT held by pid $listener, not a child of our backend session"
fi

health=$(curl -fsS "$VERIFY_URL/api/health" 2>/dev/null)
if [ -n "$health" ]; then
  echo "$health" | grep -q '"database": *"ok"' && ok "/api/health database ok" || bad "/api/health: $health"
  commit=$(echo "$health" | sed -n 's/.*"commit": *"\([^"]*\)".*/\1/p')
  head=$(git -C "$REPO_ROOT" rev-parse HEAD)
  if [ -n "$commit" ] && [[ "$head" == "$commit"* || "$commit" == "$GIT_HEAD"* ]]; then
    ok "build commit $commit matches checkout HEAD"
  else
    warn "build commit '$commit' vs HEAD ${head:0:11}; uncommitted edits are still hot-reloaded by air"
  fi
else
  bad "/api/health not answering"
fi

user=$(curl -fsS -u admin:admin "$VERIFY_URL/api/user" 2>/dev/null)
echo "$user" | grep -q '"login": *"admin"' && ok "admin/admin basic auth works" || bad "admin/admin auth failed: ${user:-no response}"

html=$(curl -fsS "$VERIFY_URL/login" 2>/dev/null)
asset=$(echo "$html" | grep -oE 'public/build/[^"]+\.js' | head -1)
if [ -n "$asset" ] && curl -fsS -o /dev/null "$VERIFY_URL/$asset"; then
  ok "frontend bundle served ($asset)"
else
  bad "frontend bundle missing from /login (is public/build populated?)"
fi

ds=$(curl -fsS -u admin:admin "$VERIFY_URL/api/datasources/uid/PD8C576611E62080A" 2>/dev/null)
echo "$ds" | grep -q gdev-testdata && ok "provisioned datasource gdev-testdata present" || warn "gdev-testdata datasource missing"

[ "$fail" = 0 ] && echo "HEALTHY" || echo "UNHEALTHY (see $VERIFY_RUN_DIR/backend.log / frontend.log)"
exit "$fail"
