#!/bin/bash
# session-notes.sh — Claude Code SessionEnd hook
# Summarizes the session and writes/overwrites one note per session
# in the Obsidian vault, organized into subfolders by project.

# The summarizer below runs `claude -p`, which fires its own SessionEnd
# hook when it finishes — this guard stops the recursion.
[ -n "${SESSION_NOTES_INNER:-}" ] && exit 0
export SESSION_NOTES_INNER=1

set -u

LOG_FILE="$HOME/.claude/hooks/session-notes.log"
if [ -f "$LOG_FILE" ] && [ "$(wc -c < "$LOG_FILE")" -gt 1000000 ]; then
  tail -c 200000 "$LOG_FILE" > "$LOG_FILE.tmp" && mv "$LOG_FILE.tmp" "$LOG_FILE"
fi
exec >> "$LOG_FILE" 2>&1
echo ""
echo "=== $(date '+%Y-%m-%d %H:%M:%S') — SessionEnd hook ==="

VAULT_DIR="${SESSION_NOTES_VAULT:-$HOME/Documents/Obsidian Vault/Personal/sessions}"

# ── Read hook input ──────────────────────────────────────────────
HOOK_INPUT=$(cat)
TRANSCRIPT_PATH=$(jq -r '.transcript_path // empty' <<< "$HOOK_INPUT")
SESSION_CWD=$(jq -r '.cwd // empty' <<< "$HOOK_INPUT")
SESSION_ID=$(jq -r '.session_id // empty' <<< "$HOOK_INPUT")
REASON=$(jq -r '.reason // "unknown"' <<< "$HOOK_INPUT")
echo "session=$SESSION_ID reason=$REASON cwd=$SESSION_CWD"
echo "transcript=$TRANSCRIPT_PATH"

if [ -z "$SESSION_ID" ] || [ -z "$TRANSCRIPT_PATH" ] || [ ! -f "$TRANSCRIPT_PATH" ]; then
  echo "Skipping: missing session_id or transcript."
  exit 0
fi

# ── Determine project and subfolder ──────────────────────────────
DIR_NAME=$(basename "$(dirname "$TRANSCRIPT_PATH")")
PROJECT=""
WORKSPACE=""

if [[ "$DIR_NAME" == *conductor-workspaces* ]]; then
  SUFFIX="${DIR_NAME#*conductor-workspaces-}"
  for PROJ_DIR in "$HOME/conductor/workspaces"/*/; do
    [ -d "$PROJ_DIR" ] || continue
    PROJ_NAME=$(basename "$PROJ_DIR")
    if [[ "$SUFFIX" == "$PROJ_NAME"-* ]]; then
      PROJECT="$PROJ_NAME"
      WORKSPACE="${SUFFIX#"$PROJ_NAME"-}"
      break
    fi
  done
  if [ -z "$PROJECT" ]; then
    PROJECT="conductor"
    WORKSPACE="$SUFFIX"
  fi
  SUBFOLDER="$PROJECT"
else
  if [ -n "$SESSION_CWD" ]; then
    CLEAN=$(echo "$SESSION_CWD" | sed "s|^$HOME/||; s|^/Users/[^/]*/||; s|/$||")
    if [ -z "$CLEAN" ] || [ "$CLEAN" = "$SESSION_CWD" ]; then
      PROJECT="home"
    else
      PROJECT="$CLEAN"
    fi
  else
    CLEAN=$(echo "$DIR_NAME" | sed 's/^-Users-[^-]*-//; s/^-//' | tr '-' '/')
    PROJECT="${CLEAN:-misc}"
  fi
  SUBFOLDER="${PROJECT//\//-}"
fi

echo "project=$PROJECT workspace=$WORKSPACE subfolder=$SUBFOLDER"

# ── Extract conversation ─────────────────────────────────────────
CONVERSATION=$(TRANSCRIPT_PATH="$TRANSCRIPT_PATH" python3 << 'PYEOF'
import json, os

parts = []
with open(os.environ["TRANSCRIPT_PATH"]) as f:
    for line in f:
        try:
            obj = json.loads(line)
        except json.JSONDecodeError:
            continue
        msg_type = obj.get("type", "")
        if msg_type not in ("user", "assistant"):
            continue

        role = "User" if msg_type == "user" else "Assistant"
        msg = obj.get("message", {})
        content = msg.get("content", "") if isinstance(msg, dict) else ""

        text = ""
        if isinstance(content, str):
            text = content
        elif isinstance(content, list):
            for block in content:
                if isinstance(block, dict) and block.get("type") == "text":
                    text += block["text"] + "\n"
                elif isinstance(block, dict) and block.get("type") == "tool_use":
                    text += f'[Used tool: {block.get("name", "?")}]\n'

        text = text.strip()
        if not text:
            continue
        if len(text) > 2000:
            text = text[:2000] + "... [truncated]"
        parts.append(f"**{role}:** {text}\n")

output = "\n".join(parts)
if len(output) > 60000:
    output = output[:60000] + "\n\n[... truncated]"
print(output)
PYEOF
)

