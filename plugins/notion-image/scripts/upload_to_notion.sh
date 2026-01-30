#!/bin/bash
#
# upload_to_notion.sh - Upload images directly to Notion using File Uploads API
# Simple approach: No external storage needed (no R2, S3, etc.)
#

set -e

# Configuration file path
CONFIG_DIR="${HOME}/.config/notion-image"
CONFIG_FILE="${CONFIG_DIR}/.env"

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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

# Load configuration
load_config() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        error "Config file not found: $CONFIG_FILE
Please create it with the following variables:
  NOTION_TOKEN=ntn_xxxxxxxxxxxxx

Optionally:
  DEFAULT_PAGE_ID=your_default_page_id"
    fi

    # Source the config file
    set -a
    source "$CONFIG_FILE"
    set +a

    # Validate required variables
    if [[ -z "$NOTION_TOKEN" ]]; then
        error "NOTION_TOKEN not set"
    fi
}

# Detect MIME type from file extension
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
        *)    error "Unsupported file type: .$ext (supported: png, jpg, jpeg, gif, webp, svg)" ;;
    esac
}

# Step 1: Create file upload object
create_file_upload() {
    local filename="$1"
    local content_type="$2"

    local response
    response=$(curl -s -X POST "https://api.notion.com/v1/file_uploads" \
        -H "Authorization: Bearer $NOTION_TOKEN" \
        -H "Notion-Version: 2022-06-28" \
        -H "Content-Type: application/json" \
        -d "{\"mode\": \"single_part\", \"name\": \"$filename\", \"content_type\": \"$content_type\"}")

    # Extract ID from response
    local upload_id
    upload_id=$(echo "$response" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)

    if [[ -z "$upload_id" ]]; then
        echo "API Response: $response" >&2
        error "Failed to create file upload object"
    fi

    echo "$upload_id"
}

# Step 2: Send file to upload object
send_file() {
    local upload_id="$1"
    local file_path="$2"

    local response
    response=$(curl -s -X POST "https://api.notion.com/v1/file_uploads/$upload_id/send" \
        -H "Authorization: Bearer $NOTION_TOKEN" \
        -H "Notion-Version: 2022-06-28" \
        -F "file=@$file_path")

    # Check for error
    if echo "$response" | grep -q '"status":"uploaded"'; then
        return 0
    else
        echo "API Response: $response" >&2
        error "Failed to send file"
    fi
}

# Step 3: Attach image to page (returns the created block ID)
attach_to_page() {
    local page_id="$1"
    local upload_id="$2"
    local after_block_id="$3"

    local json_body
    if [[ -n "$after_block_id" ]]; then
        # Insert after specific block
        json_body="{\"after\": \"$after_block_id\", \"children\": [{\"type\": \"image\", \"image\": {\"type\": \"file_upload\", \"file_upload\": {\"id\": \"$upload_id\"}}}]}"
    else
        # Append to end (default behavior)
        json_body="{\"children\": [{\"type\": \"image\", \"image\": {\"type\": \"file_upload\", \"file_upload\": {\"id\": \"$upload_id\"}}}]}"
    fi

    local response
    response=$(curl -s -X PATCH "https://api.notion.com/v1/blocks/$page_id/children" \
        -H "Authorization: Bearer $NOTION_TOKEN" \
        -H "Notion-Version: 2022-06-28" \
        -H "Content-Type: application/json" \
        -d "$json_body")

    # Check for error and extract block ID
    if echo "$response" | grep -q '"results"'; then
        # Extract the created block ID for chaining
        local block_id
        block_id=$(echo "$response" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)
        echo "$block_id"
        return 0
    else
        echo "API Response: $response" >&2
        error "Failed to attach image to page"
    fi
}

# Add caption text block after image
add_caption() {
    local page_id="$1"
    local caption_text="$2"
    local after_block_id="$3"

    # Escape special characters in caption for JSON
    local escaped_caption
    escaped_caption=$(echo "$caption_text" | sed 's/\\/\\\\/g; s/"/\\"/g; s/\t/\\t/g')

    local json_body
    if [[ -n "$after_block_id" ]]; then
        json_body="{\"after\": \"$after_block_id\", \"children\": [{\"type\": \"paragraph\", \"paragraph\": {\"rich_text\": [{\"type\": \"text\", \"text\": {\"content\": \"$escaped_caption\"}}]}}]}"
    else
        json_body="{\"children\": [{\"type\": \"paragraph\", \"paragraph\": {\"rich_text\": [{\"type\": \"text\", \"text\": {\"content\": \"$escaped_caption\"}}]}}]}"
    fi

    local response
    response=$(curl -s -X PATCH "https://api.notion.com/v1/blocks/$page_id/children" \
        -H "Authorization: Bearer $NOTION_TOKEN" \
        -H "Notion-Version: 2022-06-28" \
        -H "Content-Type: application/json" \
        -d "$json_body")

    # Check for error and return block ID
    if echo "$response" | grep -q '"results"'; then
        local block_id
        block_id=$(echo "$response" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)
        echo "$block_id"
        return 0
    else
        echo "API Response: $response" >&2
        error "Failed to add caption"
    fi
}

