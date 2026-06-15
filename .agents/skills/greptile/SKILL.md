---
name: greptile
description: Tend a PR's Greptile code review end-to-end — create the PR if the current branch doesn't have one yet, then fetch @greptileai's feedback, implement the changes that make sense (skip the rest with a reason), push, re-tag @greptileai for a re-review, wait for its reply, and stop with a merge recommendation once it's all clear. Stops before merging — you do the final merge. Use when asked to "open a PR and handle greptile", "address Greptile", "handle greptile feedback", "respond to the bot review", or to keep listening on a PR. Pair with /loop to keep tending continuously.
---

# Tend Greptile feedback on a PR

Drive one PR's Greptile review to a clean state. **You do not merge** — you stop once Greptile is happy and hand the merge back to the user.

## Scope

- Works on **one PR at a time**, in whatever repo is the current working directory. Repo-agnostic — use it in any repo where Greptile is enabled.
- Target PR: the argument if given (`/greptile 123` or a PR URL), otherwise the PR for the current branch — **and if the current branch has no PR yet, create one first** (step 0).
- Greptile's bot posts as an author whose login contains `greptile` (e.g. `greptile-apps[bot]`). Match case-insensitively — never hard-code one login. If no Greptile author ever appears on the PR (after the give-up window in step 4), assume Greptile isn't installed on this repo and tell the user.

## Step 0 — ensure a PR exists

Resolve the target PR:

```bash
gh pr view --json number,headRefName,url   # current branch's PR, if any
```

If a PR already exists (or a PR number/URL was passed as the argument), skip to step 1.

If there is **no** PR for the current branch, create one:

- **Guard:** if the current branch is the repo's default branch (`gh repo view --json defaultBranchRef -q .defaultBranchRef.name`), stop and ask the user — never open a PR from `main`/`master`. Offer to branch first.
- **Common case:** you're already on a feature branch with commits up to date — just push and open the PR. `git push -u origin HEAD` is a no-op if already pushed.
- **Uncommitted changes:** a PR only includes committed work. If `git status --porcelain` shows uncommitted changes, don't silently ignore or auto-commit them — surface them and ask whether to commit them first or open the PR from what's already committed.
- Generate a title and body from the branch's commits and diff against the base (`git log <base>..HEAD`, `git diff <base>...HEAD`). Title = concise summary of the change; body = what/why bullets. Keep it honest to the diff.
- Create it:

```bash
gh pr create --title "<generated>" --body "$(cat <<'EOF'
<what/why summary>
EOF
)"
```

  Default the base to the repo's default branch unless the user said otherwise. Do **not** pass `--draft` (Greptile reviews ready PRs) and do **not** merge.
- Report the new PR URL, then continue — Greptile auto-reviews new PRs, so proceed into the wait/poll loop (step 4) for its first review, then triage as normal.

## One pass

Each invocation does exactly one pass (after step 0 ensures a PR exists). The pass is **idempotent and safe to re-run**, so it works standalone or under `/loop`.

### 1. Read the state

```bash
PR=<number>           # resolved above
REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner)
# Review comments (inline) + issue comments + reviews from Greptile:
gh api "repos/$REPO/pulls/$PR/comments" --paginate
gh api "repos/$REPO/issues/$PR/comments" --paginate
gh api "repos/$REPO/pulls/$PR/reviews" --paginate
```

Determine which state you're in:
- **New feedback** — Greptile has actionable comments newer than your last push/reply → go to step 2.
- **Waiting** — you already addressed + re-tagged, and Greptile hasn't replied since → go to step 4 (wait).
- **Clear** — Greptile's latest review is an approval, or it explicitly says it has no further comments / all issues resolved → go to step 5 (done).

Use timestamps to decide "newer than": compare comment `created_at`/`updated_at` against the head commit's push time and your own last bot reply. Only treat a comment as actionable if it asks for a change — ignore Greptile's summary/overview comments and nits it already marked resolved.

### 2. Triage and implement

For each actionable comment, decide **does this make sense?**
- **Implement** if it's a real correctness/clarity/security/consistency improvement that fits the codebase.
- **Skip** if it's wrong, out of scope, a style choice that conflicts with the repo's conventions, or would make things worse. Skipping is fine and expected — but you must record a one-line reason.

Make the edits. Keep changes tight and matched to the surrounding code (see the `deslop` / `simplify` conventions). Run the repo's lint/typecheck/tests if they're quick and relevant before pushing.

