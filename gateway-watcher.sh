#!/bin/bash
# gateway-watcher.sh — Self-healing gateway monitor for OpenClawMaster
# Runs as a background loop. Detects: 409 conflicts, crashes, unresponsive gateway.
# Self-heals, then escalates to kimi -c for diagnosis if repeated failures.

# Fix: OPENCLAW_HOME must not be set
unset OPENCLAW_HOME

CHECK_INTERVAL=${CHECK_INTERVAL:-120}
LOG="/home/openclaw/logs/gateway-watcher.log"
MAX_LOG_SIZE=5242880
GATEWAY_PORT=18790
CONSECUTIVE_FAILURES=0
MAX_FAILURES_BEFORE_KIMI=3

log() {
  local ts
  ts=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  echo "[$ts] $1" >> "$LOG"
  echo "[$ts] [gateway-watcher] $1"
}

rotate_log() {
  if [ -f "$LOG" ]; then
    local size
    size=$(stat -c%s "$LOG" 2>/dev/null || echo 0)
    if [ "$size" -gt "$MAX_LOG_SIZE" ]; then
      mv "$LOG" "$LOG.old"
      log "Log rotated"
    fi
  fi
}

check_gateway_alive() {
  pgrep -f "openclaw.*gateway" >/dev/null 2>&1
}

check_gateway_responsive() {
  timeout 10 bash -c "echo > /dev/tcp/127.0.0.1/$GATEWAY_PORT" 2>/dev/null
}

restart_gateway() {
  log "Restarting gateway..."
  pkill -9 -f "openclaw.*gateway" 2>/dev/null || true
  sleep 2

  export PATH=/home/openclaw/.local/bin:/usr/local/bin:/usr/bin:/bin:$PATH
  export HOME=/home/openclaw

  if [ -f /home/openclaw/.env.keys ]; then
    set -a
    source /home/openclaw/.env.keys
    set +a
  fi

  nohup openclaw gateway run --force --bind loopback --port $GATEWAY_PORT \
    >> /home/openclaw/logs/gateway-restart.log 2>&1 &

  sleep 5
  if check_gateway_alive; then
    log "Gateway restarted successfully (PID $(pgrep -f 'openclaw.*gateway' | head -1))"
    return 0
  else
    log "Gateway failed to restart"
    return 1
  fi
}

escalate_to_kimi() {
  log "Escalating to kimi -c for diagnosis (failure #$CONSECUTIVE_FAILURES)..."

  local diag_file="/tmp/gateway-diag-$(date +%s).txt"
  {
    echo "=== OpenClaw Gateway Diagnostic Report ==="
    echo "Timestamp: $(date -u)"
    echo "Consecutive failures: $CONSECUTIVE_FAILURES"
    echo ""
    echo "=== Gateway Process ==="
    ps aux | grep "[o]penclaw.*gateway" || echo "NO GATEWAY PROCESS RUNNING"
    echo ""
    echo "=== Port $GATEWAY_PORT ==="
    ss -tlnp | grep "$GATEWAY_PORT" || echo "Port not listening"
    echo ""
    echo "=== Recent Gateway Logs (last 30 lines) ==="
    tail -30 "/tmp/openclaw/openclaw-$(date -u +%Y-%m-%d).log" 2>/dev/null || echo "No log file"
    echo ""
    echo "=== Watcher Log (last 20 lines) ==="
    tail -20 "$LOG" 2>/dev/null || echo "No watcher log"
    echo ""
    echo "=== Disk Usage ==="
    df -h /home/openclaw
    echo ""
    echo "=== Memory ==="
    free -h 2>/dev/null || echo "N/A"
  } > "$diag_file" 2>&1

  local fix_script="/tmp/gateway-fix-$(date +%s).sh"
  kimi -c "You are the OpenClaw gateway doctor. Read the diagnostic report below and write a bash script to fix the issue. Rules: gateway command is openclaw gateway run --force --bind loopback --port 18790. HOME=/home/openclaw. NEVER use destructive commands. Output ONLY the bash script.

$(cat "$diag_file")" > "$fix_script" 2>/dev/null

  if [ -s "$fix_script" ]; then
    log "Kimi produced fix script: $fix_script"

    if grep -qiE "rm -rf /|mkfs|dd if=/dev|shutdown|reboot|halt|format" "$fix_script"; then
      log "BLOCKED: Fix script contains dangerous commands, skipping"
      rm -f "$fix_script" "$diag_file"
      return 1
    fi

    chmod +x "$fix_script"
    bash "$fix_script" >> "$LOG" 2>&1
    local result=$?
    log "Fix script exit code: $result"

    sleep 5
    if check_gateway_alive && check_gateway_responsive; then
      log "Kimi fix successful — gateway is back up"
    else
      log "Kimi fix did not resolve the issue"
    fi
  else
    log "Kimi produced no output or failed"
  fi

  rm -f "$fix_script" "$diag_file"
}

# === Main Loop ===
log "Gateway watcher started (interval: ${CHECK_INTERVAL}s, kimi escalation after ${MAX_FAILURES_BEFORE_KIMI} failures)"

while true; do
  rotate_log

  if ! check_gateway_alive; then
    log "ALERT: Gateway process is dead!"
    CONSECUTIVE_FAILURES=$((CONSECUTIVE_FAILURES + 1))

    if [ $CONSECUTIVE_FAILURES -ge $MAX_FAILURES_BEFORE_KIMI ]; then
      escalate_to_kimi
      CONSECUTIVE_FAILURES=0
    else
      restart_gateway && CONSECUTIVE_FAILURES=0
    fi
    sleep $CHECK_INTERVAL
    continue
  fi

  if ! check_gateway_responsive; then
    log "ALERT: Gateway not responding on port $GATEWAY_PORT!"
    CONSECUTIVE_FAILURES=$((CONSECUTIVE_FAILURES + 1))

    if [ $CONSECUTIVE_FAILURES -ge $MAX_FAILURES_BEFORE_KIMI ]; then
      escalate_to_kimi
      CONSECUTIVE_FAILURES=0
    else
      restart_gateway && CONSECUTIVE_FAILURES=0
    fi
    sleep $CHECK_INTERVAL
    continue
  fi

  if [ $CONSECUTIVE_FAILURES -gt 0 ]; then
    log "Gateway recovered after $CONSECUTIVE_FAILURES failure(s)"
  fi
  CONSECUTIVE_FAILURES=0

  sleep $CHECK_INTERVAL
done