if [ -z "$CONVERSATION" ]; then
  echo "Skipping: empty conversation."
  exit 0
fi

EXCHANGE_COUNT=$(grep -c '^\*\*\(User\|Assistant\):\*\*' <<< "$CONVERSATION")
echo "exchanges=$EXCHANGE_COUNT"

# ── Resolve note path (one note per session, updated on re-runs) ─
SESSION_DATE=$(head -20 "$TRANSCRIPT_PATH" | jq -rs '[.[] | .timestamp // empty] | first // empty' | cut -c1-10)
SESSION_DATE="${SESSION_DATE:-$(date +%Y-%m-%d)}"
SESSION_SHORT="${SESSION_ID:0:8}"
NOTE_DIR="${VAULT_DIR}/${SUBFOLDER}"
mkdir -p "$NOTE_DIR"

FULL_PATH=$(find "$NOTE_DIR" -name "*-${SESSION_SHORT}.md" -type f 2>/dev/null | head -1)
if [ -n "$FULL_PATH" ]; then
  echo "Updating existing note: $FULL_PATH"
else
  FILENAME="${SESSION_DATE}-${SESSION_SHORT}${WORKSPACE:+-$WORKSPACE}.md"
  FULL_PATH="${NOTE_DIR}/$(echo "$FILENAME" | tr '/ ' '--')"
  echo "Creating new note: $FULL_PATH"
fi

# ── Summarize via claude CLI ─────────────────────────────────────
echo "Calling claude -p..."
SUMMARY=$(printf '%s' "$CONVERSATION" | env -u CLAUDE_CODE_ENTRYPOINT -u CLAUDECODE -u ANTHROPIC_API_KEY \
  claude -p --model haiku "You are summarizing a Claude Code session transcript.

Context: project='$PROJECT', workspace='$WORKSPACE'

Write a concise Obsidian note. Use this format exactly:

## What happened
A short paragraph (2-4 sentences) describing what was accomplished in plain language. Be specific about outcomes, not process.

## Decisions
- Bullet any meaningful technical or design choices. Skip if none.

## Files touched
- List key files created or modified. Skip lock files, node_modules, etc. If unclear, describe the area of code.

## Still open
- Anything unresolved, left as a TODO, or to revisit next session. Write 'Nothing — wrapped up cleanly.' if none.

Be concise and direct. No preamble, no 'Here is the summary' intro." 2>&1)

CLAUDE_EXIT=$?
echo "claude -p exit: $CLAUDE_EXIT"

if [ $CLAUDE_EXIT -ne 0 ] || [ -z "$SUMMARY" ]; then
  echo "ERROR: claude -p failed. Output: $SUMMARY"
  SUMMARY="_Summarization failed (exit $CLAUDE_EXIT). Review transcript manually._

Exchanges: $EXCHANGE_COUNT"
fi

# ── Write/overwrite the note ─────────────────────────────────────
TIMESTAMP=$(date +"%Y-%m-%d %H:%M")
TITLE="${PROJECT}${WORKSPACE:+ / $WORKSPACE}"

cat > "$FULL_PATH" << NOTEEOF
---
type: session-note
project: ${PROJECT}
workspace: ${WORKSPACE}
session_id: ${SESSION_ID}
date: ${SESSION_DATE}
updated: ${TIMESTAMP}
transcript: ${TRANSCRIPT_PATH}
exchanges: ${EXCHANGE_COUNT}
tags:
  - session-note
  - ${SUBFOLDER}
---

# ${TITLE}
_${SESSION_DATE} | ${EXCHANGE_COUNT} exchanges | updated ${TIMESTAMP}_

${SUMMARY}
NOTEEOF

echo "SUCCESS: $FULL_PATH ($(wc -c < "$FULL_PATH") bytes)"
