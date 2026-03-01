#!/bin/bash
# launch.sh — Main entrypoint for openclaw-launcher
# Starts the gateway, watcher, and installs the hourly orchestrator cron
#
# Usage:
#   ./launch.sh              # Start everything
#   ./launch.sh --no-cron    # Start gateway only, skip cron install
#   ./launch.sh --cron-only  # Only install the cron job (gateway must be running)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="${HOME}/logs"
GATEWAY_PORT="${OPENCLAW_GATEWAY_PORT:-18790}"

mkdir -p "$LOG_DIR"

log() {
  local ts
  ts=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  echo "[$ts] [launcher] $1"
}

# ─── Load environment ─────────────────────────────────────────────────────────

if [ -f "${HOME}/.env.keys" ]; then
  set -a
  # shellcheck disable=SC1091
  source "${HOME}/.env.keys"
  set +a
fi

export PATH="${HOME}/.local/bin:/usr/local/bin:/usr/bin:/bin:$PATH"
export HOME="${HOME:-/home/openclaw}"

# Fix: OPENCLAW_HOME must not be set — CLI auto-resolves to ~/.openclaw
unset OPENCLAW_HOME

# ─── Parse args ───────────────────────────────────────────────────────────────

SKIP_CRON=false
CRON_ONLY=false

for arg in "$@"; do
  case "$arg" in
    --no-cron)    SKIP_CRON=true ;;
    --cron-only)  CRON_ONLY=true ;;
    --help|-h)
      echo "Usage: $0 [--no-cron | --cron-only]"
      echo ""
      echo "Options:"
      echo "  --no-cron     Start gateway and watcher, skip cron install"
      echo "  --cron-only   Only install the orchestrator cron job"
      echo ""
      exit 0
      ;;
  esac
done

# ─── Cron-only mode ───────────────────────────────────────────────────────────

if $CRON_ONLY; then
  log "Installing orchestrator cron only..."
  bash "${SCRIPT_DIR}/orchestrator/install-cron.sh"
  exit $?
fi

# ─── Start Gateway ────────────────────────────────────────────────────────────

start_gateway() {
  # Check if already running
  if timeout 3 bash -c "echo > /dev/tcp/127.0.0.1/$GATEWAY_PORT" 2>/dev/null; then
    log "Gateway already running on port $GATEWAY_PORT"
    return 0
  fi

  log "Starting gateway on port $GATEWAY_PORT..."

  # Kill stale gateway processes
  pkill -f "openclaw.*gateway" 2>/dev/null || true
  sleep 2

  nohup openclaw gateway run --force --bind loopback --port "$GATEWAY_PORT" \
    >> "${LOG_DIR}/gateway.log" 2>&1 &

  # Wait for gateway to be ready
  local retries=0
  while ! timeout 3 bash -c "echo > /dev/tcp/127.0.0.1/$GATEWAY_PORT" 2>/dev/null; do
    retries=$((retries + 1))
    if [ $retries -gt 15 ]; then
      log "ERROR: Gateway failed to start after 30 seconds"
      return 1
    fi
    sleep 2
  done

  log "Gateway started (PID $(pgrep -f 'openclaw.*gateway' | head -1))"
}

# ─── Start Gateway Watcher ────────────────────────────────────────────────────

start_watcher() {
  if pgrep -f "gateway-watcher.sh" >/dev/null 2>&1; then
    log "Gateway watcher already running"
    return 0
  fi

  if [ -f "${SCRIPT_DIR}/gateway-watcher.sh" ]; then
    log "Starting gateway watcher..."
    nohup bash "${SCRIPT_DIR}/gateway-watcher.sh" >> "${LOG_DIR}/gateway-watcher.log" 2>&1 &
    log "Gateway watcher started"
  else
    log "WARNING: gateway-watcher.sh not found, skipping"
  fi
}

# ─── Install Orchestrator Cron ─────────────────────────────────────────────────

install_cron() {
  if $SKIP_CRON; then
    log "Skipping cron install (--no-cron)"
    return 0
  fi

  log "Installing orchestrator cron..."

  # Give the gateway a moment to fully initialize
  sleep 3

  bash "${SCRIPT_DIR}/orchestrator/install-cron.sh" 2>&1 || \
    log "WARNING: Cron install failed (gateway may need more time, retry with: $0 --cron-only)"
}

# ─── Main ─────────────────────────────────────────────────────────────────────

main() {
  echo ""
  echo "╔══════════════════════════════════════════════╗"
  echo "║       OpenClaw Launcher v1.1.0               ║"
  echo "║  Gateway + Watcher + Orchestrator            ║"
  echo "║  Brain: Kimi K2.5 | Executor: Claude Code   ║"
  echo "╚══════════════════════════════════════════════╝"
  echo ""

  start_gateway
  start_watcher
  install_cron

  echo ""
  log "All services started."
  log "  Gateway:      port $GATEWAY_PORT"
  log "  Watcher:      running"
  log "  Orchestrator: cron every 1h"
  log ""
  log "Logs: ${LOG_DIR}/"
  log "Check cron: openclaw cron list"
  log "Run now:    openclaw cron run orchestrator"
  log "Manual run: bash ${SCRIPT_DIR}/orchestrator/orchestrator.sh"
}

main
