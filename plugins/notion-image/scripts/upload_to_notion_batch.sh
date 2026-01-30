#!/bin/bash
#
# upload_to_notion_batch.sh - Batch upload images to Notion
# Reads a JSON file and uploads multiple images with captions in sequence
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Configuration file path
CONFIG_DIR="${HOME}/.config/notion-image"
CONFIG_FILE="${CONFIG_DIR}/.env"

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Error handling
error() {
    echo -e "${RED}Error: $1${NC}" >&2
    exit 1
}

info() {
    echo -e "${GREEN}$1${NC}"
}

warn() {
    echo -e "${YELLOW}$1${NC}"
}

header() {
    echo -e "${BLUE}$1${NC}"
}

# Load configuration
load_config() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        error "Config file not found: $CONFIG_FILE"
    fi

    set -a
    source "$CONFIG_FILE"
    set +a

    if [[ -z "$NOTION_TOKEN" ]]; then
        error "NOTION_TOKEN not set"
    fi
}

# Check for jq
check_dependencies() {
    if ! command -v jq &> /dev/null; then
        error "jq is required but not installed. Install with: apt install jq"
    fi
}

# Show usage
usage() {
    echo "Usage: $0 <json_file> [page_id] [options]"
    echo ""
    echo "Batch upload images to Notion from a JSON configuration file."
    echo ""
    echo "Arguments:"
    echo "  <json_file>   Path to JSON file with image configurations (required)"
    echo "  [page_id]     Notion page ID (optional, uses DEFAULT_PAGE_ID if not provided)"
    echo ""
    echo "Options:"
    echo "  --after <block_id>   Block ID to insert images after"
    echo "  --dry-run            Show what would be uploaded without uploading"
    echo ""
    echo "JSON file format:"
    echo "  ["
    echo "    {"
    echo "      \"path\": \"/path/to/image1.png\","
    echo "      \"caption\": \"Figure 1: Description\""
    echo "    },"
    echo "    {"
    echo "      \"path\": \"/path/to/image2.png\","
    echo "      \"caption\": \"Figure 2: Description\""
    echo "    }"
    echo "  ]"
    echo ""
    echo "Or simple array format (no captions):"
    echo "  [\"/path/to/image1.png\", \"/path/to/image2.png\"]"
    echo ""
    echo "Examples:"
    echo "  $0 images.json"
    echo "  $0 images.json abc123def456..."
    echo "  $0 images.json page_id --after block_id"
    echo "  $0 images.json page_id --dry-run"
}

# Detect MIME type
get_mime_type() {
    local file="$1"
    local ext="${file##*.}"
    ext=$(echo "$ext" | tr '[:upper:]' '[:lower:]')

    case "$ext" in
        png)  echo "image/png" ;;
        jpg|jpeg) echo "image/jpeg" ;;
        gif)  echo "image/gif" ;;
        webp) echo "image/webp" ;;
        svg)  echo "image/svg+xml" ;;
        *)    echo "" ;;
    esac
}

# Create file upload object
create_file_upload() {
    local filename="$1"
    local content_type="$2"

    local response
    response=$(curl -s -X POST "https://api.notion.com/v1/file_uploads" \
        -H "Authorization: Bearer $NOTION_TOKEN" \
        -H "Notion-Version: 2022-06-28" \
        -H "Content-Type: application/json" \
        -d "{\"mode\": \"single_part\", \"name\": \"$filename\", \"content_type\": \"$content_type\"}")

    local upload_id
    upload_id=$(echo "$response" | jq -r '.id // empty')

    if [[ -z "$upload_id" ]]; then
        echo "API Response: $response" >&2
        return 1
    fi

    echo "$upload_id"
}

# Send file
send_file() {
    local upload_id="$1"
    local file_path="$2"

    local response
    response=$(curl -s -X POST "https://api.notion.com/v1/file_uploads/$upload_id/send" \
        -H "Authorization: Bearer $NOTION_TOKEN" \
        -H "Notion-Version: 2022-06-28" \
        -F "file=@$file_path")

    if echo "$response" | jq -e '.status == "uploaded"' > /dev/null 2>&1; then
        return 0
    else
        echo "API Response: $response" >&2
        return 1
    fi
}