# Main upload function
upload_to_notion() {
    local local_file="$1"
    local page_id="$2"
    local after_block_id="$3"
    local caption="$4"

    # Validate file exists
    [[ ! -f "$local_file" ]] && error "File not found: $local_file"

    # Get MIME type (validates file type)
    local content_type
    content_type=$(get_mime_type "$local_file")

    info "Uploading: $local_file"
    info "  -> Content-Type: $content_type"

    # Step 1: Create upload object
    local steps_total=3
    [[ -n "$caption" ]] && steps_total=4

    info "Step 1/$steps_total: Creating upload object..."
    local filename
    filename=$(basename "$local_file")
    local upload_id
    upload_id=$(create_file_upload "$filename" "$content_type")
    info "  -> Upload ID: $upload_id"

    # Step 2: Send file
    info "Step 2/$steps_total: Sending file..."
    send_file "$upload_id" "$local_file"
    info "  -> File sent successfully"

    # Step 3: Attach to page (if page_id provided)
    local image_block_id=""
    local caption_block_id=""
    if [[ -n "$page_id" ]]; then
        # If caption is provided, add it first (above the image)
        if [[ -n "$caption" ]]; then
            info "Step 3/$steps_total: Adding caption (above image)..."
            caption_block_id=$(add_caption "$page_id" "$caption" "$after_block_id")
            info "  -> Caption added: $caption"
            info "  -> Caption block ID: $caption_block_id"

            # Image will be inserted after the caption
            info "Step 4/$steps_total: Attaching image..."
            image_block_id=$(attach_to_page "$page_id" "$upload_id" "$caption_block_id")
        else
            info "Step 3/$steps_total: Attaching to page..."
            image_block_id=$(attach_to_page "$page_id" "$upload_id" "$after_block_id")
        fi

        if [[ -n "$after_block_id" ]]; then
            info "  -> Inserted after block: $after_block_id"
        else
            info "  -> Appended to page: $page_id"
        fi
        info "  -> Image block ID: $image_block_id"
    else
        warn "Step 3/$steps_total: Skipped (no page_id provided)"
        echo ""
        info "To attach later, use:"
        echo "  Upload ID: $upload_id"
        echo ""
        warn "Note: Upload expires in 1 hour if not attached!"
    fi

    echo ""
    info "Upload successful!"

    # Output the last block ID for chaining (always image, since caption is above)
    if [[ -n "$image_block_id" ]]; then
        echo "LAST_BLOCK_ID=$image_block_id"
    fi
}

# Show usage
usage() {
    echo "Usage: $0 <image_file_path> [page_id] [options]"
    echo ""
    echo "Uploads an image directly to Notion using the File Uploads API."
    echo ""
    echo "Arguments:"
    echo "  <image_file_path>  Path to the image file (required)"
    echo "  [page_id]          Notion page ID to attach the image (optional)"
    echo "                     If not provided, uses DEFAULT_PAGE_ID from config"
    echo ""
    echo "Options:"
    echo "  --after <block_id>   Block ID to insert the image after"
    echo "  --caption <text>     Caption text to add below the image"
    echo ""
    echo "Supported formats: png, jpg, jpeg, gif, webp, svg"
    echo ""
    echo "Examples:"
    echo "  $0 /path/to/image.png"
    echo "  $0 /path/to/image.png abc123def456..."
    echo "  $0 /path/to/image.png page_id --caption 'Figure 1: Results'"
    echo "  $0 /path/to/image.png page_id --after block_id --caption 'Figure 1'"
}

# Main entry point
main() {
    if [[ $# -lt 1 ]]; then
        usage
        exit 1
    fi

    load_config

    local file_path=""
    local page_id=""
    local after_block_id=""
    local caption=""

    # Parse arguments
    local positional_args=()
    while [[ $# -gt 0 ]]; do
        case $1 in
            --after)
                after_block_id="$2"
                shift 2
                ;;
            --caption)
                caption="$2"
                shift 2
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
        file_path="${positional_args[0]}"
    fi
    if [[ ${#positional_args[@]} -ge 2 ]]; then
        page_id="${positional_args[1]}"
    else
        page_id="$DEFAULT_PAGE_ID"
    fi

    # Validate file_path
    if [[ -z "$file_path" ]]; then
        usage
        exit 1
    fi

    upload_to_notion "$file_path" "$page_id" "$after_block_id" "$caption"
}

main "$@"
