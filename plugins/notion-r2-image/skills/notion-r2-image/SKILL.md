---
name: notion-r2-image
description: 画像をCloudflare R2にアップロードし、Notion埋め込み用URLを取得する。使用場面: (1) Notionに画像を追加したい時、(2) スクリーンショットを共有したい時、(3) 画像URLが必要な時。トリガー: "notion画像", "画像アップロード", "r2", "/notion-image"
---

# Notion R2 Image Upload

画像ファイルをCloudflare R2（プライベートバケット）にアップロードし、
Cloudflare Workers経由でトークン認証付きアクセス可能なURLを返すスキル。

## 前提条件

- **設定ファイル** が存在すること
  - パス: `~/.config/notion-r2-image/.env`
  - 必須変数: `R2_ACCESS_KEY_ID`, `R2_SECRET_ACCESS_KEY`, `R2_BUCKET_NAME`, `R2_ACCOUNT_ID`, `WORKERS_PROXY_URL`, `WORKERS_AUTH_TOKEN`

- **依存ツール** がインストールされていること
  - `openssl` (macOS標準またはbrew install openssl)
  - `curl`
  - `xxd` (macOS標準)

- **Cloudflare Workers** がデプロイされていること
  - 詳細: `references/WORKERS_SETUP.md` を参照

## 実行コマンド

```bash
/path/to/plugins/notion-r2-image/scripts/upload_to_r2.sh <image_file_path>
```

## パラメータ

| パラメータ | 説明 |
|-----------|------|
| `<image_file_path>` | アップロードする画像ファイルの絶対パス |

## 出力形式

成功時:
```
Upload successful!
Notion URL: https://your-worker.workers.dev/images/20240115_143052_screenshot.png?token=YOUR_SECRET_TOKEN
```

このURLをそのままNotionページの画像ブロック（/image）に貼り付けることができます。

## 対応ファイル形式

| 形式 | MIME Type |
|------|-----------|
| `.png` | image/png |
| `.jpg`, `.jpeg` | image/jpeg |
| `.gif` | image/gif |
| `.webp` | image/webp |
| `.svg` | image/svg+xml |

## 使用例

### 基本的な使用

```bash
# スクリーンショットをアップロード
/path/to/plugins/notion-r2-image/scripts/upload_to_r2.sh /tmp/screenshot.png

# 出力例:
# Upload successful!
# Notion URL: https://notion-r2-image-proxy.xxx.workers.dev/images/20240115_143052_screenshot.png?token=abc123
```

### Claude Codeでの使用

ユーザー: 「この画像をNotionにアップロードして」
→ スキルを実行し、出力されたURLをユーザーに返す

ユーザー: 「スクリーンショットをNotionに貼り付けられるURLにして」
→ 画像パスを確認し、スキルを実行

## ファイル名の生成ルール

アップロード時のファイル名は以下の形式で自動生成:
```
images/{YYYYMMDD}_{HHMMSS}_{original_filename}
```

例: `screenshot.png` → `images/20240115_143052_screenshot.png`

これにより:
- ファイル名の衝突を防止
- 時系列でのソートが可能
- 元のファイル名も保持

## エラーハンドリング

| エラー | 原因 | 対処法 |
|--------|------|--------|
| `Config file not found` | 設定ファイル未作成 | `~/.config/notion-r2-image/.env` を作成 |
| `File not found` | 指定ファイルが存在しない | ファイルパスを確認 |
| `Unsupported file type` | 非対応の画像形式 | png/jpg/gif/webp/svgを使用 |
| `Upload failed` | R2へのアップロード失敗 | 認証情報とネットワークを確認 |

## セキュリティ

- R2バケットはプライベート設定（直接アクセス不可）
- Workers Proxyが固定トークンで認証
- トークンはURLパラメータとして付与（`?token=xxx`）
- Notion内で画像として表示される際もトークン付きURLが使用される

## 注意事項

- アップロードされた画像は自動削除されません（R2の設定に依存）
- 大きなファイル（10MB以上）はアップロードに時間がかかる場合があります
- トークンが漏洩した場合は、Workers側でトークンを再生成してください
  - `wrangler secret put AUTH_TOKEN` で新しいトークンを設定
  - `~/.config/notion-r2-image/.env` の `WORKERS_AUTH_TOKEN` も更新

## トラブルシューティング

### SignatureDoesNotMatch エラー
- R2_ACCESS_KEY_ID と R2_SECRET_ACCESS_KEY が正しいか確認
- .env ファイルに余分なスペースや改行がないか確認

### 403 Forbidden (Worker)
- AUTH_TOKEN が .env と Worker の両方で一致しているか確認
- wrangler.toml の bucket_name が正しいか確認

### 画像がNotionで表示されない
- Workers がデプロイされているか確認
- URLにトークンが含まれているか確認
- ブラウザで直接URLを開いて画像が表示されるか確認
