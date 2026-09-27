#!/usr/bin/env bash
# Start Grafana for verification: backend (`make run`) + frontend watcher (`yarn start`),
# each in its own tmux session, with an isolated SQLite data dir under $VERIFY_RUN_DIR.
#
# Usage: launch.sh [--backend-only]
#   --backend-only  skip `yarn start`; only valid when public/build is already current.
# Env:   VERIFY_PORT (default 3000), VERIFY_RUN_DIR (default /tmp/verify-grafana)
set -euo pipefail
. "$(dirname "$0")/lib.sh"

FRONTEND=1
[ "${1:-}" = "--backend-only" ] && FRONTEND=0

for s in "$TMUX_BACKEND" "$TMUX_FRONTEND"; do
  if tmux_cmd has-session -t "=$s" 2>/dev/null; then
    log "tmux session $s already exists: an instance is running. Run doctor.sh, or cleanup.sh first."
    exit 1
  fi
done
if [ -n "$(port_listener_pid "$VERIFY_PORT")" ]; then
  log "port $VERIFY_PORT is already in use by pid $(port_listener_pid "$VERIFY_PORT") (not ours). Pick another VERIFY_PORT."
  exit 1
fi
if [ -f "$VERIFY_RUN_DIR/state.env" ]; then
  log "stale $VERIFY_RUN_DIR/state.env found; run cleanup.sh first."
  exit 1
fi

mkdir -p "$VERIFY_RUN_DIR"/{data,logs,plugins} "$VERIFY_RUN_DIR"/provisioning/{datasources,dashboards,plugins,alerting,access-control}
# Same provisioned datasources/dashboards as the e2e harness (gdev-testdata, "gdev dashboards" folder).
cp "$REPO_ROOT/devenv/datasources.yaml" "$VERIFY_RUN_DIR/provisioning/datasources/"
cp "$REPO_ROOT/devenv/dashboards.yaml" "$VERIFY_RUN_DIR/provisioning/dashboards/"

GF_ENV="GF_SERVER_HTTP_PORT=$VERIFY_PORT GF_PATHS_DATA=$VERIFY_RUN_DIR/data GF_PATHS_LOGS=$VERIFY_RUN_DIR/logs \
GF_PATHS_PROVISIONING=$VERIFY_RUN_DIR/provisioning GF_PATHS_PLUGINS=$VERIFY_RUN_DIR/plugins GF_ANALYTICS_REPORTING_ENABLED=false \
GF_ANALYTICS_CHECK_FOR_UPDATES=false GF_ANALYTICS_CHECK_FOR_PLUGIN_UPDATES=false GF_NEWS_NEWS_FEED_ENABLED=false"

log "starting backend: make run (port $VERIFY_PORT, log $VERIFY_RUN_DIR/backend.log)"
tmux_cmd new-session -d -s "$TMUX_BACKEND" -c "$REPO_ROOT" \
  "env PATH='$PATH' $GF_ENV bash -c 'make run 2>&1 | tee $VERIFY_RUN_DIR/backend.log'"
BACKEND_PANE_PID=$(tmux_cmd display-message -p -t "$TMUX_BACKEND" '#{pane_pid}')

FRONTEND_PANE_PID=
if [ "$FRONTEND" = 1 ]; then
  log "starting frontend: yarn start (log $VERIFY_RUN_DIR/frontend.log)"
  tmux_cmd new-session -d -s "$TMUX_FRONTEND" -c "$REPO_ROOT" \
    "env PATH='$PATH' bash -c 'yarn start 2>&1 | tee $VERIFY_RUN_DIR/frontend.log'"
  FRONTEND_PANE_PID=$(tmux_cmd display-message -p -t "$TMUX_FRONTEND" '#{pane_pid}')
fi

cat >"$VERIFY_RUN_DIR/state.env" <<EOF
VERIFY_PORT=$VERIFY_PORT
BACKEND_PANE_PID=$BACKEND_PANE_PID
FRONTEND_PANE_PID=$FRONTEND_PANE_PID
GIT_HEAD=$(git -C "$REPO_ROOT" rev-parse --short HEAD)
STARTED_AT=$(date -u +%Y-%m-%dT%H:%M:%SZ)
EOF

start=$(date +%s)
if [ "$FRONTEND" = 1 ]; then
  # `yarn start` runs through nx, which first builds workspace packages that print their own
  # "webpack ... compiled" lines; only webpackbar's "Grafana: Compiled" marks the app bundle.
  log "waiting for the Grafana bundle compile (~90s cold, ~15s with webpack cache)..."
  until grep -q 'Grafana: Compiled' "$VERIFY_RUN_DIR/frontend.log" 2>/dev/null; do
    if ! kill -0 "$FRONTEND_PANE_PID" 2>/dev/null; then log "frontend exited; see $VERIFY_RUN_DIR/frontend.log"; exit 1; fi
    [ $(( $(date +%s) - start )) -gt 900 ] && { log "frontend not ready after 15 min"; exit 1; }
    sleep 5
  done
  grep 'Grafana: Compiled' "$VERIFY_RUN_DIR/frontend.log" | tail -1 >&2
  log "frontend compiled after $(( $(date +%s) - start ))s"
fi

log "waiting for backend /api/health (first build ~3-6 min with debug symbols)..."
until curl -fsS "$VERIFY_URL/api/health" >/dev/null 2>&1; do
  if ! kill -0 "$BACKEND_PANE_PID" 2>/dev/null; then log "backend exited; see $VERIFY_RUN_DIR/backend.log"; exit 1; fi
  [ $(( $(date +%s) - start )) -gt 1500 ] && { log "backend not ready after 25 min"; exit 1; }
  sleep 5
done
echo "LISTENER_PID=$(port_listener_pid "$VERIFY_PORT")" >>"$VERIFY_RUN_DIR/state.env"
log "backend healthy after $(( $(date +%s) - start ))s at $VERIFY_URL (admin/admin)"
log "next: $(dirname "$0")/doctor.sh"
