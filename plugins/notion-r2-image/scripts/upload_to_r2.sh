#!/bin/bash
#
# upload_to_r2.sh - Upload images to Cloudflare R2 using AWS Signature V4
# No AWS CLI required - pure bash + curl + openssl implementation
#

set -e

# Configuration file path
CONFIG_DIR="${HOME}/.config/notion-r2-image"
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
  R2_ACCESS_KEY_ID=your_access_key
  R2_SECRET_ACCESS_KEY=your_secret_key
  R2_BUCKET_NAME=your_bucket_name
  R2_ACCOUNT_ID=your_account_id
  WORKERS_PROXY_URL=https://your-worker.workers.dev
  WORKERS_AUTH_TOKEN=your_secret_token"
    fi

    # Source the config file
    set -a
    source "$CONFIG_FILE"
    set +a

    # Validate required variables
    [[ -z "$R2_ACCESS_KEY_ID" ]] && error "R2_ACCESS_KEY_ID not set"
    [[ -z "$R2_SECRET_ACCESS_KEY" ]] && error "R2_SECRET_ACCESS_KEY not set"
    [[ -z "$R2_BUCKET_NAME" ]] && error "R2_BUCKET_NAME not set"
    [[ -z "$R2_ACCOUNT_ID" ]] && error "R2_ACCOUNT_ID not set"
    [[ -z "$WORKERS_PROXY_URL" ]] && error "WORKERS_PROXY_URL not set"
    [[ -z "$WORKERS_AUTH_TOKEN" ]] && error "WORKERS_AUTH_TOKEN not set"
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

# Generate timestamp-based unique filename
generate_remote_path() {
    local original_name="$1"
    local timestamp=$(date +"%Y%m%d_%H%M%S")
    local basename=$(basename "$original_name")
    # Sanitize filename: replace spaces with underscores, remove special chars
    basename=$(echo "$basename" | tr ' ' '_' | tr -cd '[:alnum:]._-')
    echo "images/${timestamp}_${basename}"
}

# SHA256 hash of file
sha256_hash_file() {
    local file="$1"
    openssl dgst -sha256 -binary "$file" | xxd -p -c 256
}

# AWS Signature V4 signing
sign_and_upload() {
    local local_file="$1"
    local remote_path="$2"
    local content_type="$3"

    # R2 endpoint configuration
    local host="${R2_ACCOUNT_ID}.r2.cloudflarestorage.com"
    local endpoint="https://${host}/${R2_BUCKET_NAME}/${remote_path}"
    local region="auto"  # R2 uses 'auto' as region
    local service="s3"

    # Timestamps
    local amz_date=$(date -u +"%Y%m%dT%H%M%SZ")
    local date_stamp=$(date -u +"%Y%m%d")

    # Calculate payload hash
    local payload_hash=$(sha256_hash_file "$local_file")

    # Canonical URI (URL-encoded path)
    local canonical_uri="/${R2_BUCKET_NAME}/${remote_path}"

    # Canonical query string (empty for PUT)
    local canonical_querystring=""

    # Signed headers (must be sorted alphabetically)
    local signed_headers="content-type;host;x-amz-content-sha256;x-amz-date"

    # Canonical request
    local canonical_request="PUT
${canonical_uri}
${canonical_querystring}
content-type:${content_type}
host:${host}
x-amz-content-sha256:${payload_hash}
x-amz-date:${amz_date}

${signed_headers}
${payload_hash}"

    # Hash of canonical request
    local canonical_request_hash=$(printf '%s' "$canonical_request" | openssl dgst -sha256 | sed 's/^.* //')

    # Credential scope
    local credential_scope="${date_stamp}/${region}/${service}/aws4_request"

    # String to sign
    local string_to_sign="AWS4-HMAC-SHA256
${amz_date}
${credential_scope}
${canonical_request_hash}"

    # Signing key derivation
    local k_secret="AWS4${R2_SECRET_ACCESS_KEY}"
    local k_date=$(printf '%s' "$date_stamp" | openssl dgst -sha256 -mac HMAC -macopt "key:${k_secret}" -binary | xxd -p -c 256)
    local k_region=$(printf '%s' "$region" | openssl dgst -sha256 -mac HMAC -macopt "hexkey:${k_date}" -binary | xxd -p -c 256)
    local k_service=$(printf '%s' "$service" | openssl dgst -sha256 -mac HMAC -macopt "hexkey:${k_region}" -binary | xxd -p -c 256)
    local k_signing=$(printf '%s' "aws4_request" | openssl dgst -sha256 -mac HMAC -macopt "hexkey:${k_service}" -binary | xxd -p -c 256)

    # Final signature
    local signature=$(printf '%s' "$string_to_sign" | openssl dgst -sha256 -mac HMAC -macopt "hexkey:${k_signing}" | sed 's/^.* //')

    # Authorization header
    local authorization="AWS4-HMAC-SHA256 Credential=${R2_ACCESS_KEY_ID}/${credential_scope}, SignedHeaders=${signed_headers}, Signature=${signature}"

    # Execute upload with curl
    local response_file=$(mktemp)
    local http_code
    http_code=$(curl -s -o "$response_file" -w "%{http_code}" \
        -X PUT \
        -H "Host: ${host}" \
        -H "Content-Type: ${content_type}" \
        -H "X-Amz-Content-Sha256: ${payload_hash}" \
        -H "X-Amz-Date: ${amz_date}" \
        -H "Authorization: ${authorization}" \
        --data-binary "@${local_file}" \
        "$endpoint")

    local response_body=$(cat "$response_file")
    rm -f "$response_file"

    if [[ "$http_code" == "200" ]] || [[ "$http_code" == "201" ]]; then
        return 0
    else
        echo "HTTP $http_code: $response_body" >&2
        return 1
    fi
}

# Main upload function
upload_to_r2() {
    local local_file="$1"

    # Validate file exists
    [[ ! -f "$local_file" ]] && error "File not found: $local_file"

    # Get MIME type
    local content_type=$(get_mime_type "$local_file")

    # Generate remote path with timestamp
    local remote_path=$(generate_remote_path "$local_file")

    info "Uploading: $local_file"
    info "  -> Remote: $remote_path"
    info "  -> Content-Type: $content_type"

    # Execute upload
    if sign_and_upload "$local_file" "$remote_path" "$content_type"; then
        info "Upload successful!"

        # Generate the proxy URL with auth token
        local proxy_url="${WORKERS_PROXY_URL}/${remote_path}?token=${WORKERS_AUTH_TOKEN}"

        echo ""
        info "Notion URL:"
        echo "$proxy_url"
    else
        error "Upload failed"
    fi
}

# Main entry point
main() {
    if [[ $# -lt 1 ]]; then
        echo "Usage: $0 <image_file_path>"
        echo ""
        echo "Uploads an image to Cloudflare R2 and returns a Notion-embeddable URL."
        echo ""
        echo "Supported formats: png, jpg, jpeg, gif, webp, svg"
        exit 1
    fi

    load_config
    upload_to_r2 "$1"
}

main "$@"
