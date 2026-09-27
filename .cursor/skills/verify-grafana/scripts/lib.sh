# shellcheck shell=bash
# Shared settings for the verify-grafana helpers. Source it; don't execute it.

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
SKILL_DIR="$REPO_ROOT/.cursor/skills/verify-grafana"

VERIFY_PORT="${VERIFY_PORT:-3000}"
VERIFY_URL="http://localhost:${VERIFY_PORT}"
# Scratch state: deleted by cleanup.sh.
VERIFY_RUN_DIR="${VERIFY_RUN_DIR:-/tmp/verify-grafana}"
# Proof artifacts: never touched by cleanup.sh.
VERIFY_EVIDENCE_ROOT="${VERIFY_EVIDENCE_ROOT:-$HOME/verify-grafana-evidence}"

TMUX_BACKEND=verify-grafana-backend
TMUX_FRONTEND=verify-grafana-frontend

NODE_BIN="$HOME/.nvm/versions/node/$(cat "$REPO_ROOT/.nvmrc")/bin"
if [ -d "$NODE_BIN" ]; then
  # Some VMs ship an older node earlier on PATH (e.g. /exec-daemon/node); force the .nvmrc one.
  export PATH="$NODE_BIN:$PATH"
fi

tmux_cmd() {
  if [ -f /exec-daemon/tmux.portal.conf ]; then
    tmux -f /exec-daemon/tmux.portal.conf "$@"
  else
    tmux "$@"
  fi
}

port_listener_pid() {
  if command -v lsof >/dev/null; then
    lsof -nP -t -iTCP:"$1" -sTCP:LISTEN 2>/dev/null | head -1
  else
    ss -ltnpH "sport = :$1" 2>/dev/null | sed -n 's/.*pid=\([0-9]*\).*/\1/p' | head -1
  fi
}

log() { printf '[verify-grafana] %s\n' "$*" >&2; }
