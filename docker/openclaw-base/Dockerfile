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
    && rm -rf /var/lib/apt/lists/*

# Install OpenClaw CLI
RUN pip install --no-cache-dir openclaw-cli

# Install ClawHub CLI (if separate)
RUN pip install --no-cache-dir clawhub-cli || echo "clawhub-cli bundled with openclaw-cli"

# Install model providers
RUN openclaw plugin install \
    kimi-provider \
    toad-provider \
    codex-provider

# Install ClawHub Google plugins (Normal tier subset)
RUN clawhub install \
    gog \
    gcal-tool \
    gdrive-tool \
    gtasks-tool \
    gcontacts-tool

# Install Telegram channel with STT workaround
RUN clawhub install telegram-channel

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

# Copy pre-installed skills
COPY skills/ ${OPENCLAW_SKILLS_DIR}/

# Set executable permissions
RUN chmod +x ${OPENCLAW_HOME}/scripts/*.sh

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD openclaw healthcheck || exit 1

# Expose default port (if needed for web interface)
EXPOSE 8080

# Set working directory
WORKDIR ${OPENCLAW_HOME}

# Entrypoint
ENTRYPOINT ["/opt/openclaw/scripts/entrypoint.sh"]
CMD ["openclaw", "start"]
