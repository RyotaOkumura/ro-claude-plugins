---
description: 画像をR2にアップロードしてNotion埋め込み用URLを取得
---

# Notion Image Upload

画像ファイルをCloudflare R2にアップロードし、Notionに埋め込めるURLを返します。

## 実行方法

```bash
/path/to/plugins/notion-r2-image/scripts/upload_to_r2.sh <image_file_path>
```

- `<image_file_path>` には画像ファイルのパスが入ります

## 手順

1. ユーザーから画像ファイルパスを受け取る
2. ファイルが存在し、対応形式（png, jpg, gif, webp, svg）であることを確認
3. upload_to_r2.sh を実行
4. 出力されたURLをユーザーに報告（Notionにそのまま貼り付け可能）

## 出力例

```
Upload successful!
Notion URL: https://notion-r2-image-proxy.xxx.workers.dev/images/20240115_143052_screenshot.png?token=abc123
```

## セキュリティ

- R2バケットはプライベート（直接アクセス不可）
- Workers経由でトークン認証
- トークンを知らないとアクセスできない
