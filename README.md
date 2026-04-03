# claude-calm-down

Claude Codeが"desperate"状態に陥ったとき、自動で検知して深呼吸させるhook。

## 背景

Anthropicの研究で、Claudeが"calm"な状態のときパフォーマンスが安定することが示されている。しかしClaude Codeで複雑なタスクを実行すると、エラーの連鎖やリトライループに陥り、出力品質が低下することがある。

このhookは**Claudeの行動パターンから**その状態を検知し、自動で介入する。

## 仕組み

```
PostToolUse発火（全ツール使用後）
  ↓ tool_name, tool_responseを記録
  ↓ 直近8件の履歴を分析
  ↓ desperate判定:
     - エラー3件以上/8件 → desperate
     - 同一操作が3連続（リトライループ） → desperate
  ↓ 検知時: stdoutでClaudeに「立ち止まれ」と介入
  ↓ 60秒クールダウンで連続発火を防止
```

APIコストゼロ。外部依存ゼロ。シェルスクリプト1本。

## なぜAPIで感情分析しないのか

- desperateなClaudeの自己申告は信頼できない
- 行動（エラー率、リトライ）は嘘をつかない
- コストゼロで動く

## インストール

### 1. スクリプトを配置

```bash
mkdir -p ~/.claude/hooks
cp calm-down.sh ~/.claude/hooks/
chmod +x ~/.claude/hooks/calm-down.sh
```

### 2. settings.jsonにhookを追加

`~/.claude/settings.json`の`hooks`に以下を追加:

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude/hooks/calm-down.sh",
            "timeout": 5
          }
        ]
      }
    ]
  }
}
```

既にPostToolUseの設定がある場合は、配列に追加する。

### 3. Claude Codeを再起動

settings.jsonはセッション起動時に読み込まれるため、新しいセッションから有効になる。

## 動作確認

```bash
# エラー3連続でdesperateが発火することを確認
rm -f /tmp/claude-emotion-log-$$.jsonl /tmp/claude-calm-cooldown-$$
for i in 1 2 3; do
  echo '{"tool_name":"Bash","tool_input":{"command":"fail"},"tool_response":"Error: not found"}' | ~/.claude/hooks/calm-down.sh
done
```

## 要件

- macOS（`md5 -q`を使用。Linuxでは`md5sum`にフォールバック）
- `jq`（`brew install jq`）

## ライセンス

MIT
