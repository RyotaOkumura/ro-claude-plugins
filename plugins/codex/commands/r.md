---
description: Codex CLI でコードレビュー・相談を実行
---

# Codex Review

ユーザーのリクエストに基づいて Codex CLI を実行します。

## 実行方法

```bash
codex exec --full-auto --sandbox read-only --cd <project_directory> "$ARGUMENTS"
```

- `$ARGUMENTS` にはユーザーが入力した内容が入ります
- `<project_directory>` は現在の作業ディレクトリを使用します

## 手順

1. ユーザーの `$ARGUMENTS` を確認
2. 現在のディレクトリで Codex を実行
3. 結果を報告
