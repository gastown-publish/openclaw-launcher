# OpenClaw Launcher Makefile
# Common operations for building, deploying, and managing the launcher

.PHONY: help build build-base build-privileged build-deacon up down logs shell clean test lint

# Default target
help:
	@echo "OpenClaw Launcher - Available Commands:"
	@echo ""
	@echo "  make build           - Build all Docker images"
	@echo "  make build-base      - Build Normal tier image"
	@echo "  make build-privileged- Build Privileged tier image"
	@echo "  make build-deacon    - Build Deacon service image"
	@echo ""
	@echo "  make up              - Deploy all services (normal + privileged + deacon)"
	@echo "  make up-normal       - Deploy Normal tier only"
	@echo "  make up-privileged   - Deploy Privileged tier only"
	@echo "  make down            - Stop all services"
	@echo ""
	@echo "  make logs            - View logs from all services"
	@echo "  make logs-deacon     - View Deacon service logs"
	@echo "  make shell-normal    - Open shell in Normal tier container"
	@echo "  make shell-privileged- Open shell in Privileged tier container"
	@echo ""
	@echo "  make secrets         - Create example Docker secrets (prompts for values)"
	@echo "  make test            - Run tests and validation"
	@echo "  make lint            - Run linting on shell scripts and Dockerfiles"
	@echo "  make clean           - Remove all containers and volumes"
	@echo ""

# Build targets
build: build-base build-privileged build-deacon

build-base:
	@echo "Building Normal tier image..."
	docker build -t openclaw-launcher/base:latest ./docker/openclaw-base/

build-privileged:
	@echo "Building Privileged tier image..."
	docker build -t openclaw-launcher/privileged:latest ./docker/openclaw-privileged/

build-deacon:
	@echo "Building Deacon service image..."
	docker build -t openclaw-launcher/deacon:latest ./deacon/

# Deployment targets
up:
	@echo "Deploying all services..."
	docker-compose --profile all up -d

up-normal:
	@echo "Deploying Normal tier..."
	docker-compose --profile normal up -d

up-privileged:
	@echo "Deploying Privileged tier..."
	docker-compose --profile privileged up -d

down:
	@echo "Stopping all services..."
	docker-compose --profile all down

# Utility targets
logs:
	docker-compose logs -f

logs-deacon:
	docker-compose logs -f deacon

logs-normal:
	docker-compose logs -f openclaw-normal

logs-privileged:
	docker-compose logs -f openclaw-privileged

shell-normal:
	docker exec -it openclaw-normal /bin/bash

shell-privileged:
	docker exec -it openclaw-privileged /bin/bash

shell-deacon:
	docker exec -it deacon /bin/bash

# Secrets management
secrets:
	@echo "Creating Docker secrets..."
	@echo "Note: This will prompt for secret values. Press Ctrl+C to skip a secret."
	@echo ""
	@read -p "Enter Kimi API key (or press Enter to skip): " key; \
	if [ -n "$$key" ]; then echo "$$key" | docker secret create kimi_key - 2>/dev/null || echo "kimi_key already exists"; fi
	@read -p "Enter Toad API key (or press Enter to skip): " key; \
	if [ -n "$$key" ]; then echo "$$key" | docker secret create toad_key - 2>/dev/null || echo "toad_key already exists"; fi
	@read -p "Enter Codex API key (or press Enter to skip): " key; \
	if [ -n "$$key" ]; then echo "$$key" | docker secret create codex_key - 2>/dev/null || echo "codex_key already exists"; fi
	@read -p "Enter Claude Code key (or press Enter to skip): " key; \
	if [ -n "$$key" ]; then echo "$$key" | docker secret create claude_key - 2>/dev/null || echo "claude_key already exists"; fi
	@read -p "Enter Gemini API key (or press Enter to skip): " key; \
	if [ -n "$$key" ]; then echo "$$key" | docker secret create gemini_key - 2>/dev/null || echo "gemini_key already exists"; fi
	@read -p "Enter Telegram bot token (or press Enter to skip): " key; \
	if [ -n "$$key" ]; then echo "$$key" | docker secret create telegram_bot_token - 2>/dev/null || echo "telegram_bot_token already exists"; fi
	@read -p "Enter Deepgram API key (or press Enter to skip): " key; \
	if [ -n "$$key" ]; then echo "$$key" | docker secret create deepgram_key - 2>/dev/null || echo "deepgram_key already exists"; fi
	@read -p "Enter Deacon API key (or press Enter to skip): " key; \
	if [ -n "$$key" ]; then echo "$$key" | docker secret create deacon_api_key - 2>/dev/null || echo "deacon_api_key already exists"; fi

# Testing and validation
test:
	@echo "Running tests..."
	@echo "Validating docker-compose.yml..."
	docker-compose config > /dev/null && echo "✓ docker-compose.yml is valid"
	@echo "Checking for required files..."
	@test -f docker-compose.yml && echo "✓ docker-compose.yml exists"
	@test -f docker/openclaw-base/Dockerfile && echo "✓ Normal tier Dockerfile exists"
	@test -f docker/openclaw-privileged/Dockerfile && echo "✓ Privileged tier Dockerfile exists"
	@test -f deacon/Dockerfile && echo "✓ Deacon Dockerfile exists"
	@test -f deacon/requirements.txt && echo "✓ Deacon requirements.txt exists"
	@echo "All tests passed!"

lint:
	@echo "Running linters..."
	@echo "Checking shell scripts with shellcheck..."
	@which shellcheck > /dev/null || (echo "shellcheck not installed, skipping..."; exit 0)
	@find . -name "*.sh" -type f -exec shellcheck {} \; 2>/dev/null || echo "Shellcheck completed with warnings"
	@echo "Checking Dockerfiles with hadolint..."
	@which hadolint > /dev/null || (echo "hadolint not installed, skipping..."; exit 0)
	@hadolint docker/openclaw-base/Dockerfile 2>/dev/null || true
	@hadolint docker/openclaw-privileged/Dockerfile 2>/dev/null || true
	@hadolint deacon/Dockerfile 2>/dev/null || true
	@echo "Linting complete!"

# Cleanup
clean:
	@echo "Cleaning up containers and volumes..."
	docker-compose --profile all down -v
	docker system prune -f

# Full reset (DANGER: removes all data)
reset:
	@echo "WARNING: This will remove all containers, volumes, and secrets!"
	@read -p "Are you sure? (yes/no): " confirm; \
	if [ "$$confirm" = "yes" ]; then \
		docker-compose --profile all down -v; \
		docker volume rm -f openclaw-data-normal openclaw-data-privileged deacon-data 2>/dev/null || true; \
		docker secret rm kimi_key toad_key codex_key claude_key gemini_key telegram_bot_token deepgram_key deacon_api_key 2>/dev/null || true; \
		echo "Cleanup complete!"; \
	else \
		echo "Aborted."; \
	fi

# Deacon operations
update-plugins:
	@echo "Triggering plugin update via Deacon..."
	@curl -X POST http://localhost:8080/update-plugins 2>/dev/null || echo "Deacon not accessible at localhost:8080"

backup:
	@echo "Triggering backup via Deacon..."
	@curl -X POST http://localhost:8080/backup 2>/dev/null || echo "Deacon not accessible at localhost:8080"

health:
	@echo "Checking Deacon health..."
	@curl http://localhost:8080/health 2>/dev/null || echo "Deacon not accessible at localhost:8080"
