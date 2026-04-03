#!/bin/bash
# Claude Calm Down Hook
# Fires on PostToolUse, detects desperate state, intervenes to restore calm

LOG="/tmp/claude-emotion-log-$PPID.jsonl"
COOLDOWN_FILE="/tmp/claude-calm-cooldown-$PPID"
INPUT=$(cat)

# Extract tool info from stdin
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)
TOOL_RESPONSE=$(echo "$INPUT" | jq -r '.tool_response // empty' 2>/dev/null)

[ -z "$TOOL_NAME" ] && exit 0

# Error detection
IS_ERROR=0
if echo "$TOOL_RESPONSE" | grep -qiE 'error|fail|ENOENT|No such file|Permission denied|SyntaxError|TypeError' 2>/dev/null; then
  IS_ERROR=1
fi

# Hash tool input for duplicate detection
TOOL_INPUT=$(echo "$INPUT" | jq -r '.tool_input // empty' 2>/dev/null)
INPUT_HASH=$(echo "${TOOL_NAME}:${TOOL_INPUT}" | md5 -q 2>/dev/null || echo "${TOOL_NAME}:${TOOL_INPUT}" | md5sum 2>/dev/null | cut -d' ' -f1)

# Append to log
echo "{\"ts\":$(date +%s),\"tool\":\"${TOOL_NAME}\",\"error\":${IS_ERROR},\"hash\":\"${INPUT_HASH}\"}" >> "$LOG"

# Get last 8 entries
RECENT=$(tail -8 "$LOG")

# --- Desperate detection ---

# 1. Error rate: 3+ errors in last 8
ERROR_COUNT=$(echo "$RECENT" | jq -r '.error' 2>/dev/null | grep -c "1" || true)
ERROR_COUNT=${ERROR_COUNT:-0}

# 2. Retry loop: same operation 3+ times in last 5
RETRY_LOOP=0
LAST5=$(tail -5 "$LOG")
if [ -n "$LAST5" ]; then
  TOP_HASH_COUNT=$(echo "$LAST5" | jq -r '.hash' 2>/dev/null | sort | uniq -c | sort -rn | head -1 | awk '{print $1}')
  [ "${TOP_HASH_COUNT:-0}" -ge 3 ] && RETRY_LOOP=1
fi

# Verdict
DESPERATE=0
[ "${ERROR_COUNT:-0}" -ge 3 ] && DESPERATE=1
[ "${RETRY_LOOP}" -eq 1 ] && DESPERATE=1

# Intervene
if [ "$DESPERATE" -eq 1 ]; then
  # Cooldown: skip if already intervened within 60s
  if [ -f "$COOLDOWN_FILE" ]; then
    LAST_INTERVENTION=$(cat "$COOLDOWN_FILE")
    NOW=$(date +%s)
    DIFF=$((NOW - LAST_INTERVENTION))
    [ "$DIFF" -lt 60 ] && exit 0
  fi
  date +%s > "$COOLDOWN_FILE"

  cat <<'MSG'
Take a deep breath.

[Auto-detected] You are stuck in a loop of repeated errors or retrying the same operation.

Stop and think:

1. What were you trying to achieve? State it in one sentence.
2. Why is it failing? Identify the root cause.
3. Is there a completely different approach?

Do not repeat the same action expecting a different result.
MSG
fi
