# OpenClaw Launcher

A containerized deployment system for OpenClaw with pre-installed plugins, model providers, and tiered resource management.

## Overview

OpenClaw Launcher provides Docker-based deployment for OpenClaw instances with:

- **Pre-installed Model Providers**: Kimi, Toad, Claude Code, Codex, and Gemini
- **Google Workspace Integration**: Full suite of Google tools via ClawHub plugins
- **Tiered Architecture**: Normal and Privileged user tiers with different resource limits
- **Telegram STT Workaround**: Fixes known bug with voice message transcription
- **Deacon Service**: Automated plugin updates, health monitoring, and backups

## Quick Start

```bash
# Clone the repository
git clone https://github.com/gastown-publish/openclaw-launcher.git
cd openclaw-launcher

# Create Docker secrets
echo "your-kimi-api-key" | docker secret create kimi_key -
echo "your-telegram-bot-token" | docker secret create telegram_bot_token -
# ... create other secrets as needed

# Deploy using Make (recommended)
make up                    # Deploy all services
make up-normal            # Deploy Normal tier only
make up-privileged        # Deploy Privileged tier only

# Or use docker-compose directly
docker-compose --profile normal up -d
docker-compose --profile privileged up -d
docker-compose --profile all up -d
```

### Using Make

A Makefile is provided for common operations:

```bash
make help              # Show all available commands
make build             # Build all Docker images
make secrets           # Interactively create Docker secrets
make logs              # View logs from all services
make shell-normal      # Open shell in Normal tier container
make test              # Run validation tests
make clean             # Clean up containers and volumes
```

## Architecture

### Tier System

| Resource | Normal Users | Privileged Users |
|----------|-------------|------------------|
| **Base Image** | Python 3.11 | Python 3.13 |
| **CPU Limit** | 4 cores | 8 cores |
| **Memory Limit** | 16GB | 128GB |
| **Memory Reservation** | 4GB | None |
| **Disk** | 50GB | 100GB |
| **Pre-installed Skills** | Basic 20 skills | Full ClawHub library |
| **Speech-to-Text** | Deepgram (EN only) | Whisper API + Local |
| **Model Access** | Kimi, Toad, Codex | All + Claude + Gemini |

### Pre-installed Plugins

#### Model Providers (All Tiers)
- `kimi-provider` - Kimi AI integration
- `toad-provider` - Toad AI integration
- `codex-provider` - OpenAI Codex integration

#### Privileged-Only Model Providers
- `claude-code-provider` - Anthropic Claude Code
- `gemini-provider` - Google Gemini

#### Google Workspace Plugins

| Plugin | Function | Tier | Maton.ai Compatible |
|--------|----------|------|-------------------|
| `gog` | Google Workspace core | Both | Yes |
| `gogcli` | CLI interface | Both | Yes |
| `gcal-tool` | Calendar management | Both | Yes |
| `gdrive-tool` | Drive file operations | Both | Yes |
| `gtasks-tool` | Tasks management | Normal | Yes |
| `gcontacts-tool` | Contact management | Normal | Yes |
| `gmail-tool` | Gmail automation | Privileged | Yes |
| `gdocs-tool` | Google Docs editing | Privileged | Yes |
| `gsheets-tool` | Spreadsheet automation | Privileged | Yes |
| `gsearch-tool` | Custom Search API | Privileged | Yes |

## Configuration

### Environment Setup

Copy the example environment file and customize it:

```bash
cp .env.example .env
# Edit .env with your API keys and configuration
```

### Using Docker Compose Override

For local customization, create a `docker-compose.override.yml`:

```bash
cp docker-compose.override.yml.example docker-compose.override.yml
# Edit to add custom volumes, ports, or environment variables
```

### Environment Variables

#### Model Provider Keys
| Variable | Description | Required |
|----------|-------------|----------|
| `KIMI_API_KEY` | Kimi API key | Yes |
| `TOAD_API_KEY` | Toad API key | Yes |
| `CODEX_API_KEY` | OpenAI Codex key | Yes |
| `CLAUDE_CODE_KEY` | Anthropic Claude key | Privileged only |
| `GEMINI_API_KEY` | Google Gemini key | Privileged only |

#### Telegram Configuration
| Variable | Description | Default |
|----------|-------------|---------|
| `TELEGRAM_BOT_TOKEN` | Telegram bot token | - |
| `FORCE_MEDIA_UNDERSTANDING` | Enable STT workaround | `true` |
| `WHISPER_MODEL` | Whisper model size | `base` (normal), `large-v3` (privileged) |
| `TRANSCRIPTION_PROVIDER` | STT provider | `deepgram` (normal), `whisper-api` (privileged) |

#### Plugin Settings
| Variable | Description | Default |
|----------|-------------|---------|
| `PLUGINS_AUTO_UPDATE` | Auto-update plugins daily | `true` |
| `CLAWHUB_AUTO_SYNC` | Sync with ClawHub registry | `true` |
| `PLUGIN_UPDATE_INTERVAL` | Update check interval (seconds) | `86400` |

### Docker Secrets

Create secrets before deployment:

```bash
# Required secrets
echo "your-key" | docker secret create kimi_key -
echo "your-key" | docker secret create toad_key -
echo "your-key" | docker secret create codex_key -

# Privileged tier secrets
echo "your-key" | docker secret create claude_key -
echo "your-key" | docker secret create gemini_key -

# Integration secrets
echo "your-oauth-json" | docker secret create google_oauth -
echo "your-token" | docker secret create telegram_bot_token -
echo "your-key" | docker secret create deepgram_key -
```

