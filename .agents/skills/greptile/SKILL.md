---
name: greptile
description: Tend a PR's automated code review end-to-end — create the PR if the current branch doesn't have one yet, then fetch Greptile's (primary) and Codex's (secondary) feedback, implement the changes that make sense (skip the rest with a reason), push, re-tag @greptileai for a re-review, wait for its reply, and stop with a merge recommendation once it's all clear. Stops before merging — you do the final merge. Use when asked to "open a PR and handle greptile", "address Greptile", "handle the bot review", "respond to Codex", or to keep listening on a PR. Pair with /loop to keep tending continuously.
---

# Tend automated PR review feedback (Greptile + Codex)

Drive one PR's automated code review to a clean state. **You do not merge** — you stop once the review is happy and hand the merge back to the user.

Two reviewers, weighted differently:
- **Greptile — primary.** Its verdict gates "ready to merge", and `@greptileai` is what you re-tag for a re-review.
- **Codex (`chatgpt-codex-connector`) — secondary / advisory.** Read it, but take it with a grain of salt: it's less reliable than Greptile. Apply a higher bar (see step 2), don't gate merge-readiness on it, and don't loop waiting for it.

## Scope

- Works on **one PR at a time**, in whatever repo is the current working directory. Repo-agnostic — use it in any repo where Greptile and/or Codex review.
- Target PR: the argument if given (`/greptile 123` or a PR URL), otherwise the PR for the current branch — **and if the current branch has no PR yet, create one first** (step 0).
- Reviewer authors, matched case-insensitively (never hard-code one exact login):
  - **Greptile** — login contains `greptile` (e.g. `greptile-apps[bot]`).
  - **Codex** — login contains `chatgpt-codex-connector` (or `codex`).
- If no Greptile author ever appears (after the give-up window in step 4), assume Greptile isn't installed on this repo and tell the user. Codex may or may not be present — its absence is fine.

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
# Inline comments + issue comments + reviews (from BOTH reviewers):
gh api "repos/$REPO/pulls/$PR/comments" --paginate
gh api "repos/$REPO/issues/$PR/comments" --paginate
gh api "repos/$REPO/pulls/$PR/reviews" --paginate
```

Read feedback from **both** authors (match `greptile` and `chatgpt-codex-connector`/`codex`, case-insensitively), but keep them tagged by source — Greptile is primary, Codex is advisory (step 2 weights them).

**Greptile re-reviews by EDITING its summary comment in place** — it does NOT post a fresh comment each round. It keeps one summary comment (with a confidence score like `4/5` → `5/5` and a verdict like "safe to merge") and updates it. So:
- Detect new activity by `updated_at`, **not** `created_at` — an in-place edit bumps `updated_at` while `created_at` stays put. Keying off `created_at` will miss the re-review entirely (this was a real bug).
- The signal of "did Greptile respond to my re-tag?" is: the summary comment's `updated_at` is newer than your last re-tag, OR a new inline comment/review appeared after it.
- The signal of "is it clear?" lives in the **body** of that latest summary comment — its confidence score and verdict, and whether any P0/P1/actionable findings remain. Read the body; don't infer from comment count.

Codex (`chatgpt-codex-connector`) re-reviews **on push** (no `@` tag needed), so its latest comments after your last push are its current take.

Determine which state you're in (**gated on Greptile** — Codex never blocks):
- **New feedback** — Greptile's latest summary/inline lists actionable findings newer than your last push/reply, OR Codex has new findings worth acting on → step 2.
- **Waiting** — nothing from Greptile is newer than your last re-tag (`updated_at` unchanged) → step 4.
- **Clear** — Greptile's latest verdict is an approval / "safe to merge" with no remaining actionable findings (a review state of APPROVED counts). Any leftover *Codex-only* nits you deliberately skipped don't block this — list them in the report instead → step 5.

To get the editable Greptile summary, read `updated_at` + `body` together, e.g.:
```bash
gh api "repos/$REPO/issues/$PR/comments" --paginate \
  -q '.[] | select(.user.login|ascii_downcase|test("greptile")) | "\(.updated_at)\t\(.body)"' | tail -1
