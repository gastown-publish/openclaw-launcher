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
    local secret_file="$1"
    if [[ -f "$secret_file" ]]; then
        tr -d '\n\r' < "$secret_file"
    else
        echo ""
    fi
}

# Initialize environment from secrets
init_secrets() {
    log_info "Initializing secrets..."
    
    # Model Provider Keys
    KIMI_API_KEY=$(read_secret "/run/secrets/kimi_key")
    export KIMI_API_KEY
    
    TOAD_API_KEY=$(read_secret "/run/secrets/toad_key")
    export TOAD_API_KEY
    
    CODEX_API_KEY=$(read_secret "/run/secrets/codex_key")
    export CODEX_API_KEY
    
    # Optional keys for privileged tier
    if [[ -f "/run/secrets/claude_key" ]]; then
        CLAUDE_CODE_KEY=$(read_secret "/run/secrets/claude_key")
        export CLAUDE_CODE_KEY
    fi
    
    if [[ -f "/run/secrets/gemini_key" ]]; then
        GEMINI_API_KEY=$(read_secret "/run/secrets/gemini_key")
        export GEMINI_API_KEY
    fi
    
    # Google OAuth
    GOOGLE_OAUTH=$(read_secret "/run/secrets/google_oauth")
    export GOOGLE_OAUTH
    
    # Telegram
    TELEGRAM_BOT_TOKEN=$(read_secret "/run/secrets/telegram_bot_token")
    export TELEGRAM_BOT_TOKEN
    
    # Deepgram (for STT)
    DEEPGRAM_API_KEY=$(read_secret "/run/secrets/deepgram_key")
    export DEEPGRAM_API_KEY
    
    # Whisper API key fallback to Kimi
    if [[ -z "${WHISPER_API_KEY:-}" && -n "$KIMI_API_KEY" ]]; then
        WHISPER_API_KEY="$KIMI_API_KEY"
        export WHISPER_API_KEY
    fi
    
    log_success "Secrets initialized"
}

# Initialize directories
init_directories() {
    log_info "Initializing directories..."
    
    mkdir -p "${OPENCLAW_DATA_DIR}"
    mkdir -p "${OPENCLAW_ADDONS_DIR}"
    mkdir -p "${OPENCLAW_SKILLS_DIR}"
    mkdir -p /var/log/openclaw
    
    log_success "Directories initialized"
}

# Check and install plugin updates
check_plugin_updates() {
    log_info "Checking for plugin updates..."
    
    if [[ "${PLUGINS_AUTO_UPDATE:-}" == "true" ]]; then
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
        log_warn "KIMI_API_KEY is not set - Kimi integration will not work"
    fi
    
    if [[ -z "$TELEGRAM_BOT_TOKEN" ]]; then
        log_warn "TELEGRAM_BOT_TOKEN is not set - Telegram integration will not work"
    fi
    
    # Check OpenClaw installation (warning only - container can still run)
    if ! command -v openclaw &> /dev/null; then
        log_warn "OpenClaw CLI is not installed - some features may not work"
    fi
    
    if [[ $errors -gt 0 ]]; then
        log_warn "Configuration validation completed with $errors warnings"
    else
        log_success "Configuration validated"
    fi
}

# Setup Google Workspace integration
setup_google_workspace() {
    log_info "Setting up Google Workspace integration..."
    
    if [[ -n "$GOOGLE_OAUTH" ]]; then
        # Save OAuth credentials to file
        mkdir -p /root/.openclaw
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
    log_info "Python: $(python --version 2>&1)"
    log_info "OpenClaw: $(openclaw --version 2>/dev/null || echo 'not installed')"
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
    log_info "Starting: $*"
    exec "$@"
}

# Run main function
main "$@"
