#!/bin/bash
# install-cron.sh — Register the orchestrator as an hourly openclaw cron job
# Requires the gateway to be running

set -euo pipefail

# Fix: OPENCLAW_HOME must not be set
unset OPENCLAW_HOME

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ORCHESTRATOR_SCRIPT="${SCRIPT_DIR}/orchestrator.sh"
GATEWAY_PORT="${OPENCLAW_GATEWAY_PORT:-18790}"

echo "[install-cron] Installing orchestrator cron job..."

# Check gateway is reachable
if ! timeout 5 bash -c "echo > /dev/tcp/127.0.0.1/$GATEWAY_PORT" 2>/dev/null; then
  echo "[install-cron] ERROR: Gateway not reachable on port $GATEWAY_PORT"
  echo "[install-cron] Start the gateway first: openclaw gateway run --force --bind loopback --port $GATEWAY_PORT"
  exit 1
fi

# Remove existing orchestrator cron if any
existing=$(openclaw cron list --json 2>/dev/null | jq -r '.[] | select(.name == "orchestrator") | .id' 2>/dev/null || echo "")
if [ -n "$existing" ]; then
  echo "[install-cron] Removing existing orchestrator cron (id: $existing)..."
  openclaw cron rm "$existing" 2>/dev/null || true
fi

# Register the hourly cron job
openclaw cron add \
  --name "orchestrator" \
  --every 1h \
  --description "Hourly orchestrator: PR review/merge, update checks, session maintenance" \
  --system-event "Run the orchestrator cycle. Execute: bash ${ORCHESTRATOR_SCRIPT}. Tasks: 1) Session maintenance (openclaw sessions cleanup --all-agents --enforce) 2) Check GitHub repos for open PRs — review diffs using Claude Code AI, approve and merge good PRs, request changes on bad ones 3) Check for updates to openclaw (npm), claude-code (npm), kimi-code (npm), openclaw-launcher (git pull) 4) Use openclaw memory search for context when reviewing PRs 5) Log everything to ~/logs/orchestrator-*.log. Report a summary." \
  --model "kimi-coding/k2p5" \
  --session "main" \
  --timeout 120000 \
  2>/dev/null

echo "[install-cron] Orchestrator cron job installed (runs every 1 hour)"
echo "[install-cron] Model: kimi-coding/k2p5 (Kimi K2.5)"
echo "[install-cron] To check status: openclaw cron list"
echo "[install-cron] To run now: openclaw cron run orchestrator"
