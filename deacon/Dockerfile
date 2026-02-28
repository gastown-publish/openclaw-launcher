# OpenClaw Launcher - Deacon Service
# Plugin management, monitoring, and maintenance daemon

FROM python:3.11-slim

LABEL maintainer="OpenClaw Team <team@openclaw.dev>"
LABEL service="deacon"
LABEL version="1.0.0"

# Prevent Python from writing pyc files and buffering stdout
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

# Deacon configuration
ENV DEACON_HOME=/opt/deacon
ENV DEACON_DATA=/var/lib/deacon
ENV DEACON_LOG=/var/log/deacon

# Default intervals (in seconds)
ENV PLUGIN_UPDATE_INTERVAL=86400
ENV HEALTH_CHECK_INTERVAL=300
ENV BACKUP_INTERVAL=3600

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    jq \
    cron \
    docker.io \
    && rm -rf /var/lib/apt/lists/*

# Install Python dependencies
RUN pip install --no-cache-dir \
    requests \
    schedule \
    pyyaml \
    docker \
    prometheus-client

# Create directories
RUN mkdir -p ${DEACON_HOME}/scripts \
    ${DEACON_DATA} \
    ${DEACON_LOG} \
    ${DEACON_DATA}/backups \
    ${DEACON_DATA}/metrics

# Copy deacon scripts
COPY deacon.py ${DEACON_HOME}/
COPY plugins/ ${DEACON_HOME}/plugins/
COPY scripts/ ${DEACON_HOME}/scripts/

# Set executable permissions
RUN chmod +x ${DEACON_HOME}/deacon.py
RUN chmod +x ${DEACON_HOME}/scripts/*.sh

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8080/health || exit 1

# Expose API port
EXPOSE 8080

# Expose metrics port for Prometheus
EXPOSE 9090

WORKDIR ${DEACON_HOME}

ENTRYPOINT ["python", "deacon.py"]
