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

# Telegram STT Configuration (Privileged tier uses Whisper API + Local)
ENV FORCE_MEDIA_UNDERSTANDING=true
ENV WHISPER_MODEL=large-v3
ENV TRANSCRIPTION_PROVIDER=whisper-api
ENV WHISPER_API_KEY=${KIMI_API_KEY}

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
    && rm -rf /var/lib/apt/lists/*

# Install OpenClaw CLI
RUN pip install --no-cache-dir openclaw-cli

# Install ClawHub CLI (if separate)
RUN pip install --no-cache-dir clawhub-cli || echo "clawhub-cli bundled with openclaw-cli"

# Install all model providers
RUN openclaw plugin install \
    kimi-provider \
    toad-provider \
    claude-code-provider \
    codex-provider \
    gemini-provider

# Install full Google Workspace suite from ClawHub
RUN clawhub install \
    gog \
    gogcli \
    gmail-tool \
    gcal-tool \
    gdrive-tool \
    gdocs-tool \
    gsheets-tool \
    gtasks-tool \
    gcontacts-tool \
    gsearch-tool

# Install advanced Telegram with Whisper support
RUN clawhub install telegram-channel whisper-tool

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
