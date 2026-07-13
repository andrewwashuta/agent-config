---
name: shepherd
description: Shepherd one PR from open to merge-ready — create the PR if the current branch doesn't have one yet, tend its automated review (Greptile primary; Codex and Octopus advisory), implement the changes that make sense (skip the rest with a reason), push, re-tag @greptileai for a re-review, and — in repos that require local CI signoff (e.g. os-june's `make local-ci`, which posts the required `signoff/frontend` and `signoff/rust-macos` statuses) — run that signoff on the final commit so the PR can actually merge. Stops before merging — you do the final merge. Use when asked to "open a PR and shepherd it", "handle the bot review", "address Greptile/Codex/Octopus", "sign off the PR", or to keep listening on a PR. Pair with /loop to keep tending continuously.
---

# Shepherd a PR through review + signoff to merge-ready

Drive one PR from wherever it is to a clean, mergeable state: open it if it doesn't exist, tend its automated code review, and post the local-CI signoffs the repo's ruleset requires. **You do not merge** — you stop once the review is happy and the required statuses are green, and hand the merge back to the user.

Three reviewers, weighted differently:
- **Greptile — primary.** Its verdict gates "ready to merge", and `@greptileai` is what you re-tag for a re-review.
- **Codex (`chatgpt-codex-connector`) — advisory.** Read it, but take it with a grain of salt: it's less reliable than Greptile. Apply a higher bar (see step 2), don't gate merge-readiness on it, and don't loop waiting for it.
- **Octopus — advisory.** A second bot reviewer. Weaker still as a bug-finder (it tends to summarize and hedge, and it hides findings in collapsed `<details>` tables inside its *review body*, not always in inline threads). Treat it exactly like Codex — advisory, never blocks, don't loop on it — but read all three surfaces so you don't miss a buried finding.

Codex and Octopus together are the **advisory tier**. Both re-review on push, so both feed the churn problem the two-phase loop exists to prevent (step 1).

## Scope

- Works on **one PR at a time**, in whatever repo is the current working directory. Repo-agnostic — use it in any repo where Greptile / Codex / Octopus review. The signoff step (step 3b) is a no-op in repos that don't use local CI signoff.
- Target PR: the argument if given (`/shepherd 123` or a PR URL), otherwise the PR for the current branch — **and if the current branch has no PR yet, create one first** (step 0).
- Reviewer authors, matched case-insensitively (never hard-code one exact login):
  - **Greptile** — login contains `greptile` (e.g. `greptile-apps[bot]`).
  - **Codex** — login contains `chatgpt-codex-connector` (or `codex`).
  - **Octopus** — login contains `octopus`.
