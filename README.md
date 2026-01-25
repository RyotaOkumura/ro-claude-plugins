# tk-claude-plugins

Claude Code plugins collection.

## Quick Start

```bash
# リポジトリをクローン
git clone https://github.com/your-username/tk-claude-plugins.git
cd tk-claude-plugins

# 全プラグインをセットアップ
./scripts/setup.sh all

# または個別にセットアップ
./scripts/setup.sh notion-image
./scripts/setup.sh codex
```

セットアップスクリプトが自動で:
- 設定ディレクトリ作成
- 設定ファイルテンプレート作成
- コマンドのPATH追加
- 残りの手動ステップを案内

---

## Plugins

### 1. codex

Codex CLI を使ったコードレビュー・相談スキル。

**機能:**
- コードレビュー
- 実装方針の相談
- バグの調査
- リファクタリング提案

**セットアップ:**
```bash
./scripts/setup.sh codex
```

**手動ステップ:**

1. **Codex CLIをインストール**
   ```bash
   npm install -g @openai/codex
   ```

2. **APIキーを設定**
   ```bash
   echo 'export OPENAI_API_KEY=sk-xxx' >> ~/.zshrc
   source ~/.zshrc
   ```

**使用例:**
```bash
codex exec --full-auto --sandbox read-only --cd /path/to/project "このコードをレビューして"
```

---

### 2. notion-image

Notionに画像を直接アップロードするスキル（Notion File Uploads API使用）。

**機能:**
- ローカル画像をNotion APIで直接アップロード
- 指定したNotionページに画像ブロックとして追加
- 外部ストレージ不要（R2, S3等は不要）

**アーキテクチャ:**
```
┌─────────────────┐     ┌──────────────────┐     ┌─────────────────┐
│  Claude Code    │────>│  notion-upload   │────>│   Notion API    │
│                 │     │                  │     │ (File Uploads)  │
└─────────────────┘     └──────────────────┘     └────────┬────────┘
                                                          │
                                                 ┌────────▼────────┐
                                                 │  Notion Page    │
                                                 │  (画像ブロック)  │
                                                 └─────────────────┘
```

**セットアップ:**
```bash
./scripts/setup.sh notion-image
```

**手動ステップ:**

1. **Notion Integrationを作成**
   - https://www.notion.so/my-integrations にアクセス
   - 「New integration」→ 名前入力 → Submit
   - Capabilities: Read content ✅, Insert content ✅
   - トークン（`ntn_xxx...`）をコピー

2. **トークンを設定ファイルに記入**
   ```bash
   # ntn_xxx... の部分をコピーしたトークンに置き換えて実行
   echo "NOTION_TOKEN=ntn_xxxxxxxxxxxxx" > ~/.config/notion-image/.env
   ```

3. **Notionでページに接続**
   - アップロード先ページを開く → 右上「...」→「接続」→ Integration選択

**使用例:**
```bash
notion-upload /tmp/screenshot.png PAGE_ID
```

**制限事項:**
- ファイルサイズ: 20MB以下
- 対応形式: png, jpg, jpeg, gif, webp, svg
- アップロード後1時間以内にページに添付必要

**コスト:** 無料（Notion API追加料金なし）

---

## Claude Codeへの登録

`~/.claude/settings.json` に追加:

```json
{
  "plugins": [
    "/path/to/tk-claude-plugins"
  ]
}
```

または、プロジェクトの `CLAUDE.md` に追記:

```markdown
## Skills

- /path/to/tk-claude-plugins/plugins/codex
- /path/to/tk-claude-plugins/plugins/notion-image
```

## Usage

Claude Codeで以下のように使用:

```
# codex
「このコードをレビューして」

# notion-image
「この画像をNotionにアップロードして」
/notion-image /path/to/image.png PAGE_ID
```

## License

MIT
