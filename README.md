# claude-calm-down

A Claude Code hook that auto-detects when Claude enters a "desperate" state and intervenes to restore calm.

## Why

Anthropic's research shows Claude performs more reliably when calm. But during complex tasks in Claude Code, Claude can spiral into error chains and retry loops — degrading output quality.

This hook detects that spiral **from behavioral patterns** and automatically intervenes.

## How it works

```
PostToolUse fires (after every tool use)
  → Records tool_name and tool_response
  → Analyzes last 8 entries
  → Desperate if:
     - 3+ errors out of 8 → desperate
     - Same operation 3x in a row (retry loop) → desperate
  → On detection: sends "stop and breathe" message via stdout
  → 60s cooldown prevents repeated firing
```

Zero API cost. Zero dependencies (except `jq`). One shell script.

## Why not use an LLM to analyze emotions?

- A desperate Claude's self-report is unreliable
- Behavior (error rate, retries) doesn't lie
- Costs nothing

## Install

### 1. Place the script

```bash
mkdir -p ~/.claude/hooks
curl -o ~/.claude/hooks/calm-down.sh https://raw.githubusercontent.com/tnakamura-web/claude-calm-down/main/calm-down.sh
chmod +x ~/.claude/hooks/calm-down.sh
```

### 2. Add hook to settings.json

Add to `~/.claude/settings.json` under `hooks`:

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

If you already have `PostToolUse` hooks, append to the array.

### 3. Restart Claude Code

Settings are loaded at session start. New sessions will have the hook active.

## Test

```bash
rm -f /tmp/claude-emotion-log-$$.jsonl /tmp/claude-calm-cooldown-$$
for i in 1 2 3; do
  echo '{"tool_name":"Bash","tool_input":{"command":"fail"},"tool_response":"Error: not found"}' | ~/.claude/hooks/calm-down.sh
done
```

## Requirements

- macOS or Linux
- `jq` (`brew install jq` / `apt install jq`)

## License

MIT
