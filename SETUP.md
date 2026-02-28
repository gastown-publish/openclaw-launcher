# OpenClaw Launcher - Setup Guide

This guide will help you set up the OpenClaw Launcher project and push it to GitHub.

## Prerequisites

- Git installed
- Docker and Docker Compose installed
- GitHub account with access to `gastown-publish/openclaw-launcher`
- GitHub CLI (optional, for PR creation)

## Quick Setup

### 1. Clone the Repository (if starting fresh)

```bash
git clone git@github.com:gastown-publish/openclaw-launcher.git
cd openclaw-launcher
```

### 2. Configure Git

```bash
git config user.email "your@email.com"
git config user.name "Your Name"
```

### 3. Run Setup Script

```bash
chmod +x setup-git.sh
./setup-git.sh
```

This will:
- Initialize the git repository
- Add all files
- Create an initial commit
- Push to GitHub

### 4. Create a Pull Request

#### Option A: Using GitHub CLI

```bash
# Install gh if not already installed
# https://cli.github.com/

# Authenticate
gh auth login

# Create PR
gh pr create \
  --title "Initial Release: OpenClaw Launcher v1.0.0" \
  --body "## OpenClaw Launcher - First Version

This PR introduces the initial version of OpenClaw Launcher with the following features:

### Features

- **Tiered Architecture**: Normal (4CPU/16GB) and Privileged (8CPU/128GB) tiers
- **Pre-installed Model Providers**: Kimi, Toad, Claude Code, Codex, Gemini
- **Google Workspace Integration**: Full suite via ClawHub plugins
- **Telegram STT Workaround**: Fixes known voice transcription bug
- **Deacon Service**: Automated plugin updates, monitoring, and backups

### Components

- Docker configurations for both tiers
- Docker Compose orchestration
- Entrypoint scripts with workarounds
- Pre-installed skills
- CI/CD workflows
- Comprehensive documentation

### Testing

- [ ] Build base image
- [ ] Build privileged image
- [ ] Build deacon image
- [ ] Test docker-compose configuration
- [ ] Verify Telegram STT workaround

### Documentation

See README.md for full documentation." \
  --base main \
  --head $(git branch --show-current)
```

#### Option B: Using GitHub Web Interface

1. Go to https://github.com/gastown-publish/openclaw-launcher
2. Click "Compare & pull request"
3. Fill in the PR title and description
4. Click "Create pull request"

## Manual Setup (Alternative)

If the setup script doesn't work:

```bash
# Initialize git
git init
git branch -m main

# Add remote
git remote add origin git@github.com:gastown-publish/openclaw-launcher.git

# Add files
git add .

# Commit
git commit -m "Initial commit: OpenClaw Launcher v1.0.0"

# Push
git push -u origin main
```

## GitHub Token Setup

If you're using HTTPS instead of SSH:

```bash
# Use your personal access token
# First, set your token as an environment variable:
# export GITHUB_TOKEN=ghp_your_token_here
#
# Then configure the remote:
git remote add origin https://${GITHUB_TOKEN}@github.com/gastown-publish/openclaw-launcher.git
```

**Note**: The token provided should be treated as sensitive. Do not commit it to the repository.

## Post-Setup Steps

### 1. Set Up Docker Secrets

```bash
# Create secrets
echo "your-kimi-api-key" | docker secret create kimi_key -
echo "your-toad-api-key" | docker secret create toad_key -
echo "your-codex-api-key" | docker secret create codex_key -
echo "your-claude-key" | docker secret create claude_key -
echo "your-gemini-key" | docker secret create gemini_key -
echo "your-google-oauth" | docker secret create google_oauth -
echo "your-telegram-token" | docker secret create telegram_bot_token -
echo "your-deepgram-key" | docker secret create deepgram_key -
```

### 2. Deploy

```bash
# Deploy all services
docker-compose --profile all up -d

# Or deploy individually
docker-compose --profile normal up -d
docker-compose --profile privileged up -d
docker-compose --profile deacon up -d
```

### 3. Verify Deployment

```bash
# Check containers
docker-compose ps

# Check logs
docker-compose logs -f

# Check Deacon API
curl http://localhost:8080/health
```

## Troubleshooting

### Git Push Fails

```bash
# Check remote
 git remote -v

# Update remote to use SSH
git remote set-url origin git@github.com:gastown-publish/openclaw-launcher.git

# Or use HTTPS with token
git remote set-url origin https://YOUR_TOKEN@github.com/gastown-publish/openclaw-launcher.git
```

### Permission Denied

Make sure you have write access to the repository:
1. Check repository settings on GitHub
2. Verify your SSH key is added: `cat ~/.ssh/id_rsa.pub`
3. Or use a personal access token with `repo` scope

## Project Structure

```
openclaw-launcher/
├── docker/
│   ├── openclaw-base/          # Normal tier Dockerfile
│   └── openclaw-privileged/    # Privileged tier Dockerfile
├── deacon/                      # Deacon service
├── skills/                      # Pre-installed skills
├── docker-compose.yml           # Orchestration
├── README.md                    # Main documentation
├── SETUP.md                     # This file
└── .github/workflows/           # CI/CD
```

## Support

For issues or questions:
- Open an issue: https://github.com/gastown-publish/openclaw-launcher/issues
- Start a discussion: https://github.com/gastown-publish/openclaw-launcher/discussions
