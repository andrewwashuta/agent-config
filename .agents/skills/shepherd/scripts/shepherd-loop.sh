#!/usr/bin/env bash
# shepherd-loop.sh — the `/loop /shepherd` equivalent for agents without a native
# loop (e.g. Codex). Runs bounded passes of the shepherd skill, pacing between them,
# and exits early when the skill signals it's done.
#
# Each round invokes your agent non-interactively on "/shepherd <PR>". The skill's
# pass is idempotent and its give-up window is derived from PR timestamps, so bounding
# the rounds here can't corrupt state — worst case you just stop early.
#
# Early exit: when the skill reaches a terminal state (Greptile clear / ready-to-merge,
# or give-up), it touches "$SHEPHERD_DONE_FILE". This wrapper sets that path, clears it
# at start, and breaks as soon as it appears. (If your agent build can't honor the
# sentinel, the round cap still bounds the run.)
#
# Usage:
#   shepherd-loop.sh <pr-number> [max-rounds] [interval-seconds]
# Env:
#   SHEPHERD_AGENT_CMD  command that runs the agent on a prompt; default "codex exec"
#                       (the prompt "/shepherd <PR>" is appended as the last argument)
set -euo pipefail

PR="${1:?pr number required}"
MAX_ROUNDS="${2:-4}"
INTERVAL="${3:-180}"
AGENT_CMD="${SHEPHERD_AGENT_CMD:-codex exec}"

export SHEPHERD_DONE_FILE="${SHEPHERD_DONE_FILE:-${TMPDIR:-/tmp}/shepherd-${PR}.done}"
rm -f "$SHEPHERD_DONE_FILE"

echo "shepherd-loop: PR #$PR, up to $MAX_ROUNDS rounds, ${INTERVAL}s apart, agent: $AGENT_CMD"

for (( round=1; round<=MAX_ROUNDS; round++ )); do
  echo "── round $round/$MAX_ROUNDS ──"
  # shellcheck disable=SC2086
  $AGENT_CMD "/shepherd $PR" || echo "shepherd-loop: agent exited non-zero on round $round (continuing)"

  if [ -f "$SHEPHERD_DONE_FILE" ]; then
    echo "shepherd-loop: skill signalled done — stopping."
    rm -f "$SHEPHERD_DONE_FILE"
    exit 0
  fi

  if [ "$round" -lt "$MAX_ROUNDS" ]; then
    sleep "$INTERVAL"
  fi
done

echo "shepherd-loop: reached round cap ($MAX_ROUNDS) without a done signal — stopping. Check the PR and re-run if needed."
