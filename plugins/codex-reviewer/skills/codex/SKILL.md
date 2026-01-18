---
name: codex
description: Codex CLI を使用したコードレビュー・分析・相談を実行する。使用場面: (1) コードレビュー依頼時、(2) 実装方針の相談、(3) バグの調査、(4) リファクタリング提案、(5) 解消が難しい問題の調査。トリガー: "codex", "コードレビュー", "レビューして", "相談して", "/codex"
---

# Codex

Codex CLI を使用してコードレビュー・分析・相談を実行するスキル。

## 実行コマンド

```bash
codex exec --full-auto --sandbox read-only --cd <project_directory> "<request>"
```

## パラメータ

| パラメータ | 説明 |
|-----------|------|
| `--full-auto` | 完全自動モードで実行 |
| `--sandbox read-only` | 読み取り専用サンドボックス（安全な分析用） |
| `--cd <dir>` | 対象プロジェクトのディレクトリ |
| `"<request>"` | 依頼内容（日本語可） |

## 使用例

### コードレビュー
```bash
codex exec --full-auto --sandbox read-only --cd /path/to/project "このプロジェクトのコードをレビューして、改善点を指摘してください"
```

### 設計相談
```bash
codex exec --full-auto --sandbox read-only --cd /path/to/project "この認証機能の設計方針について意見をください"
```

### バグ調査
```bash
codex exec --full-auto --sandbox read-only --cd /path/to/project "このエラーの原因を調査してください: <error_message>"
```

### セキュリティチェック
```bash
codex exec --full-auto --sandbox read-only --cd /path/to/project "セキュリティ上の問題点がないかチェックしてください"
```

## 実行手順

1. ユーザーから依頼内容を受け取る
2. 対象プロジェクトのディレクトリを特定する（通常はカレントディレクトリ）
3. 上記コマンド形式で Codex を実行
4. Codex の出力をリアルタイムで表示
5. 結果をユーザーに報告

## 注意事項

- Codex CLI が事前にインストールされている必要があります
- `--sandbox read-only` により、Codex はファイルの読み取りのみ可能です（安全）
- 複雑な調査は時間がかかる場合があります
- Codex の意見を鵜呑みにせず、最終判断は自分で行ってください
