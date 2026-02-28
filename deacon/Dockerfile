FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl jq \
    && rm -rf /var/lib/apt/lists/*

# Install Docker CLI (for managing sub-instances)
RUN curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg && \
    echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian bookworm stable" > /etc/apt/sources.list.d/docker.list && \
    apt-get update && \
    apt-get install -y docker-ce-cli && \
    rm -rf /var/lib/apt/lists/*

RUN pip install --no-cache-dir docker requests schedule pyyaml

RUN mkdir -p /var/lib/deacon /var/log/deacon

COPY deacon.py /opt/deacon/deacon.py
COPY scripts/ /opt/deacon/scripts/
RUN chmod +x /opt/deacon/scripts/*.sh 2>/dev/null || true

WORKDIR /opt/deacon

HEALTHCHECK --interval=30s --timeout=10s --retries=3 \
    CMD curl -f http://localhost:8080/health || exit 1

ENTRYPOINT ["python", "deacon.py"]
