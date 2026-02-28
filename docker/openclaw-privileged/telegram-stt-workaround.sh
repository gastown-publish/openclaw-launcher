#!/bin/bash
# OpenClaw Launcher - Telegram Speech-to-Text Workaround
# 
# Known Issue: OpenClaw has a bug where applyMediaUnderstanding function 
# is never called during Telegram message processing, preventing automatic 
# transcription of voice messages.
#
# This workaround forces media understanding for Telegram voice messages
# by patching the Telegram channel handler.

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}[STT-WORKAROUND]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[STT-WORKAROUND]${NC} $1"
}

log_error() {
    echo -e "${RED}[STT-WORKAROUND]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[STT-WORKAROUND]${NC} $1"
}

log_info "Applying Telegram STT workaround..."

# Find Telegram plugin installation path
TELEGRAM_PLUGIN_PATH=""

# Check common locations
if [[ -d "/root/.openclaw/addons/telegram-channel" ]]; then
    TELEGRAM_PLUGIN_PATH="/root/.openclaw/addons/telegram-channel"
elif [[ -d "/opt/openclaw/addons/telegram-channel" ]]; then
    TELEGRAM_PLUGIN_PATH="/opt/openclaw/addons/telegram-channel"
elif [[ -d "/usr/local/lib/python*/site-packages/openclaw/addons/telegram-channel" ]]; then
    TELEGRAM_PLUGIN_PATH=$(find /usr/local/lib/python*/site-packages/openclaw/addons -name "telegram-channel" -type d 2>/dev/null | head -1)
fi

if [[ -z "$TELEGRAM_PLUGIN_PATH" ]]; then
    log_warn "Telegram plugin not found in standard locations"
    log_info "Attempting to find via openclaw command..."
    
    # Try to get path from openclaw
    if command -v openclaw &> /dev/null; then
        TELEGRAM_PLUGIN_PATH=$(openclaw plugin path telegram-channel 2>/dev/null || echo "")
    fi
fi

if [[ -z "$TELEGRAM_PLUGIN_PATH" ]]; then
    log_warn "Could not locate Telegram plugin, skipping workaround patch"
    log_info "STT may not work for voice messages until the bug is fixed upstream"
    exit 0
fi

log_info "Found Telegram plugin at: $TELEGRAM_PLUGIN_PATH"

# Create the patch for media understanding
PATCH_FILE="${TELEGRAM_PLUGIN_PATH}/media_understanding_patch.py"

cat > "$PATCH_FILE" << 'EOF'
"""
Telegram Media Understanding Patch
Forces transcription of voice messages in Telegram
"""

import os
import logging
from typing import Optional

logger = logging.getLogger(__name__)

# Force media understanding flag
FORCE_MEDIA_UNDERSTANDING = os.getenv('FORCE_MEDIA_UNDERSTANDING', 'true').lower() == 'true'
WHISPER_MODEL = os.getenv('WHISPER_MODEL', 'base')
TRANSCRIPTION_PROVIDER = os.getenv('TRANSCRIPTION_PROVIDER', 'deepgram')

class MediaUnderstandingPatcher:
    """Patches Telegram message handler to force media understanding"""
    
    def __init__(self):
        self.original_handler = None
        self.patched = False
    
    def patch_telegram_handler(self, telegram_bot):
        """Apply patch to Telegram bot message handler"""
        if not FORCE_MEDIA_UNDERSTANDING:
            logger.info("Media understanding patch disabled")
            return
        
        try:
            # Store original handler
            if hasattr(telegram_bot, '_handle_message'):
                self.original_handler = telegram_bot._handle_message
                telegram_bot._handle_message = self._patched_handle_message
                self.patched = True
                logger.info("Telegram message handler patched for media understanding")
        except Exception as e:
            logger.error(f"Failed to patch Telegram handler: {e}")
    
    def _patched_handle_message(self, message):
        """Patched message handler that forces media understanding"""
        try:
            # Check if message contains voice
            if hasattr(message, 'voice') and message.voice:
                logger.info("Voice message detected, forcing transcription")
                self._transcribe_voice_message(message)
            
            # Check if message contains audio
            if hasattr(message, 'audio') and message.audio:
                logger.info("Audio message detected, forcing transcription")
                self._transcribe_audio_message(message)
                
        except Exception as e:
            logger.error(f"Error in patched handler: {e}")
        
        # Call original handler
        if self.original_handler:
            return self.original_handler(message)
    
    def _transcribe_voice_message(self, message):
        """Transcribe voice message using configured provider"""
        try:
            voice_file = message.voice.get_file()
            
            if TRANSCRIPTION_PROVIDER == 'whisper-api':
                self._transcribe_with_whisper(voice_file)
            elif TRANSCRIPTION_PROVIDER == 'deepgram':
                self._transcribe_with_deepgram(voice_file)
            elif TRANSCRIPTION_PROVIDER == 'local':
                self._transcribe_with_local_whisper(voice_file)
            else:
                logger.warning(f"Unknown transcription provider: {TRANSCRIPTION_PROVIDER}")
                
        except Exception as e:
            logger.error(f"Voice transcription failed: {e}")
    
    def _transcribe_audio_message(self, message):
        """Transcribe audio message using configured provider"""
        try:
            audio_file = message.audio.get_file()
            
            if TRANSCRIPTION_PROVIDER == 'whisper-api':
                self._transcribe_with_whisper(audio_file)
            elif TRANSCRIPTION_PROVIDER == 'deepgram':
                self._transcribe_with_deepgram(audio_file)
            elif TRANSCRIPTION_PROVIDER == 'local':
                self._transcribe_with_local_whisper(audio_file)
            else:
                logger.warning(f"Unknown transcription provider: {TRANSCRIPTION_PROVIDER}")
                
        except Exception as e:
            logger.error(f"Audio transcription failed: {e}")
    
    def _transcribe_with_whisper(self, file_obj):
        """Transcribe using OpenAI Whisper API"""
        import openai
        
        api_key = os.getenv('WHISPER_API_KEY') or os.getenv('KIMI_API_KEY')
        if not api_key:
            logger.error("No API key for Whisper")
            return
        
        client = openai.OpenAI(api_key=api_key)
        
        try:
            with open(file_obj.download(), 'rb') as audio:
                response = client.audio.transcriptions.create(
                    model="whisper-1",
                    file=audio
                )
                logger.info(f"Whisper transcription: {response.text}")
                return response.text
        except Exception as e:
            logger.error(f"Whisper API transcription failed: {e}")
    
    def _transcribe_with_deepgram(self, file_obj):
        """Transcribe using Deepgram API"""
        from deepgram import DeepgramClient, PrerecordedOptions
        
        api_key = os.getenv('DEEPGRAM_API_KEY')
        if not api_key:
            logger.error("No Deepgram API key")
            return
        
        try:
            deepgram = DeepgramClient(api_key)
            
            with open(file_obj.download(), 'rb') as audio:
                source = {'buffer': audio, 'mimetype': 'audio/ogg'}
                options = PrerecordedOptions(
                    model="nova-2",
                    language="en",
                    smart_format=True
                )
                
                response = deepgram.listen.prerecorded.v("1").transcribe_file(
                    source, options
                )
                
                transcript = response.results.channels[0].alternatives[0].transcript
                logger.info(f"Deepgram transcription: {transcript}")
                return transcript
                
        except Exception as e:
            logger.error(f"Deepgram transcription failed: {e}")
    
    def _transcribe_with_local_whisper(self, file_obj):
        """Transcribe using local Whisper installation"""
        try:
            import whisper
            
            model = whisper.load_model(WHISPER_MODEL)
            result = model.transcribe(file_obj.download())
            
            logger.info(f"Local Whisper transcription: {result['text']}")
            return result['text']
            
        except ImportError:
            logger.error("Local Whisper not installed, run: pip install openai-whisper")
        except Exception as e:
            logger.error(f"Local Whisper transcription failed: {e}")

