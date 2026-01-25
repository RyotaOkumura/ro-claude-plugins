#!/bin/bash
#
# setup.sh - Plugin setup script for tk-claude-plugins
#

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Get script directory (repository root)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

info() { echo -e "${GREEN}✓${NC} $1"; }
warn() { echo -e "${YELLOW}!${NC} $1"; }
error() { echo -e "${RED}✗${NC} $1" >&2; }
step() { echo -e "${BLUE}→${NC} $1"; }

# Setup notion-image plugin
setup_notion_image() {
    echo ""
    echo "================================"
    echo " notion-image セットアップ"
    echo "================================"
    echo ""

    CONFIG_DIR="$HOME/.config/notion-image"
    CONFIG_FILE="$CONFIG_DIR/.env"
    BIN_DIR="$HOME/bin"
    SCRIPT_PATH="$REPO_DIR/plugins/notion-image/scripts/upload_to_notion.sh"

    # Step 1: Create config directory
    step "設定ディレクトリを作成..."
    if [[ -d "$CONFIG_DIR" ]]; then
        info "既に存在: $CONFIG_DIR"
    else
        mkdir -p "$CONFIG_DIR"
        chmod 700 "$CONFIG_DIR"
        info "作成完了: $CONFIG_DIR"
    fi

    # Step 2: Create config file template
    step "設定ファイルを作成..."
    if [[ -f "$CONFIG_FILE" ]]; then
        warn "既に存在: $CONFIG_FILE (スキップ)"
    else
        cat > "$CONFIG_FILE" << 'EOF'
# Notion Integration Token
# 取得方法: https://www.notion.so/my-integrations
NOTION_TOKEN=ntn_xxxxxxxxxxxxx

# デフォルトのアップロード先ページID（オプション）
# NotionページURLの末尾32文字（ハイフンなし）
DEFAULT_PAGE_ID=
EOF
        chmod 600 "$CONFIG_FILE"
        info "作成完了: $CONFIG_FILE"
    fi

    # Step 3: Create bin directory and symlink
    step "コマンドをPATHに追加..."
    mkdir -p "$BIN_DIR"

    if [[ -L "$BIN_DIR/notion-upload" ]]; then
        rm "$BIN_DIR/notion-upload"
    fi

    ln -s "$SCRIPT_PATH" "$BIN_DIR/notion-upload"
    chmod +x "$SCRIPT_PATH"
    info "シンボリックリンク作成: $BIN_DIR/notion-upload"

    # Check if ~/bin is in PATH and add to shell config if needed
    if [[ ":$PATH:" != *":$HOME/bin:"* ]]; then
        step "~/bin をPATHに追加..."

        # Determine shell config file
        SHELL_CONFIG="$HOME/.zshrc"
        if [[ "$SHELL" == *"bash"* ]]; then
            SHELL_CONFIG="$HOME/.bashrc"
        fi

        # Check if already in config file
        if grep -q 'export PATH="\$HOME/bin:\$PATH"' "$SHELL_CONFIG" 2>/dev/null; then
            info "既に $SHELL_CONFIG に記載済み（次回ログイン時に有効）"
        else
            echo '' >> "$SHELL_CONFIG"
            echo '# Added by tk-claude-plugins setup' >> "$SHELL_CONFIG"
            echo 'export PATH="$HOME/bin:$PATH"' >> "$SHELL_CONFIG"
            info "$SHELL_CONFIG に追加完了"
            warn "反映するには: source $SHELL_CONFIG"
        fi
    else
        info "~/bin は既にPATHに含まれています"
    fi

    # Manual steps
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo " 残りの手動ステップ"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "1. Notion Integrationを作成:"
    echo "   → https://www.notion.so/my-integrations"
    echo "   → New integration → 名前入力 → Submit"
    echo "   → Capabilities: Read content ✓, Insert content ✓"
    echo ""
    echo "2. トークンを設定ファイルに記入:"
    echo "   # ntn_xxx... をコピーしたトークンに置き換えて実行"
    echo "   echo \"NOTION_TOKEN=ntn_xxxxxxxxxxxxx\" > $CONFIG_FILE"
    echo ""
    echo "3. Notionでページに接続:"
    echo "   → アップロード先ページを開く"
    echo "   → 右上「...」→「接続」→ Integration選択"
    echo ""
    echo "4. テスト:"
    echo "   → notion-upload /path/to/image.png PAGE_ID"
    echo ""
}

# Setup codex plugin
setup_codex() {
    echo ""
    echo "================================"
    echo " codex セットアップ"
    echo "================================"
    echo ""

    # Check if codex is installed
    step "Codex CLIを確認..."
    if command -v codex &> /dev/null; then
        info "インストール済み: $(which codex)"
    else
        warn "Codex CLIがインストールされていません"
        echo ""
        echo "  以下のコマンドでインストール:"
        echo ""
        echo "    npm install -g @openai/codex"
        echo ""
    fi

    # Check OPENAI_API_KEY
    step "OPENAI_API_KEYを確認..."
    if [[ -n "$OPENAI_API_KEY" ]]; then
        info "設定済み"
    else
        warn "OPENAI_API_KEYが設定されていません"
        echo ""
        echo "  以下を ~/.zshrc または ~/.bashrc に追加:"
        echo ""
        echo "    export OPENAI_API_KEY=sk-..."
        echo ""
    fi
}

# Setup all plugins
setup_all() {
    setup_codex
    setup_notion_image
}

# Show usage
usage() {
    echo "Usage: $0 [plugin|all]"
    echo ""
    echo "Plugins:"
    echo "  notion-image  - Notion画像アップロードプラグイン"
    echo "  codex         - Codex CLIレビュープラグイン"
    echo "  all           - すべてのプラグイン"
    echo ""
    echo "Examples:"
    echo "  $0 notion-image"
    echo "  $0 all"
}

# Main
main() {
    if [[ $# -lt 1 ]]; then
        usage
        exit 1
    fi

    case "$1" in
        notion-image)
            setup_notion_image
            ;;
        codex)
            setup_codex
            ;;
        all)
            setup_all
            ;;
        -h|--help)
            usage
            ;;
        *)
            error "Unknown plugin: $1"
            usage
            exit 1
            ;;
    esac

    echo ""
    info "セットアップ完了!"
    echo ""
}

main "$@"
