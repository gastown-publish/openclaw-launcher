# Tutorial: Deploying your first OpenClaw instance

This guide will walk you through the process of setting up and deploying your first OpenClaw instance using the OpenClaw Launcher.

## Prerequisites

- **Docker and Docker Compose**: Ensure you have the latest versions installed.
- **Make**: (Optional but recommended) For using the provided automation scripts.
- **API Keys**: You will need API keys for at least one model provider (Kimi, Toad, or Codex).

## Step 1: Clone the Repository

Start by cloning the OpenClaw Launcher repository to your local machine:

```bash
git clone https://github.com/gastown-publish/openclaw-launcher.git
cd openclaw-launcher
```

## Step 2: Configure Environment Variables

Copy the example environment file and edit it with your configuration:

```bash
cp .env.example .env
```

Open the `.env` file in your favorite text editor and fill in your API keys and preferred settings.

## Step 3: Create Docker Secrets

OpenClaw Launcher uses Docker secrets to securely manage sensitive information like API keys. You can create them using the following commands:

```bash
# Required secrets
echo "your-kimi-api-key" | docker secret create kimi_key -
echo "your-toad-api-key" | docker secret create toad_key -
echo "your-codex-api-key" | docker secret create codex_key -

# Optional integration secrets
echo "your-telegram-bot-token" | docker secret create telegram_bot_token -
echo "your-deepgram-api-key" | docker secret create deepgram_key -
```

Alternatively, you can use `make secrets` for an interactive setup.

## Step 4: Deploy the Services

You can deploy the services using the provided Makefile or directly with Docker Compose.

### Using Make (Recommended)

To deploy all services (Normal and Privileged tiers + Deacon):

```bash
make up
```

To deploy only the Normal tier:

```bash
make up-normal
```

### Using Docker Compose

```bash
docker-compose --profile all up -d
```

## Step 5: Verify the Deployment

Once the deployment is complete, you can check the status of your containers:

```bash
docker-compose ps
```

You should see the `openclaw-normal`, `openclaw-privileged`, and `deacon` containers running.

## Step 6: Accessing your instance

You can now start interacting with your OpenClaw instance via the configured interfaces (e.g., Telegram bot or CLI).

To open a shell in the Normal tier container:

```bash
make shell-normal
```

## Next Steps

- Explore the [Architecture](../architecture.md) to understand the tier system.
- Check the [Troubleshooting](../troubleshooting.md) guide if you encounter any issues.
- Learn about [Custom Skill Development](../examples/custom-skill/) to extend your instance.