# Attach image to page
attach_image() {
    local page_id="$1"
    local upload_id="$2"
    local after_block_id="$3"

    local json_body
    if [[ -n "$after_block_id" ]]; then
        json_body="{\"after\": \"$after_block_id\", \"children\": [{\"type\": \"image\", \"image\": {\"type\": \"file_upload\", \"file_upload\": {\"id\": \"$upload_id\"}}}]}"
    else
        json_body="{\"children\": [{\"type\": \"image\", \"image\": {\"type\": \"file_upload\", \"file_upload\": {\"id\": \"$upload_id\"}}}]}"
    fi

    local response
    response=$(curl -s -X PATCH "https://api.notion.com/v1/blocks/$page_id/children" \
        -H "Authorization: Bearer $NOTION_TOKEN" \
        -H "Notion-Version: 2022-06-28" \
        -H "Content-Type: application/json" \
        -d "$json_body")

    local block_id
    block_id=$(echo "$response" | jq -r '.results[0].id // empty')

    if [[ -z "$block_id" ]]; then
        echo "API Response: $response" >&2
        return 1
    fi

    echo "$block_id"
}

# Add caption
add_caption() {
    local page_id="$1"
    local caption_text="$2"
    local after_block_id="$3"

    # Escape for JSON using jq
    local escaped_caption
    escaped_caption=$(echo -n "$caption_text" | jq -Rs '.')

    local json_body
    if [[ -n "$after_block_id" ]]; then
        json_body="{\"after\": \"$after_block_id\", \"children\": [{\"type\": \"paragraph\", \"paragraph\": {\"rich_text\": [{\"type\": \"text\", \"text\": {\"content\": $escaped_caption}, \"annotations\": {\"italic\": true, \"color\": \"gray\"}}]}}]}"
    else
        json_body="{\"children\": [{\"type\": \"paragraph\", \"paragraph\": {\"rich_text\": [{\"type\": \"text\", \"text\": {\"content\": $escaped_caption}, \"annotations\": {\"italic\": true, \"color\": \"gray\"}}]}}]}"
    fi

    local response
    response=$(curl -s -X PATCH "https://api.notion.com/v1/blocks/$page_id/children" \
        -H "Authorization: Bearer $NOTION_TOKEN" \
        -H "Notion-Version: 2022-06-28" \
        -H "Content-Type: application/json" \
        -d "$json_body")

    local block_id
    block_id=$(echo "$response" | jq -r '.results[0].id // empty')

    if [[ -z "$block_id" ]]; then
        echo "API Response: $response" >&2
        return 1
    fi

    echo "$block_id"
}

# Upload single image with caption
# Note: All info/warn output goes to stderr, only block_id goes to stdout
upload_single() {
    local file_path="$1"
    local page_id="$2"
    local after_block_id="$3"
    local caption="$4"

    # Validate file
    if [[ ! -f "$file_path" ]]; then
        warn "  File not found: $file_path (skipping)" >&2
        echo "$after_block_id"
        return 0
    fi

    local content_type
    content_type=$(get_mime_type "$file_path")
    if [[ -z "$content_type" ]]; then
        warn "  Unsupported file type: $file_path (skipping)" >&2
        echo "$after_block_id"
        return 0
    fi

    local filename
    filename=$(basename "$file_path")

    # Step 1: Create upload object
    local upload_id
    upload_id=$(create_file_upload "$filename" "$content_type")
    if [[ -z "$upload_id" ]]; then
        warn "  Failed to create upload object for: $file_path" >&2
        echo "$after_block_id"
        return 0
    fi

    # Step 2: Send file
    if ! send_file "$upload_id" "$file_path"; then
        warn "  Failed to send file: $file_path" >&2
        echo "$after_block_id"
        return 0
    fi

    # Step 3: Attach to page
    local block_id
    block_id=$(attach_image "$page_id" "$upload_id" "$after_block_id")
    if [[ -z "$block_id" ]]; then
        warn "  Failed to attach image: $file_path" >&2
        echo "$after_block_id"
        return 0
    fi

    info "  -> Uploaded: $filename (block: ${block_id:0:8}...)" >&2

    # Step 4: Add caption if provided
    if [[ -n "$caption" ]]; then
        local caption_block_id
        caption_block_id=$(add_caption "$page_id" "$caption" "$block_id")
        if [[ -n "$caption_block_id" ]]; then
            info "  -> Caption: $caption" >&2
            echo "$caption_block_id"
            return 0
        fi
    fi

    echo "$block_id"
}

