#!/bin/bash
set -e

CONFIG_FILE="$HOME/.config/codex/.env"
[[ -f "$CONFIG_FILE" ]] && source "$CONFIG_FILE"

SANDBOX="${CODEX_SANDBOX:-read-only}"
PROJECT_DIR="${1:-.}"
PROMPT="$2"

if [[ -z "$PROMPT" ]]; then
    PROMPT="$1"
    PROJECT_DIR="."
fi

codex exec --full-auto --sandbox "$SANDBOX" --cd "$PROJECT_DIR" "$PROMPT"
