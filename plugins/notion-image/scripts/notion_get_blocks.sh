#!/bin/bash
#
# notion_get_blocks.sh - Get block IDs from a Notion page
# Helper command to find block IDs for --after option
#

set -e

# Configuration file path
CONFIG_DIR="${HOME}/.config/notion-image"
CONFIG_FILE="${CONFIG_DIR}/.env"

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Error handling
error() {
    echo -e "${RED}Error: $1${NC}" >&2
    exit 1
}

info() {
    echo -e "${GREEN}$1${NC}"
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
        error "NOTION_TOKEN not set in $CONFIG_FILE"
    fi
}

# Get blocks from a page
get_blocks() {
    local page_id="$1"
    local start_cursor="$2"

    local url="https://api.notion.com/v1/blocks/$page_id/children?page_size=100"
    if [[ -n "$start_cursor" ]]; then
        url="${url}&start_cursor=$start_cursor"
    fi

    curl -s -X GET "$url" \
        -H "Authorization: Bearer $NOTION_TOKEN" \
        -H "Notion-Version: 2022-06-28"
}

# Extract text content from rich_text array
extract_text() {
    local json="$1"
    echo "$json" | grep -o '"plain_text":"[^"]*"' | head -1 | cut -d'"' -f4
}

# Parse and display blocks
parse_blocks() {
    local response="$1"
    local indent="$2"

    # Check for error
    if echo "$response" | grep -q '"object":"error"'; then
        local message
        message=$(echo "$response" | grep -o '"message":"[^"]*"' | cut -d'"' -f4)
        error "API Error: $message"
    fi

    # Parse results using grep/sed (avoiding jq dependency)
    local results
    results=$(echo "$response" | grep -o '"results":\[.*\]' | sed 's/"results"://' | sed 's/,"next_cursor".*//' | sed 's/,"has_more".*//')

    # Extract individual blocks
    local i=0
    while true; do
        # Find each block object
        local block
        block=$(echo "$response" | grep -o '{[^{}]*"object":"block"[^{}]*}' | sed -n "$((i+1))p")

        if [[ -z "$block" ]]; then
            # Try alternative parsing for nested objects
            break
        fi

        local block_id block_type
        block_id=$(echo "$block" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)
        block_type=$(echo "$block" | grep -o '"type":"[^"]*"' | head -1 | cut -d'"' -f4)

        if [[ -n "$block_id" && -n "$block_type" ]]; then
            printf "${indent}${CYAN}%-36s${NC}  ${YELLOW}%-15s${NC}" "$block_id" "[$block_type]"

            # Try to extract text content for common block types
            case "$block_type" in
                paragraph|heading_1|heading_2|heading_3|bulleted_list_item|numbered_list_item|quote|callout)
                    local text
                    text=$(extract_text "$block")
                    if [[ -n "$text" ]]; then
                        # Truncate long text
                        if [[ ${#text} -gt 50 ]]; then
                            text="${text:0:50}..."
                        fi
                        printf "  %s" "$text"
                    fi
                    ;;
                image)
                    printf "  [image]"
                    ;;
                code)
                    printf "  [code block]"
                    ;;
                divider)
                    printf "  ---"
                    ;;
            esac
            echo ""
        fi

        ((i++))
        [[ $i -gt 200 ]] && break  # Safety limit
    done

    # Check for more results
    if echo "$response" | grep -q '"has_more":true'; then
        local next_cursor
        next_cursor=$(echo "$response" | grep -o '"next_cursor":"[^"]*"' | cut -d'"' -f4)
        if [[ -n "$next_cursor" ]]; then
            echo ""
            info "Fetching more blocks..."
            local more_response
            more_response=$(get_blocks "$1" "$next_cursor")
            parse_blocks "$more_response" "$indent"
        fi
    fi
}

# Alternative simpler parsing using Python if available
parse_blocks_python() {
    local page_id="$1"

    python3 << EOF
import json
import subprocess
import os

# Load config
config_path = os.path.expanduser("~/.config/notion-image/.env")
token = None
with open(config_path) as f:
    for line in f:
        if line.startswith("NOTION_TOKEN="):
            token = line.strip().split("=", 1)[1]
            break

if not token:
    print("Error: NOTION_TOKEN not found")
    exit(1)

def get_blocks(page_id, cursor=None):
    import urllib.request
    url = f"https://api.notion.com/v1/blocks/{page_id}/children?page_size=100"
    if cursor:
        url += f"&start_cursor={cursor}"

    req = urllib.request.Request(url)
    req.add_header("Authorization", f"Bearer {token}")
    req.add_header("Notion-Version", "2022-06-28")

    with urllib.request.urlopen(req) as resp:
        return json.loads(resp.read())

def extract_text(rich_text):
    if not rich_text:
        return ""
    return "".join(t.get("plain_text", "") for t in rich_text)[:50]

def print_blocks(page_id, indent=""):
    try:
        data = get_blocks(page_id)
    except Exception as e:
        print(f"Error: {e}")
        return

    for block in data.get("results", []):
        block_id = block.get("id", "")
        block_type = block.get("type", "")

        text = ""
        if block_type in data.get(block_type, {}):
            content = block.get(block_type, {})
            if "rich_text" in content:
                text = extract_text(content["rich_text"])

        # Get text for various block types
        content = block.get(block_type, {})
        if isinstance(content, dict) and "rich_text" in content:
            text = extract_text(content["rich_text"])

        text_display = f"  {text}" if text else ""
        if block_type == "image":
            text_display = "  [image]"
        elif block_type == "code":
            text_display = "  [code block]"
        elif block_type == "divider":
            text_display = "  ---"

        print(f"{indent}\033[0;36m{block_id}\033[0m  \033[1;33m[{block_type:15}]\033[0m{text_display}")

    if data.get("has_more") and data.get("next_cursor"):
        print("\nFetching more...")
        # Would need to handle pagination

print_blocks("$page_id")
EOF
}

# Show usage
usage() {
    echo "Usage: $0 <page_id> [options]"
    echo ""
    echo "Get block IDs from a Notion page for use with --after option."
    echo ""
    echo "Arguments:"
    echo "  <page_id>     Notion page ID"
    echo ""
    echo "Options:"
    echo "  --simple      Simple output (ID only, one per line)"
    echo "  --help, -h    Show this help"
    echo ""
    echo "Examples:"
    echo "  $0 abc123def456"
    echo "  $0 abc123def456 --simple"
    echo ""
    echo "Then use the block ID with notion-upload:"
    echo "  notion-upload image.png PAGE_ID --after BLOCK_ID"
}

# Main
main() {
    if [[ $# -lt 1 || "$1" == "--help" || "$1" == "-h" ]]; then
        usage
        exit 0
    fi

    load_config

    local page_id="$1"
    local simple_mode=false

    if [[ "$2" == "--simple" ]]; then
        simple_mode=true
    fi

    info "Fetching blocks from page: $page_id"
    echo ""

    # Use Python for better JSON parsing if available
    if command -v python3 &> /dev/null; then
        parse_blocks_python "$page_id"
    else
        local response
        response=$(get_blocks "$page_id")
        parse_blocks "$response" ""
    fi

    echo ""
    info "Use block ID with: notion-upload image.png PAGE_ID --after BLOCK_ID"
}

main "$@"