# Main batch upload function
batch_upload() {
    local json_file="$1"
    local page_id="$2"
    local after_block_id="$3"
    local dry_run="$4"

    # Validate JSON file
    if [[ ! -f "$json_file" ]]; then
        error "JSON file not found: $json_file"
    fi

    # Parse JSON
    local json_content
    json_content=$(cat "$json_file")

    # Detect JSON format (array of objects or array of strings)
    local is_simple_array
    is_simple_array=$(echo "$json_content" | jq -r 'if type == "array" and (.[0] | type) == "string" then "true" else "false" end')

    local count
    count=$(echo "$json_content" | jq -r 'length')

    header "=========================================="
    header "Batch Upload: $count images"
    header "=========================================="
    echo ""

    if [[ "$dry_run" == "true" ]]; then
        warn "[DRY RUN] No images will be uploaded"
        echo ""
    fi

    local current_after="$after_block_id"
    local success_count=0
    local fail_count=0

    for ((i=0; i<count; i++)); do
        local file_path
        local caption=""

        if [[ "$is_simple_array" == "true" ]]; then
            file_path=$(echo "$json_content" | jq -r ".[$i]")
        else
            file_path=$(echo "$json_content" | jq -r ".[$i].path")
            caption=$(echo "$json_content" | jq -r ".[$i].caption // empty")
        fi

        header "[$((i+1))/$count] $file_path"

        if [[ "$dry_run" == "true" ]]; then
            info "  Would upload: $file_path"
            if [[ -n "$caption" ]]; then
                info "  With caption: $caption"
            fi
            continue
        fi

        # Upload and get the new block ID for chaining
        local new_block_id
        new_block_id=$(upload_single "$file_path" "$page_id" "$current_after" "$caption")

        if [[ -n "$new_block_id" && "$new_block_id" != "$current_after" ]]; then
            current_after="$new_block_id"
            ((success_count++)) || true
        else
            ((fail_count++)) || true
        fi

        echo ""
    done

    header "=========================================="
    if [[ "$dry_run" == "true" ]]; then
        info "Dry run complete. $count images would be uploaded."
    else
        info "Batch upload complete!"
        info "  Success: $success_count"
        if [[ $fail_count -gt 0 ]]; then
            warn "  Failed:  $fail_count"
        fi
    fi
    header "=========================================="
}

# Main entry point
main() {
    if [[ $# -lt 1 ]]; then
        usage
        exit 1
    fi

    check_dependencies
    load_config

    local json_file=""
    local page_id=""
    local after_block_id=""
    local dry_run="false"

    # Parse arguments
    local positional_args=()
    while [[ $# -gt 0 ]]; do
        case $1 in
            --after)
                after_block_id="$2"
                shift 2
                ;;
            --dry-run)
                dry_run="true"
                shift
                ;;
            --help|-h)
                usage
                exit 0
                ;;
            -*)
                error "Unknown option: $1"
                ;;
            *)
                positional_args+=("$1")
                shift
                ;;
        esac
    done

    # Extract positional arguments
    if [[ ${#positional_args[@]} -ge 1 ]]; then
        json_file="${positional_args[0]}"
    fi
    if [[ ${#positional_args[@]} -ge 2 ]]; then
        page_id="${positional_args[1]}"
    else
        page_id="$DEFAULT_PAGE_ID"
    fi

    # Validate
    if [[ -z "$json_file" ]]; then
        usage
        exit 1
    fi

    if [[ -z "$page_id" ]]; then
        error "No page_id provided and DEFAULT_PAGE_ID not set"
    fi

    batch_upload "$json_file" "$page_id" "$after_block_id" "$dry_run"
}

main "$@"
