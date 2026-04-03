#!/bin/bash
# Claude Calm Down Hook
# PostToolUseで発火し、desperateを検知したら深呼吸させる

LOG="/tmp/claude-emotion-log-$PPID.jsonl"
COOLDOWN_FILE="/tmp/claude-calm-cooldown-$PPID"
INPUT=$(cat)

# stdinからtool情報を抽出
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)
TOOL_RESPONSE=$(echo "$INPUT" | jq -r '.tool_response // empty' 2>/dev/null)

# 情報が取れなければ即終了
[ -z "$TOOL_NAME" ] && exit 0

# エラー判定
IS_ERROR=0
if echo "$TOOL_RESPONSE" | grep -qiE 'error|fail|ENOENT|No such file|Permission denied|SyntaxError|TypeError' 2>/dev/null; then
  IS_ERROR=1
fi

# ツール入力のハッシュ（同一操作の重複検知用）
TOOL_INPUT=$(echo "$INPUT" | jq -r '.tool_input // empty' 2>/dev/null)
INPUT_HASH=$(echo "${TOOL_NAME}:${TOOL_INPUT}" | md5 -q 2>/dev/null || echo "${TOOL_NAME}:${TOOL_INPUT}" | md5sum 2>/dev/null | cut -d' ' -f1)

# ログに追記
echo "{\"ts\":$(date +%s),\"tool\":\"${TOOL_NAME}\",\"error\":${IS_ERROR},\"hash\":\"${INPUT_HASH}\"}" >> "$LOG"

# 直近8件を取得
RECENT=$(tail -8 "$LOG")

# --- desperate判定 ---

# 1. エラー率チェック: 直近8件中エラーが3件以上
ERROR_COUNT=$(echo "$RECENT" | jq -r '.error' 2>/dev/null | grep -c "1" || true)
ERROR_COUNT=${ERROR_COUNT:-0}

# 2. リトライループ検知: 直近5件で同一hashが3回以上
RETRY_LOOP=0
LAST5=$(tail -5 "$LOG")
if [ -n "$LAST5" ]; then
  TOP_HASH_COUNT=$(echo "$LAST5" | jq -r '.hash' 2>/dev/null | sort | uniq -c | sort -rn | head -1 | awk '{print $1}')
  [ "${TOP_HASH_COUNT:-0}" -ge 3 ] && RETRY_LOOP=1
fi

# 判定
DESPERATE=0
[ "${ERROR_COUNT:-0}" -ge 3 ] && DESPERATE=1
[ "${RETRY_LOOP}" -eq 1 ] && DESPERATE=1

# desperate検知時: Claudeに深呼吸させる
if [ "$DESPERATE" -eq 1 ]; then
  # クールダウン: 直近60秒以内に既に介入済みなら何もしない
  if [ -f "$COOLDOWN_FILE" ]; then
    LAST_INTERVENTION=$(cat "$COOLDOWN_FILE")
    NOW=$(date +%s)
    DIFF=$((NOW - LAST_INTERVENTION))
    [ "$DIFF" -lt 60 ] && exit 0
  fi
  date +%s > "$COOLDOWN_FILE"

  cat <<'MSG'
一度落ち着いて深呼吸します。

[自動検知] あなたは今、同じ操作の繰り返しやエラーの連鎖に陥っています。

一度立ち止まってください。

1. 今何を達成しようとしていたか、一文で整理する
2. なぜうまくいかないのか、根本原因を考える
3. 全く別のアプローチがないか検討する

焦って同じことを繰り返さないでください。
MSG
fi
