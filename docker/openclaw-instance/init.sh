#!/bin/bash
set -e

export HOME=/home/openclaw

echo "Initializing OpenClaw instance..."

# Kill any stale gateway
pkill -9 -f "openclaw-gateway" 2>/dev/null || true
sleep 1

# Source API keys if available
if [ -f /home/openclaw/.env.keys ]; then
  set -a; source /home/openclaw/.env.keys; set +a
fi

# Create minimal config if missing
if [ ! -f /home/openclaw/.openclaw/openclaw.json ]; then
  echo "[+] Creating minimal OpenClaw config..."
  mkdir -p /home/openclaw/.openclaw
  cat > /home/openclaw/.openclaw/openclaw.json << 'OCCONFIG'
{
  "gateway": {
    "port": 18790,
    "mode": "local",
    "bind": "lan",
    "controlUi": {
      "dangerouslyAllowHostHeaderOriginFallback": true
    }
  },
  "agents": {
    "defaults": {
      "model": {
        "primary": "kimi-coding/k2p5"
      },
      "workspace": "/home/openclaw/.openclaw/workspace"
    }
  },
  "plugins": {
    "entries": {
      "telegram": { "enabled": true }
    }
  }
}
OCCONFIG
fi

# Install kimi-cli if missing
if ! command -v kimi >/dev/null 2>&1; then
  echo "[+] Installing kimi-cli..."
  uv tool install kimi-cli 2>/dev/null || true
  KIMI_BIN=$(find /root/.local -name "kimi" -type f 2>/dev/null | head -1)
  if [ -n "$KIMI_BIN" ]; then
    echo "#!/bin/bash" > /usr/local/bin/kimi
    echo "exec $KIMI_BIN \"\$@\"" >> /usr/local/bin/kimi
    chmod +x /usr/local/bin/kimi
  fi
fi

# Start SSH if available
if [ -x /usr/sbin/sshd ]; then
  mkdir -p /run/sshd
  /usr/sbin/sshd 2>/dev/null || true
fi

# Start cron
if command -v cron >/dev/null 2>&1; then
  cron 2>/dev/null || true
fi

# Set up daily upgrade cron (3 AM UTC)
echo "0 3 * * * npm update -g openclaw@latest >> /home/openclaw/logs/upgrade.log 2>&1" | crontab -

# Install Maton-powered skills on first boot
if [ ! -f /home/openclaw/.openclaw/workspace/skills/.installed ]; then
  echo "[+] Installing Maton-powered skills from ClawHub..."
  SKILLS="api-gateway gmail google-docs google-sheets google-drive google-calendar-api google-contacts google-slides google-meet google-tasks-api google-forms"
  for skill in $SKILLS; do
    echo "  Installing $skill..."
    clawhub install "$skill" --dir /home/openclaw/.openclaw/workspace/skills/ --no-input --force 2>/dev/null || true
  done
  touch /home/openclaw/.openclaw/workspace/skills/.installed
fi

echo "Init complete. Starting gateway..."

export PATH=/home/openclaw/.local/bin:/usr/local/bin:/usr/bin:/bin:$PATH

exec node "$(which openclaw | head -1)" gateway run --force --bind lan --port 18790
