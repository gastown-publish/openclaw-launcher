# OpenClaw Launcher

A Docker-in-Docker system for launching and managing OpenClaw instances. The master OpenClaw (openclawmaster) orchestrates sub-instances on customer demand.

## Architecture

```
openclawmaster (orchestrator)
  |
  +-- Docker Socket
       |
       +-- Deacon Service (lifecycle manager, API on :8080)
            |
            +-- openclaw-customer-1 (isolated, no host ports, root)
            +-- openclaw-customer-2 (isolated, no host ports, root)
            +-- openclaw-customer-N ...
```

Each sub-instance:
- Runs as **root** (no permission issues)
- Has **no port bindings** to the host (outbound HTTPS only for Telegram polling)
- Uses the **latest OpenClaw version** on launch
- **Auto-upgrades daily** via cron (3 AM UTC)
- Gets its own config volume and data volume
- Has Maton-powered Google Workspace skills pre-installed on first boot

## Quick Start

```bash
# Build the instance image
docker build -t openclaw-launcher/instance:latest docker/openclaw-instance/

# Build the deacon image
docker build -t openclaw-launcher/deacon:latest deacon/

# Start the deacon
docker compose up -d

# Launch a sub-instance via API
curl -X POST http://localhost:8080/instances/launch \
  -H "Content-Type: application/json" \
  -d '{ "name": "customer1", "telegram_bot_token": "123456:ABC..." }'
```

## Deacon API

| Endpoint | Method | Description |
|----------|--------|-------------|
| /health | GET | Deacon health status |
| /instances | GET | List all managed instances |
| /instances/launch | POST | Launch a new instance |
| /instances/stop | POST | Stop an instance |
| /instances/destroy | POST | Remove an instance (keeps volumes) |
| /upgrade | POST | Trigger OpenClaw upgrade across all instances |

### Launch Parameters

- **name** (required): Instance identifier
- **telegram_bot_token** (required): Telegram bot token for this instance
- **env_keys** (optional): Dict of environment variables (KIMI_API_KEY, MATON_API_KEY, etc.)
- **mem_limit** (optional): Memory limit, default "4g"
- **cpu_limit** (optional): CPU limit, default 2.0

## Pre-installed Skills

Each instance auto-installs these Maton-powered skills on first boot:

- api-gateway - Connect to 100+ APIs via gateway.maton.ai
- gmail - Gmail read, send, manage labels
- google-docs - Create and edit Google Docs
- google-sheets - Read and write spreadsheets
- google-drive - File operations
- google-calendar-api - Calendar management
- google-contacts - Contact management
- google-slides - Presentations
- google-meet - Meeting spaces
- google-tasks-api - Task lists
- google-forms - Forms

## Network Isolation

Sub-instances run on an isolated bridge network with:
- No port forwarding to the host
- Outbound internet access (HTTPS for Telegram, Maton, Kimi APIs)
- DNS: 8.8.8.8, 1.1.1.1

## Daily Upgrades

Each instance has a cron job at 3 AM UTC: `npm update -g openclaw@latest`

The deacon also triggers daily upgrades across all instances as a fallback.

## License

MIT License - See LICENSE file for details
