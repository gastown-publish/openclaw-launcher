FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

# System packages
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl wget git ca-certificates gnupg lsb-release \
    jq tmux lsof net-tools openssh-server sudo cron \
    build-essential python3 python3-pip python3-venv \
    fish \
    && rm -rf /var/lib/apt/lists/*

# Node.js 22 LTS
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - && \
    apt-get install -y nodejs && \
    rm -rf /var/lib/apt/lists/*

# yq
RUN wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 && \
    chmod +x /usr/local/bin/yq

# uv (Python package manager for kimi-cli etc.)
RUN curl -LsSf https://astral.sh/uv/install.sh | sh && \
    cp /root/.local/bin/uv /usr/local/bin/uv && \
    cp /root/.local/bin/uvx /usr/local/bin/uvx

# OpenClaw (official installer — skip interactive setup, config comes from volume)
RUN curl -fsSL https://openclaw.ai/install.sh -o /tmp/install-openclaw.sh && \
    sed -i "s|/dev/tty|/dev/null|g" /tmp/install-openclaw.sh && \
    bash /tmp/install-openclaw.sh || true && \
    rm -f /tmp/install-openclaw.sh && \
    command -v openclaw && openclaw --version

# ClawHub CLI
RUN npm install -g clawhub

# Root uses /home/openclaw as home — single user, zero permission issues
RUN sed -i "s|^root:x:0:0:root:/root:|root:x:0:0:root:/home/openclaw:|" /etc/passwd

# Create directory structure
RUN mkdir -p /home/openclaw/.local/bin /home/openclaw/.openclaw/state \
    /home/openclaw/.openclaw/workspace/skills \
    /home/openclaw/logs /home/openclaw/.ssh /home/openclaw/.kimi \
    /tmp/openclaw

ENV HOME=/home/openclaw
ENV PATH=/home/openclaw/.local/bin:/usr/local/bin:/usr/bin:/bin:$PATH
ENV OPENCLAW_STATE_DIR=/home/openclaw/.openclaw/state
ENV LANG=en_US.UTF-8

WORKDIR /home/openclaw

# Copy init script
COPY init.sh /init.sh
RUN chmod +x /init.sh

CMD ["/init.sh"]
