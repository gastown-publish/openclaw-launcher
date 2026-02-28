#!/bin/bash
# OpenClaw Launcher - Entrypoint Script
# Handles initialization and startup for both Normal and Privileged tiers

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# Function to read secrets from files
read_secret() {
    local secret_file=$1
    if [[ -f "$secret_file" ]]; then
        cat "$secret_file"
    else
        echo ""
    fi
}

# Initialize environment from secrets
init_secrets() {
    log_info "Initializing secrets..."
    
    # Model Provider Keys
    export KIMI_API_KEY=$(read_secret "/run/secrets/kimi_key")
    export TOAD_API_KEY=$(read_secret "/run/secrets/toad_key")
    export CODEX_API_KEY=$(read_secret "/run/secrets/codex_key")
    
    # Optional keys for privileged tier
    if [[ -f "/run/secrets/claude_key" ]]; then
        export CLAUDE_CODE_KEY=$(read_secret "/run/secrets/claude_key")
    fi
    
    if [[ -f "/run/secrets/gemini_key" ]]; then
        export GEMINI_API_KEY=$(read_secret "/run/secrets/gemini_key")
    fi
    
    # Google OAuth
    export GOOGLE_OAUTH=$(read_secret "/run/secrets/google_oauth")
    
    # Telegram
    export TELEGRAM_BOT_TOKEN=$(read_secret "/run/secrets/telegram_bot_token")
    
    # Deepgram (for STT)
    export DEEPGRAM_API_KEY=$(read_secret "/run/secrets/deepgram_key")
    
    # Whisper API key fallback to Kimi
    if [[ -z "$WHISPER_API_KEY" && -n "$KIMI_API_KEY" ]]; then
        export WHISPER_API_KEY="$KIMI_API_KEY"
    fi
    
    log_success "Secrets initialized"
}

# Initialize directories
init_directories() {
    log_info "Initializing directories..."
    
    mkdir -p ${OPENCLAW_DATA_DIR}
    mkdir -p ${OPENCLAW_ADDONS_DIR}
    mkdir -p ${OPENCLAW_SKILLS_DIR}
    mkdir -p /var/log/openclaw
    
    log_success "Directories initialized"
}

# Check and install plugin updates
check_plugin_updates() {
    log_info "Checking for plugin updates..."
    
    if [[ "${PLUGINS_AUTO_UPDATE}" == "true" ]]; then
        log_info "Auto-update enabled, updating plugins..."
        
        # Update ClawHub plugins
        if command -v clawhub &> /dev/null; then
            clawhub update --all || log_warn "Some plugins failed to update"
        fi
        
        # Update OpenClaw plugins
        if command -v openclaw &> /dev/null; then
            openclaw plugin update --all || log_warn "Some OpenClaw plugins failed to update"
        fi
        
        log_success "Plugin updates completed"
    else
        log_info "Auto-update disabled, skipping plugin updates"
    fi
}

# Apply Telegram STT workaround
apply_telegram_stt_workaround() {
    log_info "Applying Telegram STT workaround..."
    
    if [[ -f "${OPENCLAW_HOME}/scripts/telegram-stt-workaround.sh" ]]; then
        bash "${OPENCLAW_HOME}/scripts/telegram-stt-workaround.sh"
    else
        log_warn "Telegram STT workaround script not found"
    fi
}

# Validate configuration
validate_config() {
    log_info "Validating configuration..."
    
    local errors=0
    
    # Check required environment variables
    if [[ -z "$KIMI_API_KEY" ]]; then
        log_error "KIMI_API_KEY is not set"
        errors=$((errors + 1))
    fi
    
    if [[ -z "$TELEGRAM_BOT_TOKEN" ]]; then
        log_warn "TELEGRAM_BOT_TOKEN is not set - Telegram integration will not work"
    fi
    
    # Check OpenClaw installation
    if ! command -v openclaw &> /dev/null; then
        log_error "OpenClaw CLI is not installed"
        errors=$((errors + 1))
    fi
    
    if [[ $errors -gt 0 ]]; then
        log_error "Configuration validation failed with $errors errors"
        exit 1
    fi
    
    log_success "Configuration validated"
}

# Setup Google Workspace integration
setup_google_workspace() {
    log_info "Setting up Google Workspace integration..."
    
    if [[ -n "$GOOGLE_OAUTH" ]]; then
        # Save OAuth credentials to file
        echo "$GOOGLE_OAUTH" > /root/.openclaw/google_oauth.json
        chmod 600 /root/.openclaw/google_oauth.json
        log_success "Google OAuth credentials configured"
    else
        log_warn "Google OAuth credentials not provided"
    fi
}

# Print startup banner
print_banner() {
    echo ""
    echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                                                            ║${NC}"
    echo -e "${GREEN}║              OpenClaw Launcher v1.0.0                      ║${NC}"
    echo -e "${GREEN}║                                                            ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    log_info "Tier: ${TIER:-normal}"
    log_info "Python: $(python --version)"
    log_info "OpenClaw: $(openclaw --version 2>/dev/null || echo 'unknown')"
    echo ""
}

# Main initialization
main() {
    print_banner
    
    log_info "Starting OpenClaw Launcher initialization..."
    
    init_secrets
    init_directories
    setup_google_workspace
    check_plugin_updates
    apply_telegram_stt_workaround
    validate_config
    
    log_success "Initialization complete!"
    echo ""
    
    # Execute the main command
    log_info "Starting OpenClaw..."
    exec "$@"
}

# Run main function
main "$@"