```
Only treat a finding as actionable if it asks for a change — ignore overview prose and nits already marked resolved.

### 1b. Keep the branch mergeable

A PR isn't truly "ready" if it can't merge into base. Check this every pass:

```bash
gh pr view "$PR" --json mergeable,mergeStateStatus,baseRefName \
  -q '"\(.mergeable)\t\(.mergeStateStatus)\t\(.baseRefName)"'
```

- **`CLEAN` / mergeable, up to date** → nothing to do, continue.
- **`BEHIND`** (out of date with base, but no conflicts) → **auto-update, no need to ask.** It's mechanical and safe:
  ```bash
  gh pr update-branch "$PR"        # or: git fetch origin && git merge origin/<base> && git push
  ```
  Then re-run the repo's quick checks (lint/typecheck/tests) to confirm the update didn't break anything, and note it in your next re-tag comment.
- **`CONFLICTING` / `DIRTY`** (real conflicts) → **do NOT resolve silently.** Resolving conflicts changes code semantics, so:
  1. Merge base in locally (`git fetch origin && git merge origin/<base>`) and resolve the conflicts carefully, preferring the intent of both sides — never just take one side blindly.
  2. Run the full test suite + typecheck.
  3. **Show the user the resolution (the conflicted files and how you resolved each) and get an explicit OK before pushing.** Never push a conflict resolution unprompted.
  4. If a conflict is genuinely ambiguous or needs a product call, stop and hand it to the user rather than guessing.

Report mergeability in the final summary (step 5) either way.

### 2. Triage and implement

For each actionable comment, decide **does this make sense?**
- **Implement** if it's a real correctness/clarity/security/consistency improvement that fits the codebase.
- **Skip** if it's wrong, out of scope, a style choice that conflicts with the repo's conventions, or would make things worse. Skipping is fine and expected — but you must record a one-line reason.

**Weight the two reviewers differently:**
- **Greptile (primary):** the default bar above. Trust it; implement solid findings.
- **Codex (advisory, grain of salt):** higher bar. Implement only when it's *clearly* correct and worth the change; lean toward skipping uncertain or stylistic Codex nits (with a reason). **When Codex and Greptile conflict, follow Greptile.** Never let a Codex finding override a deliberate choice Greptile was fine with.

Make the edits. Keep changes tight and matched to the surrounding code (see the `deslop` / `simplify` conventions). Run the repo's lint/typecheck/tests if they're quick and relevant before pushing.

### 3. Commit, push, and re-tag

```bash
git add -A
git commit -m "Address review feedback"   # end with the standard Co-Authored-By trailer
git push
```

The push alone re-triggers **Codex**. To re-trigger **Greptile**, post one PR comment that tags it and records your decisions (attribute the source when it clarifies, e.g. `(Greptile)` / `(Codex)`):

```bash
gh pr comment "$PR" --body "$(cat <<'EOF'
@greptileai I've pushed changes addressing the review.

**Addressed**
- <comment> → <what changed>

**Skipped (with reason)**
- <comment> → <why it doesn't apply>