- If no Greptile author ever appears (after the give-up window in step 4), assume Greptile isn't installed on this repo and tell the user. Codex / Octopus may or may not be present — their absence is fine.

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
# Inline comments + issue comments + reviews (from ALL reviewers):
gh api "repos/$REPO/pulls/$PR/comments" --paginate
gh api "repos/$REPO/issues/$PR/comments" --paginate
gh api "repos/$REPO/pulls/$PR/reviews" --paginate
```

Read feedback from **all three** authors (match `greptile`, `chatgpt-codex-connector`/`codex`, and `octopus`, case-insensitively), but keep them tagged by source — Greptile is primary, Codex and Octopus are advisory (step 2 weights them). Check every surface: inline review comments, review *bodies* (Octopus buries findings in collapsed `<details>` tables here), and the summary comment (Greptile puts outside-the-diff findings only in its summary).

**Greptile re-reviews by EDITING its summary comment in place** — it does NOT post a fresh comment each round. It keeps one summary comment (with a confidence score like `4/5` → `5/5` and a verdict like "safe to merge") and updates it. So:
- Detect new activity by `updated_at`, **not** `created_at` — an in-place edit bumps `updated_at` while `created_at` stays put. Keying off `created_at` will miss the re-review entirely (this was a real bug).
- The signal of "did Greptile respond to my re-tag?" is: the summary comment's `updated_at` is newer than your last re-tag, OR a new inline comment/review appeared after it.
- The signal of "is it clear?" lives in the **body** of that latest summary comment — its confidence score and verdict, and whether any P0/P1/actionable findings remain. Read the body; don't infer from comment count.

Codex (`chatgpt-codex-connector`) and Octopus re-review **on push** (no `@` tag needed), so their latest comments after your last push are their current take. (If Octopus turns out to need an explicit re-trigger comment on this repo, observe the convention from recent PRs and adapt — but never gate or loop on it.)

**The loop runs in TWO PHASES to avoid reviewer churn.** The advisory bots (Codex, Octopus) re-review on *every push*, so acting on them each round means every fix spawns fresh advisory nits and the loop never converges (this is the real-world failure: one Greptile review, but Codex re-reviewing 3+ times, each with new findings). The fix: converge Greptile first, then do a single advisory pass.

Determine which **phase + state** you're in (**gated on Greptile** — the advisory bots never block):

**Phase A — converge Greptile (default).** Act on Greptile *only*; Codex and Octopus are **read-only** here — collect their findings for later, but do NOT implement them and do NOT let them trigger a push.
- **New Greptile feedback** — Greptile's latest summary/inline has actionable findings newer than your last push/reply → step 2 (Greptile items only).
- **Waiting** — nothing from Greptile newer than your last re-tag (`updated_at` unchanged) → step 4.
- **Greptile clear** — verdict is approval / "safe to merge" with no actionable findings (review state APPROVED counts) → advance to **Phase B**.
- **Round cap** — if you've already done `MAX_ROUNDS` (default **4**) Greptile address→push cycles without reaching clear, stop and hand the rest to the user (step 5 give-up). Never loop forever.

**Phase B — one advisory pass, then STOP.** Entered only once Greptile is clear:
- Do exactly ONE pass implementing the *clearly-correct* Codex and Octopus findings (skip the rest with reasons). Push once.
- Re-tag Greptile once and wait once, to confirm the advisory-driven change didn't regress its verdict. Greptile still clear → step 5 (done). Greptile re-opens → at most ONE more Greptile round, then stop regardless.
- **Never re-engage Codex or Octopus after this push.** Their reaction to the Phase-B push is exactly the churn we're avoiding — surface any remaining advisory nits in the report for the user instead.

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
  Then re-run the repo's quick checks (lint/typecheck/tests) to confirm the update didn't break anything, and note it in your next re-tag comment. **An update-branch push is a new HEAD — any prior `signoff/*` statuses are now stale (step 3b); re-post them.**
- **`CONFLICTING` / `DIRTY`** (real conflicts) → **do NOT resolve silently.** Resolving conflicts changes code semantics, so:
  1. Merge base in locally (`git fetch origin && git merge origin/<base>`) and resolve the conflicts carefully, preferring the intent of both sides — never just take one side blindly.
  2. Run the full test suite + typecheck.
  3. **Show the user the resolution (the conflicted files and how you resolved each) and get an explicit OK before pushing.** Never push a conflict resolution unprompted.
  4. If a conflict is genuinely ambiguous or needs a product call, stop and hand it to the user rather than guessing.

**Required status checks count toward mergeability.** If the repo's ruleset requires signoff statuses (e.g. `signoff/frontend`, `signoff/rust-macos`) and they're missing/failing/pending for the current HEAD, the PR is **not** mergeable no matter how happy Greptile is — that's step 3b's job. Check them:
```bash
gh pr view "$PR" --json statusCheckRollup \
  -q '.statusCheckRollup[] | select((.context // .name) | test("signoff/")) | "\(.context // .name)\t\(.state // .conclusion)"'
```

Report mergeability (including any required signoff status) in the final summary (step 5).

### 2. Triage and implement

For each actionable comment, decide **does this make sense?**
- **Implement** if it's a real correctness/clarity/security/consistency improvement that fits the codebase.
- **Skip** if it's wrong, out of scope, a style choice that conflicts with the repo's conventions, or would make things worse. Skipping is fine and expected — but you must record a one-line reason.

**Which reviewer you act on depends on the phase (see step 1):**
- **Phase A — Greptile only.** Implement Greptile's solid findings; trust it. Codex and Octopus findings are collected but NOT implemented yet (acting on them now is what causes the churn).
- **Phase B — one advisory pass.** Higher bar: implement only *clearly-correct* Codex/Octopus findings worth the change; skip uncertain/stylistic nits (with a reason). **When an advisory bot conflicts with Greptile, follow Greptile** — never let a Codex or Octopus finding override a choice Greptile was fine with.

Make the edits. Keep changes tight and matched to the surrounding code (see the `deslop` / `simplify` conventions). Run the repo's lint/typecheck/tests if they're quick and relevant before pushing.

### 3. Commit, push, and re-tag

```bash
git add -A
git commit -m "Address review feedback"   # end with the standard Co-Authored-By trailer
git push
```

The push alone re-triggers **Codex** and **Octopus**. To re-trigger **Greptile**, post one PR comment that tags it and records your decisions (attribute the source when it clarifies, e.g. `(Greptile)` / `(Codex)` / `(Octopus)`):

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

If you addressed everything and there's nothing to skip, drop the Skipped section. Tagging `@greptileai` is what triggers Greptile's re-review — don't forget it. (Codex and Octopus don't need a tag; they re-review from the push.)

### 3b. Post required local-CI signoffs (repos that use them)

Some repos replace expensive hosted PR checks with **local commit-status signoffs** that a repo ruleset requires before merge. In **os-june**, the `main protection` ruleset requires `signoff/frontend` and `signoff/rust-macos`; hosted CI deliberately skips those suites, so a PR **cannot merge until you post them locally** — a green Greptile verdict is not enough on its own.

**Detect whether this repo uses it** (any of):
- a `local-ci` make target exists — `make -n local-ci` succeeds — or `scripts/signoff-*.sh` are present, or
- the PR's required checks include `signoff/*` contexts that are missing/pending (the step-1b query).

If none apply, this step is a no-op — skip it.

**If it does, post the signoffs on the pushed HEAD.** The signoff is tied to the exact commit, so the branch must be committed and pushed with a clean tree first (step 3 already did this):

```bash
make local-ci     # path-aware: runs only the suites the diff touches, then posts
                  # signoff/frontend + signoff/rust-macos (as "not applicable" when
                  # the changed paths don't need that suite — keeps docs-only PRs mergeable)
```

Rules and gotchas:
- **One-time prereq:** the Basecamp extension — `gh extension install basecamp/gh-signoff`. If it's missing, `make local-ci` stops and says so; install it rather than skipping the gate. (Do **not** run `gh signoff install` — it writes classic branch protection that can bypass the repo's ruleset.)
- `signoff/rust-macos` must be posted **from macOS** when Rust paths changed (it mirrors the skipped macOS runner). On non-macOS, add the escape-hatch label instead (below).
- **The status is bound to the exact commit — any later push invalidates it.** So don't waste the heavy test run every round: the natural place to sign off is **once, on the final commit, right before you declare merge-ready** (step 5), after Greptile is clear and no more pushes are coming. If you do sign off earlier and then push again (a fix, an advisory pass, or a `BEHIND` branch update), you must re-run `make local-ci` on the new HEAD.
- **If local tooling/hardware blocks a suite,** don't fake the gate — add the repo's escape-hatch label so hosted CI covers it, and note the blocker: os-june uses `run-frontend-ci` (hosted frontend typecheck + Vitest) and `run-macos-ci` (hosted Tauri Rust clippy + tests). Individual targets `make signoff-frontend` / `make signoff-rust-macos` exist if you need to post just one.

### 4. Check for Greptile's reply (with a give-up window)

Greptile's latency varies — often a couple of minutes, sometimes ~15. You're waiting for Greptile activity newer than your re-tag — which is usually an **in-place edit to its existing summary comment** (`updated_at` advances, `created_at` does not), not a brand-new comment. The poller already keys off `updated_at` for this; if you check by hand, do the same.

**Give-up is time-on-the-PR, not a local timer.** The threshold is measured from the `created_at` of your last `@greptileai` re-tag comment (or, on a brand-new PR, the PR's `createdAt`), default 20 min. This is stateless and resumable — it works the same across `/loop` ticks, a machine sleep, or a new session.

**Pick exactly ONE waiting mechanism for how you were invoked. Never combine them** — no background poller *and* a scheduled wakeup, no `Monitor`, no spawning a process that re-invokes you on top of a loop. That thrash is the #1 failure mode here.

**Under `/loop` (the normal case — this is what `/loop /shepherd` uses):**
Do a single, **instantaneous** state read — you effectively already did it in step 1. No sleeping, no `poll-greptile.sh`, no background process. Then branch:
- **Responded** → step 2 (new feedback) or step 5 (clear).
- **Still waiting, window not elapsed** → print one status line — `waiting on Greptile — Nm of <GIVE_UP>m elapsed` — and **end the pass**. The loop is your polling interval; do not block or background anything. For self-paced `/loop`, schedule the next check **~240–270s** out (keeps the prompt cache warm; ~4–5 checks inside a 20-min window). For interval `/loop`, just let the next tick fire.
- **Window elapsed, no response** → go to step 5's give-up branch and stop the loop.

**No `/loop` available (Codex, or a standalone `/shepherd` pass), if you want to actively block and wait:**
Run the poller, which sleeps/polls every 30s up to its ~9-min safety cap. It lives in this skill's `scripts/` dir — the skill is symlinked at both `~/.claude/skills/shepherd` and `~/.codex/skills/shepherd`, so use whichever exists:
```bash
bash "$HOME/.claude/skills/shepherd/scripts/poll-greptile.sh" "$REPO" "$PR" "<retag-iso8601>" [GIVE_UP_MINUTES]
# (Codex: swap .claude for .codex)
```
Exit `0` → responded, re-read state and continue. Exit `2` → give-up window elapsed, stop. Exit `1` → hit the safety cap before the window; just re-run it (or wrap the whole pass in an external loop — see Continuous mode). Do **not** also set a `ScheduleWakeup` — the blocking call *is* the wait.

### 5. Done — recommend merge (or give up), do NOT merge

**Greptile is clear** → before you call it ready, make sure the merge gates are actually green:
1. **Post the required signoffs on the final commit** (step 3b) if this repo uses local CI signoff and no more pushes are coming. Confirm `signoff/frontend` and `signoff/rust-macos` are green (or "not applicable") for the current HEAD.
2. Then **stop** and report:
   - The PR link and that Greptile has signed off.
   - A short list of what you implemented and what you skipped (with reasons), tagged by source where useful.
   - **Any Codex/Octopus-only points you deliberately skipped** — call them out so the user can override if they disagree. (They didn't block readiness, but the user should see what they raised.)
   - CI status (`gh pr checks "$PR"`) and **merge status** — mergeable / behind / conflicting (per step 1b), plus the state of any required `signoff/*` checks.
   - An explicit: "Ready for your review and merge" — and wait. Never run `gh pr merge`. (If conflicts remain unresolved because you're waiting on the user's OK, or a signoff is blocked on tooling, say so instead.)

**Give-up window elapsed with no response** → **stop** (don't keep looping) and tell the user Greptile hasn't responded in `GIVE_UP_MINUTES`. If it has *never* responded on this PR, note Greptile may not be installed on this repo. Leave the PR as-is for the user.

Either way, end the pass cleanly — under `/loop`, signal there's nothing left to do so the loop stops.

**Terminal-state signal (for the Codex wrapper).** Whenever you reach a terminal state — Greptile clear / ready-to-merge, give-up, or the `MAX_ROUNDS` cap — and the env var `SHEPHERD_DONE_FILE` is set, touch it so an external loop can exit early:
```bash
[ -n "${SHEPHERD_DONE_FILE:-}" ] && : > "$SHEPHERD_DONE_FILE"
```
Only touch it on a *terminal* state — never when you're still mid-convergence or waiting.

## Continuous mode

The skill works in both **Claude Code** and **Codex** (symlinked into `~/.claude/skills` and `~/.codex/skills`). The single pass is identical in both; only the way you *keep* listening differs. **Convergence is governed by the two-phase model in step 1** — that's what keeps the loop from churning, regardless of which agent drives the ticks.

**Claude Code** — use the built-in loop:
```
/loop /shepherd          # current branch's PR (creates it if needed), or
/loop /shepherd 123       # a specific PR
```
Each tick re-runs the pass (instantaneous check per tick — see step 4).

**Codex** (no `/loop`) — use the bundled wrapper, which is the `/loop /shepherd` equivalent: bounded rounds, paced, with early-exit when the skill signals done:
```bash
bash ~/.codex/skills/shepherd/scripts/shepherd-loop.sh 123          # PR 123, defaults (4 rounds, 180s apart)
bash ~/.codex/skills/shepherd/scripts/shepherd-loop.sh 123 6 120     # 6 rounds, 120s apart
```
(Plain fallback if you don't want the wrapper: `while :; do codex exec "/shepherd 123"; sleep 180; done` — but you lose the round cap and early-exit.)

It converges because: (1) the **two-phase model** stops the advisory bots from re-opening the loop, (2) the pass is **idempotent** with a give-up window **derived from PR timestamps** (not local state), and (3) the **`MAX_ROUNDS` cap** (default 4) is a hard backstop. The end state is the same whether ticks come from `/loop`, the wrapper, or you re-running by hand. Stop when:
- Greptile is clear → one advisory pass → signoffs posted → "ready for merge", or
- the give-up window elapsed, or the round cap was hit.

## Guardrails

- One PR per invocation; never touch other PRs or branches.
- Never force-push or rewrite history; only add commits to the PR branch.
- Never merge, close, or change PR base. The final merge is always the user's.
- Auto-update a `BEHIND` branch (safe), but never push a conflict resolution without the user's explicit OK — resolving conflicts changes code semantics. After any new push (fix, advisory pass, branch update), re-post the signoffs — they're bound to HEAD.
- Never fake a signoff. If a required `signoff/*` suite can't run locally, add the repo's escape-hatch label and say so — don't post a green status you didn't earn.
- If a review comment would require a large/risky change or a product decision, skip it and surface it to the user rather than guessing.
- If `gh` isn't authed or the PR can't be found, stop and say so.
