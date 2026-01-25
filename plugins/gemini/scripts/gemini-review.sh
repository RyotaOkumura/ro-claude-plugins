#!/bin/bash
set -e

CONFIG_FILE="$HOME/.config/gemini/.env"
[[ -f "$CONFIG_FILE" ]] && source "$CONFIG_FILE"

MODEL="${GEMINI_MODEL:-}"
PROMPT="$*"

if [[ -n "$MODEL" ]]; then
    gemini -m "$MODEL" -p "$PROMPT"
else
    gemini -p "$PROMPT"
fi
