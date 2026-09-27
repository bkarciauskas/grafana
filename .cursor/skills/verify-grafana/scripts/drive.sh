#!/usr/bin/env bash
# Drive the launched instance with Playwright and write evidence to a new run folder.
#
# Usage: drive.sh <spec-file-or-grep> [extra playwright args...]
#   drive.sh explore-query-and-split            # a spec in .cursor/skills/verify-grafana/specs/
#   drive.sh dashboard-create-save --headed     # extra args go to `playwright test`
#   VERIFY_SPEC_DIR=e2e-playwright/various-suite drive.sh explore.spec.ts   # reuse a repo e2e spec
# Prints the evidence directory on the last line.
set -euo pipefail
. "$(dirname "$0")/lib.sh"

[ $# -ge 1 ] || { sed -n '2,9p' "$0"; exit 2; }
spec="$1"; shift

[ -f "$VERIFY_RUN_DIR/state.env" ] || { log "no instance; run launch.sh first"; exit 1; }
. "$VERIFY_RUN_DIR/state.env"

name=$(basename "$spec" .ts); name=${name%.spec}
export VERIFY_EVIDENCE_DIR="$VERIFY_EVIDENCE_ROOT/$(date -u +%Y%m%dT%H%M%SZ)-$name"
mkdir -p "$VERIFY_EVIDENCE_DIR/screenshots"
export GRAFANA_URL="http://localhost:$VERIFY_PORT"
[ -n "${VERIFY_SPEC_DIR:-}" ] && export VERIFY_SPEC_DIR="$(cd "$REPO_ROOT" && realpath "$VERIFY_SPEC_DIR")"

{
  echo "spec: $spec"
  echo "url: $GRAFANA_URL"
  echo "git_head: $(git -C "$REPO_ROOT" rev-parse HEAD)"
  echo "git_dirty_files: $(git -C "$REPO_ROOT" status --porcelain | wc -l)"
  echo "health: $(curl -fsS "$GRAFANA_URL/api/health" | tr -d '\n ')"
  echo "started_at: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
} >"$VERIFY_EVIDENCE_DIR/run-info.txt"

cd "$REPO_ROOT"
set +e
NODE_OPTIONS='-C @grafana-app/source' yarn playwright test \
  -c .cursor/skills/verify-grafana/playwright.verify.config.ts "$spec" "$@" 2>&1 | tee "$VERIFY_EVIDENCE_DIR/playwright.log"
status=${PIPESTATUS[0]}
set -e
echo "exit_code: $status" >>"$VERIFY_EVIDENCE_DIR/run-info.txt"
log "playwright exit $status; videos/traces: test-results/, step screenshots: screenshots/"
echo "$VERIFY_EVIDENCE_DIR"
exit "$status"
