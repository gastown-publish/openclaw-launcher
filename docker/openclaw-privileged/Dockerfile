# OpenClaw Launcher - Privileged Tier Base Image
# Python 3.13 with full plugin suite

FROM python:3.13-slim

LABEL maintainer="OpenClaw Team <team@openclaw.dev>"
LABEL tier="privileged"
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
ENV TIER=privileged

# Telegram STT Configuration (Privileged tier uses Whisper API + Local)
ENV FORCE_MEDIA_UNDERSTANDING=true
ENV WHISPER_MODEL=large-v3
ENV TRANSCRIPTION_PROVIDER=whisper-api

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    wget \
    git \
    build-essential \
    libffi-dev \
    libssl-dev \
    ffmpeg \
    libsndfile1 \
    libsndfile1-dev \
    procps \
    && rm -rf /var/lib/apt/lists/*

# NOTE: The following tools need to be installed based on your actual setup:
# - openclaw-cli (the main OpenClaw CLI tool)
# - clawhub-cli (plugin management)
# - AI provider CLIs: kimi, toad, codex, claude-code, gemini, etc.
# 
# Example installations (uncomment and modify as needed):
# RUN pip install --no-cache-dir openclaw-cli
# RUN pip install --no-cache-dir kimi-cli toad-cli claude-cli codex-cli gemini-cli

# Install OpenAI Whisper for local fallback
RUN pip install --no-cache-dir openai-whisper

# Install Deepgram as additional option
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