# Global patcher instance
patcher = MediaUnderstandingPatcher()

def apply_patch(telegram_bot):
    """Apply the media understanding patch"""
    patcher.patch_telegram_handler(telegram_bot)
EOF

log_success "Created media understanding patch file"

# Create initialization script that loads the patch
INIT_FILE="${TELEGRAM_PLUGIN_PATH}/__init_patch__.py"

cat > "$INIT_FILE" << EOF
"""
Auto-loaded patch for Telegram STT workaround
"""

import os
import sys

# Add patch to Python path
patch_path = "${TELEGRAM_PLUGIN_PATH}"
if patch_path not in sys.path:
    sys.path.insert(0, patch_path)

# Import and apply patch
try:
    from media_understanding_patch import apply_patch, patcher
    
    # Set environment variables
    os.environ['FORCE_MEDIA_UNDERSTANDING'] = '${FORCE_MEDIA_UNDERSTANDING:-true}'
    os.environ['WHISPER_MODEL'] = '${WHISPER_MODEL:-base}'
    os.environ['TRANSCRIPTION_PROVIDER'] = '${TRANSCRIPTION_PROVIDER:-deepgram}'
    
    print("[STT-WORKAROUND] Media understanding patch loaded")
except Exception as e:
    print(f"[STT-WORKAROUND] Failed to load patch: {e}")
EOF

log_success "Created patch initialization file"

# Modify the main telegram plugin __init__.py to load our patch
INIT_PY="${TELEGRAM_PLUGIN_PATH}/__init__.py"

if [[ -f "$INIT_PY" ]]; then
    # Check if patch is already imported
    if ! grep -q "__init_patch__" "$INIT_PY" 2>/dev/null; then
        log_info "Patching ${INIT_PY}..."
        
        # Add import at the beginning
        echo "
# OpenClaw Launcher STT Workaround Patch
try:
    from . import __init_patch__
except Exception as _e:
    import logging
    logging.getLogger(__name__).warning(f'Failed to load STT workaround: {_e}')
" >> "$INIT_PY"
        
        log_success "Patched ${INIT_PY}"
    else
        log_info "Patch already applied to ${INIT_PY}"
    fi
else
    log_warn "__init__.py not found at ${INIT_PY}"
fi

# Create environment configuration file
ENV_CONFIG="${TELEGRAM_PLUGIN_PATH}/.stt_env"
cat > "$ENV_CONFIG" << EOF
# Telegram STT Configuration (auto-generated by workaround)
FORCE_MEDIA_UNDERSTANDING=${FORCE_MEDIA_UNDERSTANDING:-true}
WHISPER_MODEL=${WHISPER_MODEL:-base}
TRANSCRIPTION_PROVIDER=${TRANSCRIPTION_PROVIDER:-deepgram}
WHISPER_API_KEY=${WHISPER_API_KEY:-}
EOF

log_success "Telegram STT workaround applied successfully"
log_info "Configuration:"
log_info "  - Force Media Understanding: ${FORCE_MEDIA_UNDERSTANDING:-true}"
log_info "  - Whisper Model: ${WHISPER_MODEL:-base}"
log_info "  - Transcription Provider: ${TRANSCRIPTION_PROVIDER:-deepgram}"
