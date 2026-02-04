#!/bin/bash
#
# md_to_notion_images.sh - Markdown内の画像をNotionにアップロード
#
# Usage: md-to-notion-images <markdown_file> <page_id> [options]
#
# Options:
#   --replace-placeholder  プレースホルダーを検索して置換
#   --dry-run              アップロードせず確認のみ
#

set -e

# Ensure ~/bin is in PATH (for jq, notion-upload, etc.)
export PATH="$HOME/bin:$PATH"

# Resolve symlinks to get the actual script directory
SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do
    DIR="$(cd "$(dirname "$SOURCE")" && pwd)"
    SOURCE="$(readlink "$SOURCE")"
    [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE"
done
SCRIPT_DIR="$(cd "$(dirname "$SOURCE")" && pwd)"

# notion-image plugin directory
NOTION_IMAGE_DIR="$(dirname "$SCRIPT_DIR")/../notion-image/scripts"

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

error() {
    echo -e "${RED}Error: $1${NC}" >&2
    exit 1
}

info() {
    echo -e "${GREEN}$1${NC}"
}

# Show usage
usage() {
    echo "Usage: md-to-notion-images <markdown_file> <page_id> [options]"
    echo ""
    echo "Upload images from a Markdown file to Notion."
    echo ""
    echo "Arguments:"
    echo "  <markdown_file>  Path to the Markdown file"
    echo "  <page_id>        Notion page ID"
    echo ""
    echo "Options:"
    echo "  --replace-placeholder  Find and replace [画像: filename] placeholders"
    echo "  --dry-run              Show what would be uploaded without uploading"
    echo "  --help, -h             Show this help"
}

# Main
main() {
    if [[ $# -lt 1 || "$1" == "--help" || "$1" == "-h" ]]; then
        usage
        exit 0
    fi

    if [[ $# -lt 2 ]]; then
        error "Missing arguments. Use --help for usage."
    fi

    local md_file="$1"
    local page_id="$2"
    shift 2

    # Validate markdown file
    if [[ ! -f "$md_file" ]]; then
        error "Markdown file not found: $md_file"
    fi

    info "Extracting images from: $md_file"

    # Create temp file for image list
    local tmp_json
    tmp_json=$(mktemp /tmp/md_images_XXXXXX.json)
    trap "rm -f $tmp_json" EXIT

    # Extract images
    python3 "$SCRIPT_DIR/md_extract_images.py" "$md_file" > "$tmp_json"

    # Count images
    local count
    count=$(python3 -c "import json; print(len(json.load(open('$tmp_json'))))")

    if [[ "$count" -eq 0 ]]; then
        info "No images found in Markdown file."
        exit 0
    fi

    info "Found $count images"

    # Call notion-image batch upload
    if [[ -f "$NOTION_IMAGE_DIR/upload_to_notion_batch.sh" ]]; then
        "$NOTION_IMAGE_DIR/upload_to_notion_batch.sh" "$tmp_json" "$page_id" "$@"
    else
        error "notion-image plugin not found at: $NOTION_IMAGE_DIR"
    fi
}

main "$@"
