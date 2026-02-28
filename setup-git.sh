#!/bin/bash
# Setup script for pushing OpenClaw Launcher to GitHub
# Run this script after cloning the repository

set -e

echo "Setting up OpenClaw Launcher repository..."

# Check if git is configured
if [ -z "$(git config --global user.email)" ]; then
    echo "Please configure git user.email:"
    echo "  git config --global user.email 'your@email.com'"
    exit 1
fi

if [ -z "$(git config --global user.name)" ]; then
    echo "Please configure git user.name:"
    echo "  git config --global user.name 'Your Name'"
    exit 1
fi

# Initialize git if not already done
if [ ! -d ".git" ]; then
    echo "Initializing git repository..."
    git init
    git branch -m main
fi

# Add remote if not exists
if ! git remote | grep -q "origin"; then
    echo "Adding remote origin..."
    git remote add origin git@github.com:gastown-publish/openclaw-launcher.git
fi

# Add all files
echo "Adding files to git..."
git add .

# Commit
echo "Creating initial commit..."
git commit -m "Initial commit: OpenClaw Launcher v1.0.0

- Add Docker configurations for Normal and Privileged tiers
- Add docker-compose.yml with plugin configuration
- Add entrypoint scripts with Telegram STT workaround
- Add Deacon service for plugin updates and monitoring
- Add pre-installed skills for Google Workspace, Telegram, and System
- Add CI/CD workflows for GitHub Actions
- Add comprehensive README documentation

Features:
- Pre-installed model providers (Kimi, Toad, Claude, Codex, Gemini)
- Google Workspace integration via ClawHub plugins
- Tiered resource management (Normal: 4CPU/16GB, Privileged: 8CPU/128GB)
- Telegram voice message transcription workaround
- Automated plugin updates and health monitoring"

# Push to GitHub
echo "Pushing to GitHub..."
git push -u origin main

echo ""
echo "Setup complete! Repository pushed to:"
echo "  https://github.com/gastown-publish/openclaw-launcher"
echo ""
echo "Next steps:"
echo "  1. Create a pull request on GitHub"
echo "  2. Set up Docker secrets (see README.md)"
echo "  3. Deploy with: docker-compose --profile all up -d"
