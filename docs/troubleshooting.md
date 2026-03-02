# Troubleshooting Guide

This guide provides solutions for common issues encountered when using the OpenClaw Launcher.

## Telegram Speech-to-Text (STT) Not Working

If voice messages are not being transcribed in Telegram, follow these steps:

1. **Check if the workaround is applied**:
   Run the following command to verify that the workaround script is present in the container:
   ```bash
   docker exec openclaw-normal cat /opt/openclaw/scripts/telegram-stt-workaround.sh
   ```

2. **Verify environment variables**:
   Ensure that the STT-related environment variables are correctly set:
   ```bash
   docker exec openclaw-normal env | grep -E '(FORCE_MEDIA|WHISPER|TRANSCRIPTION)'
   ```
   `FORCE_MEDIA_UNDERSTANDING` should be set to `true`.

3. **Check logs for errors**:
   Look for STT-related errors in the container logs:
   ```bash
   docker-compose logs openclaw-normal | grep -i stt
   ```

4. **Verify STT Provider API Key**:
   Ensure that your STT provider's API key (e.g., `deepgram_key`) is correctly set as a Docker secret.

## Plugin Update Failures

If the Deacon service fails to update plugins:

1. **Check Deacon logs**:
   ```bash
   docker-compose logs deacon | grep -i "plugin update"
   ```

2. **Manual update attempt**:
   Try running the update manually inside the container to see detailed error messages:
   ```bash
   docker exec openclaw-normal clawhub update --all
   ```

3. **Check network connectivity**:
   Ensure the container has access to the internet to fetch updates from the ClawHub registry.

## Container Won't Start

If your containers are failing to start:

1. **Check Docker secrets**:
   Ensure all required secrets have been created:
   ```bash
   docker secret ls
   ```

2. **Validate Docker Compose configuration**:
   Check for syntax errors or configuration issues in your YAML files:
   ```bash
   docker-compose config
   ```

3. **Examine container logs**:
   Check the logs for any immediate startup errors:
   ```bash
   docker-compose logs openclaw-normal
   ```

4. **Check resource limits**:
   Ensure your host machine has enough CPU and memory to meet the requirements of the tiers you are deploying.

## Architecture and Resource Issues

If you notice performance degradation or resource exhaustion:

1. **Review Tier Limits**:
   Check the [Architecture](./architecture.md) document to ensure you are using the appropriate tier for your workload.

2. **Monitor Resource Usage**:
   Use `docker stats` to see real-time CPU and memory usage of your containers.

## Getting Further Help

If you cannot resolve your issue using this guide:
- Open a new issue on [GitHub](https://github.com/gastown-publish/openclaw-launcher/issues)
- Join the discussion on [Discussions](https://github.com/gastown-publish/openclaw-launcher/discussions)
- Contact support at info@trusera.dev
