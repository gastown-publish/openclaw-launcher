#!/bin/bash
# Create a Pull Request on GitHub using the GitHub API
# Usage: ./create-pr.sh [branch-name]

set -e

# Configuration
# Set GITHUB_TOKEN environment variable before running:
# export GITHUB_TOKEN=ghp_your_token_here
GITHUB_TOKEN="${GITHUB_TOKEN:-}"
REPO_OWNER="gastown-publish"
REPO_NAME="openclaw-launcher"
BASE_BRANCH="main"
HEAD_BRANCH="${1:-$(git branch --show-current 2>/dev/null || echo 'main')}"

# PR Content
PR_TITLE="Initial Release: OpenClaw Launcher v1.0.0"

PR_BODY='## OpenClaw Launcher - First Version

This PR introduces the initial version of OpenClaw Launcher with the following features:

### Features

- **Tiered Architecture**: Normal (4CPU/16GB) and Privileged (8CPU/128GB) tiers
- **Pre-installed Model Providers**: Kimi, Toad, Claude Code, Codex, Gemini
- **Google Workspace Integration**: Full suite via ClawHub plugins
- **Telegram STT Workaround**: Fixes known voice transcription bug
- **Deacon Service**: Automated plugin updates, monitoring, and backups

### Components

#### Docker Images
- `docker/openclaw-base/` - Normal tier (Python 3.11, 4CPU/16GB)
- `docker/openclaw-privileged/` - Privileged tier (Python 3.13, 8CPU/128GB)
- `deacon/` - Plugin management and monitoring service

#### Pre-installed Plugins

**Model Providers (All Tiers):**
- Kimi, Toad, Codex

**Privileged-Only:**
- Claude Code, Gemini

**Google Workspace:**
- gog, gogcli, gcal-tool, gdrive-tool (both tiers)
- gmail-tool, gdocs-tool, gsheets-tool, gsearch-tool (privileged only)

#### Skills
- `google-workspace/` - Google Workspace integration
- `telegram-utils/` - Telegram with STT workaround
- `system/` - System management utilities

#### Workarounds
- Telegram STT bug fix via media understanding patch

### Resource Tiers

| Resource | Normal | Privileged |
|----------|--------|------------|
| CPU | 4 cores | 8 cores |
| Memory | 16GB | 128GB |
| Disk | 50GB | 100GB |
| STT | Deepgram (EN) | Whisper API + Local |

### CI/CD

- GitHub Actions workflows for building and pushing images
- Automated testing on PR
- Release automation on tag push

### Documentation

- Comprehensive README.md
- SETUP.md for setup instructions
- Inline code documentation

### Testing Checklist

- [ ] Build base image
- [ ] Build privileged image  
- [ ] Build deacon image
- [ ] Test docker-compose configuration
- [ ] Verify Telegram STT workaround
- [ ] Test plugin updates via Deacon
- [ ] Verify health monitoring

### Notes

- Telegram STT workaround addresses known OpenClaw bug where `applyMediaUnderstanding` is never called
- Deacon service runs daily plugin updates and monitors Telegram STT failures
- All sensitive configuration via Docker secrets
'

echo "Creating Pull Request..."
echo "Repository: $REPO_OWNER/$REPO_NAME"
echo "Base: $BASE_BRANCH"
echo "Head: $HEAD_BRANCH"
echo ""

# Create PR using GitHub API
RESPONSE=$(curl -s -X POST \
  -H "Authorization: token $GITHUB_TOKEN" \
  -H "Accept: application/vnd.github.v3+json" \
  https://api.github.com/repos/$REPO_OWNER/$REPO_NAME/pulls \
  -d "{
    \"title\": \"$PR_TITLE\",
    \"body\": $(echo "$PR_BODY" | jq -Rs .),
    \"head\": \"$HEAD_BRANCH\",
    \"base\": \"$BASE_BRANCH\"
  }")

# Check for errors
if echo "$RESPONSE" | grep -q '"message"'; then
    echo "Error creating PR:"
    echo "$RESPONSE" | jq -r '.message'
    exit 1
fi

# Extract PR URL
PR_URL=$(echo "$RESPONSE" | jq -r '.html_url')
PR_NUMBER=$(echo "$RESPONSE" | jq -r '.number')

echo "Pull Request created successfully!"
echo "URL: $PR_URL"
echo "Number: $PR_NUMBER"
echo ""
echo "Next steps:"
echo "  1. Review the PR on GitHub"
echo "  2. Run tests: docker-compose config"
echo "  3. Merge when ready"
