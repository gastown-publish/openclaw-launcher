# OpenClaw Launcher - Normal Tier Base Image
# Python 3.11 slim with essential plugins

FROM python:3.11-slim

LABEL maintainer="OpenClaw Team <team@openclaw.dev>"
LABEL tier="normal"
LABEL version="1.0.0"

# Prevent Python from writing pyc files and buffering stdout
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
ENV PIP_NO_CACHE_DIR=1

# OpenClaw environment variables
ENV OPENCLAW_HOME=/opt/openclaw
ENV OPENCLAW_DATA_DIR=/root/.openclaw/data
ENV OPENCLAW_ADDONS_DIR=/root/.openclaw/addons
ENV OPENCLAW_SKILLS_DIR=/root/.openclaw/skills
ENV TIER=normal

# Telegram STT Workaround
ENV FORCE_MEDIA_UNDERSTANDING=true
ENV WHISPER_MODEL=base
ENV TRANSCRIPTION_PROVIDER=deepgram

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    wget \
    git \
    build-essential \
    libffi-dev \
    libssl-dev \
    ffmpeg \
    procps \
    && rm -rf /var/lib/apt/lists/*

# NOTE: The following tools need to be installed based on your actual setup:
# - openclaw-cli (the main OpenClaw CLI tool)
# - clawhub-cli (plugin management)
# - AI provider CLIs: kimi, toad, codex, etc.
# 
# Example installations (uncomment and modify as needed):
# RUN pip install --no-cache-dir openclaw-cli
# RUN pip install --no-cache-dir kimi-cli toad-cli codex-cli

# Install Deepgram for speech-to-text (English only for Normal tier)
RUN pip install --no-cache-dir deepgram-sdk

# Create necessary directories
RUN mkdir -p ${OPENCLAW_HOME}/scripts \
    ${OPENCLAW_DATA_DIR} \
    ${OPENCLAW_ADDONS_DIR} \
    ${OPENCLAW_SKILLS_DIR} \
    /var/log/openclaw

# Copy entrypoint and workaround scripts
COPY entrypoint.sh ${OPENCLAW_HOME}/scripts/
COPY telegram-stt-workaround.sh ${OPENCLAW_HOME}/scripts/

# Set executable permissions
RUN chmod +x ${OPENCLAW_HOME}/scripts/*.sh

# Health check - checks if the main process is running
# Modify this based on your actual service
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD ps aux | grep -v grep | grep -q "python\|openclaw" || exit 1

# Expose default port
EXPOSE 8080

# Set working directory
WORKDIR ${OPENCLAW_HOME}

# Entrypoint
ENTRYPOINT ["/opt/openclaw/scripts/entrypoint.sh"]
CMD ["sleep", "infinity"]