Please take another look.
EOF
)"
```

If you addressed everything and there's nothing to skip, drop the Skipped section. Tagging `@greptileai` is what triggers Greptile's re-review — don't forget it. (Codex doesn't need a tag; it re-reviews from the push.)

### 4. Check for Greptile's reply (with a give-up window)

Greptile's latency varies — often a couple of minutes, sometimes ~15. You're waiting for Greptile activity newer than your re-tag — which is usually an **in-place edit to its existing summary comment** (`updated_at` advances, `created_at` does not), not a brand-new comment. The poller already keys off `updated_at` for this; if you check by hand, do the same.

**Give-up is time-on-the-PR, not a local timer.** The threshold is measured from the `created_at` of your last `@greptileai` re-tag comment (or, on a brand-new PR, the PR's `createdAt`), default 20 min. This is stateless and resumable — it works the same across `/loop` ticks, a machine sleep, or a new session.

**Pick exactly ONE waiting mechanism for how you were invoked. Never combine them** — no background poller *and* a scheduled wakeup, no `Monitor`, no spawning a process that re-invokes you on top of a loop. That thrash is the #1 failure mode here.

**Under `/loop` (the normal case — this is what `/loop /greptile` uses):**
Do a single, **instantaneous** state read — you effectively already did it in step 1. No sleeping, no `poll-greptile.sh`, no background process. Then branch:
- **Responded** → step 2 (new feedback) or step 5 (clear).
- **Still waiting, window not elapsed** → print one status line — `waiting on Greptile — Nm of <GIVE_UP>m elapsed` — and **end the pass**. The loop is your polling interval; do not block or background anything. For self-paced `/loop`, schedule the next check **~240–270s** out (keeps the prompt cache warm; ~4–5 checks inside a 20-min window). For interval `/loop`, just let the next tick fire.
- **Window elapsed, no response** → go to step 5's give-up branch and stop the loop.

**No `/loop` available (Codex, or a standalone `/greptile` pass), if you want to actively block and wait:**
Run the poller, which sleeps/polls every 30s up to its ~9-min safety cap. It lives in this skill's `scripts/` dir — the skill is symlinked at both `~/.claude/skills/greptile` and `~/.codex/skills/greptile`, so use whichever exists:
```bash
bash "$HOME/.claude/skills/greptile/scripts/poll-greptile.sh" "$REPO" "$PR" "<retag-iso8601>" [GIVE_UP_MINUTES]
# (Codex: swap .claude for .codex)
```
Exit `0` → responded, re-read state and continue. Exit `2` → give-up window elapsed, stop. Exit `1` → hit the safety cap before the window; just re-run it (or wrap the whole pass in an external loop — see Continuous mode). Do **not** also set a `ScheduleWakeup` — the blocking call *is* the wait.

### 5. Done — recommend merge (or give up), do NOT merge

**Greptile is clear** → **stop** and report:
- The PR link and that Greptile has signed off.
- A short list of what you implemented and what you skipped (with reasons), tagged by source where useful.
- **Any Codex-only points you deliberately skipped** — call them out so the user can override if they disagree. (Codex didn't block readiness, but the user should see what it raised.)
- CI status (`gh pr checks "$PR"`) and **merge status** (mergeable / behind / conflicting, per step 1b).
- An explicit: "Ready for your review and merge" — and wait. Never run `gh pr merge`. (If conflicts remain unresolved because you're waiting on the user's OK, say so instead.)

**Give-up window elapsed with no response** → **stop** (don't keep looping) and tell the user Greptile hasn't responded in `GIVE_UP_MINUTES`. If it has *never* responded on this PR, note Greptile may not be installed on this repo. Leave the PR as-is for the user.

Either way, end the pass cleanly — under `/loop`, signal there's nothing left to do so the loop stops.

## Continuous mode

The skill works in both **Claude Code** and **Codex** (symlinked into `~/.claude/skills` and `~/.codex/skills`). The single pass is identical in both — only the way you *keep* listening differs.

**Claude Code** — use the built-in loop:
```
/loop /greptile          # current branch's PR (creates it if needed), or
/loop /greptile 123       # a specific PR
```
Each tick re-runs the pass (instantaneous check per tick — see step 4).

**Codex** (no `/loop`) — either run a single `/greptile` pass that blocks on the poller, or wrap repeated passes in an external loop / cron:
```bash
while :; do codex exec "/greptile 123"; sleep 180; done
```

Either way it converges, because the pass is **idempotent** and the give-up window is **derived from PR timestamps** (not local state) — so it implements new feedback as it arrives, re-tags, and reaches the same end state whether ticks come from `/loop`, an external loop, or you re-running it by hand. Stop when:
- Greptile is clear → reported "ready for merge", or
- the give-up window elapsed with no Greptile response.

## Guardrails

- One PR per invocation; never touch other PRs or branches.
- Never force-push or rewrite history; only add commits to the PR branch.
- Never merge, close, or change PR base. The final merge is always the user's.
- Auto-update a `BEHIND` branch (safe), but never push a conflict resolution without the user's explicit OK — resolving conflicts changes code semantics.
- If a Greptile comment would require a large/risky change or a product decision, skip it and surface it to the user rather than guessing.
- If `gh` isn't authed or the PR can't be found, stop and say so.
