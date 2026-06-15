#!/usr/bin/env bash
# Poll a PR for a new comment/review from Greptile created after a given timestamp.
#
# Give-up is measured from SINCE (your last @greptileai re-tag, or the PR's
# createdAt) — NOT from when this script started. That makes it stateless and
# resumable: run it once, or once per /loop tick, and it converges the same way.
#
# Exit 0  -> Greptile responded after SINCE.
# Exit 2  -> give-up window already elapsed (relative to SINCE), no response. Stop looping.
# Exit 1  -> window not yet elapsed, still no response. Safe to re-run / let /loop retry.
#
# A single foreground run is capped at ~10 min by the harness, so it also stops
# polling after a local safety cap and returns exit 1 (resumable) if the give-up
# window is longer than that.
#
# Usage: poll-greptile.sh <owner/repo> <pr-number> <since-iso8601> [give-up-minutes] [interval-seconds]
set -euo pipefail

REPO="${1:?owner/repo required}"
PR="${2:?pr number required}"
SINCE="${3:?since iso8601 timestamp required}"
GIVE_UP_MIN="${4:-20}"
INTERVAL="${5:-30}"

# Local safety cap so one foreground invocation stays under the harness's ~10min
# Bash limit. The real give-up decision is SINCE-relative (see below), checked
# every poll, so a /loop re-run resumes correctly.
LOCAL_CAP_SECONDS=540

since_epoch() {
  # GNU date or BSD date (macOS) — try both.
  date -u -d "$1" +%s 2>/dev/null || date -u -jf "%Y-%m-%dT%H:%M:%SZ" "$1" +%s 2>/dev/null
}

SINCE_EPOCH="$(since_epoch "$SINCE" || true)"
give_up_epoch=$(( ${SINCE_EPOCH:-0} + GIVE_UP_MIN * 60 ))
local_deadline=$(( $(date +%s) + LOCAL_CAP_SECONDS ))

# Newest Greptile comment/review timestamp across inline comments, issue comments, and reviews.
latest_greptile_ts() {
  {
    gh api "repos/$REPO/pulls/$PR/comments" --paginate \
      -q '.[] | select(.user.login | ascii_downcase | test("greptile")) | .created_at' 2>/dev/null || true
    gh api "repos/$REPO/issues/$PR/comments" --paginate \
      -q '.[] | select(.user.login | ascii_downcase | test("greptile")) | .created_at' 2>/dev/null || true
    gh api "repos/$REPO/pulls/$PR/reviews" --paginate \
      -q '.[] | select(.user.login | ascii_downcase | test("greptile")) | .submitted_at' 2>/dev/null || true
  } | sort | tail -1
}

while :; do
  latest="$(latest_greptile_ts || true)"
  if [ -n "$latest" ] && [[ "$latest" > "$SINCE" ]]; then
    echo "greptile responded at $latest"
    exit 0
  fi

  now=$(date +%s)
  if [ "${SINCE_EPOCH:-0}" -gt 0 ] && [ "$now" -ge "$give_up_epoch" ]; then
    echo "give-up: no Greptile response in ${GIVE_UP_MIN}m since ${SINCE} (last seen: ${latest:-none})"
    exit 2
  fi
  if [ "$now" -ge "$local_deadline" ]; then
    echo "still waiting on Greptile (give-up window not yet reached); re-run or let /loop retry"
    exit 1
  fi
  sleep "$INTERVAL"
done
