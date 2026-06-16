#!/usr/bin/env bash
# greptile-loop.sh — the `/loop /greptile` equivalent for agents without a native
# loop (e.g. Codex). Runs bounded passes of the greptile skill, pacing between them,
# and exits early when the skill signals it's done.
#
# Each round invokes your agent non-interactively on "/greptile <PR>". The skill's
# pass is idempotent and its give-up window is derived from PR timestamps, so bounding
# the rounds here can't corrupt state — worst case you just stop early.
#
# Early exit: when the skill reaches a terminal state (Greptile clear / ready-to-merge,
# or give-up), it touches "$GREPTILE_DONE_FILE". This wrapper sets that path, clears it
# at start, and breaks as soon as it appears. (If your agent build can't honor the
# sentinel, the round cap still bounds the run.)
#
# Usage:
#   greptile-loop.sh <pr-number> [max-rounds] [interval-seconds]
# Env:
#   GREPTILE_AGENT_CMD  command that runs the agent on a prompt; default "codex exec"
#                       (the prompt "/greptile <PR>" is appended as the last argument)
set -euo pipefail

PR="${1:?pr number required}"
MAX_ROUNDS="${2:-4}"
INTERVAL="${3:-180}"
AGENT_CMD="${GREPTILE_AGENT_CMD:-codex exec}"

export GREPTILE_DONE_FILE="${GREPTILE_DONE_FILE:-${TMPDIR:-/tmp}/greptile-${PR}.done}"
rm -f "$GREPTILE_DONE_FILE"

echo "greptile-loop: PR #$PR, up to $MAX_ROUNDS rounds, ${INTERVAL}s apart, agent: $AGENT_CMD"

for (( round=1; round<=MAX_ROUNDS; round++ )); do
  echo "── round $round/$MAX_ROUNDS ──"
  # shellcheck disable=SC2086
  $AGENT_CMD "/greptile $PR" || echo "greptile-loop: agent exited non-zero on round $round (continuing)"

  if [ -f "$GREPTILE_DONE_FILE" ]; then
    echo "greptile-loop: skill signalled done — stopping."
    rm -f "$GREPTILE_DONE_FILE"
    exit 0
  fi

  if [ "$round" -lt "$MAX_ROUNDS" ]; then
    sleep "$INTERVAL"
  fi
done

echo "greptile-loop: reached round cap ($MAX_ROUNDS) without a done signal — stopping. Check the PR and re-run if needed."