### 3. Commit, push, and re-tag

```bash
git add -A
git commit -m "Address Greptile review feedback"   # end with the standard Co-Authored-By trailer
git push
```

Then post one PR comment that re-triggers a re-review and records your decisions:

```bash
gh pr comment "$PR" --body "$(cat <<'EOF'
@greptileai I've pushed changes addressing your review.

**Addressed**
- <comment> → <what changed>

**Skipped (with reason)**
- <comment> → <why it doesn't apply>

Please take another look.
EOF
)"
```

If you addressed everything and there's nothing to skip, drop the Skipped section. Tagging `@greptileai` is what triggers the re-review — don't forget it.

### 4. Check for Greptile's reply (with a give-up window)

Greptile's latency varies — often a couple of minutes, sometimes ~15. You're waiting for a new comment/review from the Greptile author created **after** your re-tag.

**Give-up is time-on-the-PR, not a local timer.** The threshold is measured from the `created_at` of your last `@greptileai` re-tag comment (or, on a brand-new PR, the PR's `createdAt`), default 20 min. This is stateless and resumable — it works the same across `/loop` ticks, a machine sleep, or a new session.

**Pick exactly ONE waiting mechanism for how you were invoked. Never combine them** — no background poller *and* a scheduled wakeup, no `Monitor`, no spawning a process that re-invokes you on top of a loop. That thrash is the #1 failure mode here.

**Under `/loop` (the normal case — this is what `/loop /greptile` uses):**
Do a single, **instantaneous** state read — you effectively already did it in step 1. No sleeping, no `poll-greptile.sh`, no background process. Then branch:
- **Responded** → step 2 (new feedback) or step 5 (clear).
- **Still waiting, window not elapsed** → print one status line — `waiting on Greptile — Nm of <GIVE_UP>m elapsed` — and **end the pass**. The loop is your polling interval; do not block or background anything. For self-paced `/loop`, schedule the next check **~240–270s** out (keeps the prompt cache warm; ~4–5 checks inside a 20-min window). For interval `/loop`, just let the next tick fire.
- **Window elapsed, no response** → go to step 5's give-up branch and stop the loop.

**Standalone (`/greptile` with no `/loop`), only if you want to actively block and wait:**
Run the poller, which sleeps/polls every 30s up to its ~9-min safety cap:
```bash
bash ~/.claude/skills/greptile/scripts/poll-greptile.sh "$REPO" "$PR" "<retag-iso8601>" [GIVE_UP_MINUTES]
```
Exit `0` → responded, re-read state and continue. Exit `2` → give-up window elapsed, stop. Exit `1` → hit the safety cap before the window; just re-run it (or switch to `/loop`). Do **not** also set a `ScheduleWakeup` — the blocking call *is* the wait.

### 5. Done — recommend merge (or give up), do NOT merge

**Greptile is clear** → **stop** and report:
- The PR link and that Greptile has signed off.
- A short list of what you implemented and what you skipped (with reasons).
- CI status (`gh pr checks "$PR"`).
- An explicit: "Ready for your review and merge" — and wait. Never run `gh pr merge`.

**Give-up window elapsed with no response** → **stop** (don't keep looping) and tell the user Greptile hasn't responded in `GIVE_UP_MINUTES`. If it has *never* responded on this PR, note Greptile may not be installed on this repo. Leave the PR as-is for the user.

Either way, end the pass cleanly — under `/loop`, signal there's nothing left to do so the loop stops.

## Continuous mode

To keep listening rather than doing a single pass, the user runs:

```
/loop /greptile          # current branch's PR (creates it if needed), or
/loop /greptile 123       # a specific PR
```

Each tick re-runs this pass. Because the pass is idempotent and the give-up window is derived from PR timestamps, it implements new feedback as it arrives, re-tags, and converges. End the loop when:
- Greptile is clear → reported "ready for merge", or
- the give-up window elapsed with no Greptile response.

In both cases tell the loop there's nothing left to do so it stops.

## Guardrails

- One PR per invocation; never touch other PRs or branches.
- Never force-push or rewrite history; only add commits to the PR branch.
- Never merge, close, or change PR base. The final merge is always the user's.
- If a Greptile comment would require a large/risky change or a product decision, skip it and surface it to the user rather than guessing.
- If `gh` isn't authed or the PR can't be found, stop and say so.