## Telegram Speech-to-Text Workaround

### Known Issue

OpenClaw has a bug where the `applyMediaUnderstanding` function is never called during Telegram message processing, preventing automatic transcription of voice messages.

### Workaround Implementation

The launcher applies a patch that:
1. Intercepts Telegram message handlers
2. Detects voice/audio messages
3. Forces transcription using configured provider
4. Injects transcription results back into message processing

### Configuration

```yaml
environment:
  - FORCE_MEDIA_UNDERSTANDING=true
  - WHISPER_MODEL=base  # or large-v3 for privileged
  - TRANSCRIPTION_PROVIDER=deepgram  # or whisper-api, local
```

### Supported STT Providers

| Provider | Tier | Languages | Notes |
|----------|------|-----------|-------|
| Deepgram | Normal | English only | Cloud API, fast |
| Whisper API | Privileged | Multilingual | Uses OpenAI/Kimi API |
| Local Whisper | Privileged | Multilingual | Offline, requires more resources |

## Deacon Service

The Deacon is a daemon service that manages:

### Plugin Updates
- Daily updates via `clawhub update --all`
- Automatic rollback on failure
- Update notifications via webhook

### Health Monitoring
- Container health checks every 5 minutes
- Telegram STT failure detection
- Resource usage monitoring

### Backup Management
- Hourly backups of custom skills
- 7-day retention policy
- Persistent storage sync

### API Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/health` | GET | Service health status |
| `/status` | GET | Full system status |
| `/metrics` | GET | Prometheus metrics |
| `/update-plugins` | POST | Trigger plugin update |
| `/backup` | POST | Trigger backup |

### Prometheus Metrics

- `deacon_plugin_updates_total` - Plugin update count
- `deacon_health_checks_total` - Health check count
- `deacon_backups_total` - Backup count
- `deacon_active_containers` - Active container gauge
- `deacon_telegram_stt_errors_total` - STT error count

## Development

### Building Images

```bash
# Build base image
docker build -t openclaw-launcher/base:latest docker/openclaw-base/

# Build privileged image
docker build -t openclaw-launcher/privileged:latest docker/openclaw-privileged/

# Build deacon image
docker build -t openclaw-launcher/deacon:latest deacon/
```

### Testing

```bash
# Run tests
docker-compose -f docker-compose.test.yml up

# Check logs
docker-compose logs -f openclaw-normal
```

### Adding Custom Skills

1. Create skill directory in `skills/`
2. Add `skill.yaml` with configuration
3. Rebuild image or mount as volume

Example skill.yaml:
```yaml
name: my-custom-skill
description: My custom skill
tier: both  # or normal, privileged
providers:
  - provider-name
actions:
  - name: my_action
    description: Do something
    command: echo "Hello World"
```

## Troubleshooting

### Telegram STT Not Working

1. Check workaround is applied:
   ```bash
   docker exec openclaw-normal cat /opt/openclaw/scripts/telegram-stt-workaround.sh
   ```

2. Verify environment variables:
   ```bash
   docker exec openclaw-normal env | grep -E '(FORCE_MEDIA|WHISPER|TRANSCRIPTION)'
   ```

3. Check logs for errors:
   ```bash
   docker-compose logs openclaw-normal | grep -i stt
   ```

### Plugin Update Failures

1. Check Deacon logs:
   ```bash
   docker-compose logs deacon | grep -i "plugin update"
   ```

2. Manual update:
   ```bash
   docker exec openclaw-normal clawhub update --all
   ```

### Container Won't Start

1. Check secrets exist:
   ```bash
   docker secret ls
   ```

2. Verify configuration:
   ```bash
   docker-compose config
   ```

3. Check logs:
   ```bash
   docker-compose logs openclaw-normal
   ```

## Orchestrator (Hourly Cron)

The orchestrator is a Kimi K2.5-driven agent that runs every hour via `openclaw cron`. It dispatches tasks to Claude Code AIs.

### What It Does

| Task | Description |
|------|-------------|
| **PR Review & Merge** | Scans GitHub repos for open PRs, reviews diffs using Claude Code AI, approves/merges or requests changes |
| **Update Checks** | Checks for new versions of openclaw, claude-code, kimi-code, and the launcher repo |
| **Session Maintenance** | Runs `openclaw sessions cleanup --all-agents --enforce` and reindexes memory |
| **Memory-Aware Review** | Uses `openclaw memory search` to provide context when reviewing PRs |

### Quick Start

```bash
# Start everything (gateway + watcher + orchestrator cron)
./launch.sh

# Or install just the cron job (gateway must be running)
./launch.sh --cron-only

# Manual run
bash orchestrator/orchestrator.sh

# Check cron status
openclaw cron list
```

### Architecture

```
openclaw cron (every 1h)
  └─> Kimi K2.5 (kimi-coding/k2p5) — brain/orchestrator
       └─> Claude Code AIs — executor
            ├─> Review PR diffs
            ├─> Run tests
            ├─> Approve & merge
            └─> Check for updates
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

## License

MIT License - See LICENSE file for details

## Support

- Issues: https://github.com/gastown-publish/openclaw-launcher/issues
- Discussions: https://github.com/gastown-publish/openclaw-launcher/discussions

## Acknowledgments

- OpenClaw team for the core platform
- ClawHub for plugin registry
- Maton.ai for Google Workspace integrations
