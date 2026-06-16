# greptile — auto-tend your PR's code review

A Claude Code / Codex skill that drives a PR through automated review until it's
ready to merge, then hands the merge back to you. It **never merges on its own.**

## What it does

From a feature branch, in one command, it will:

1. **Open the PR** if your branch doesn't have one yet
   (guards against opening from `main`; won't sweep in uncommitted files without asking).
2. **Keep the branch mergeable** — auto-updates if it's behind base; for real
   conflicts it resolves them, runs tests, and asks for your OK before pushing.
3. **Tend the review** — reads the bot feedback, implements what makes sense,
   skips the rest *with a reason*, pushes, and re-tags `@greptileai` for a re-review.
4. **Wait** for the re-review (gives up after ~20 min of silence).
5. **Stop at "ready to merge"** with a summary: what it did, what it skipped,
   CI status, and merge status. You do the final merge.

## Two reviewers, two phases

- **Greptile (primary)** — its verdict gates "ready to merge"; it's the one we re-tag.
- **Codex / `chatgpt-codex-connector` (advisory)** — read with a grain of salt; defers to
  Greptile on conflicts, never blocks, re-reviews automatically on push.

Because Codex re-reviews on *every* push, acting on both reviewers each round makes the
loop churn (each fix spawns fresh Codex nits — it never settles). So the loop runs in
**two phases**:

1. **Converge Greptile** — act on Greptile only; Codex is read but not acted on.
2. **One Codex pass** — once Greptile is clear, implement only clearly-correct Codex
   items once, confirm Greptile is still happy, then **stop**. Remaining Codex nits are
   surfaced for you to act on by hand.

A hard round cap (default 4) backstops the whole thing.

## Install

A skill is just a folder. Copy it into your agent's skills dir — works in
**Claude Code** and **Codex**:

```bash
git clone https://github.com/andrewwashuta/agent-config /tmp/ac
cp -r /tmp/ac/.agents/skills/greptile ~/.claude/skills/greptile   # Claude Code
cp -r /tmp/ac/.agents/skills/greptile ~/.codex/skills/greptile    # Codex
```

Then `/greptile` is available in that agent.

## Update

Re-run the relevant `cp` above — it overwrites your copy with the latest.

## Usage

```
/greptile              # single pass: open the PR (if needed) + one round of feedback
/greptile 123          # single pass on a specific PR
```

**Keep tending continuously:**

- **Claude Code:** `/loop /greptile` (or `/loop /greptile 123`)
- **Codex** (no `/loop`): use the bundled wrapper — the `/loop` equivalent, with a
  built-in round cap and early-exit when the skill signals done:
  ```bash
  bash ~/.codex/skills/greptile/scripts/greptile-loop.sh 123          # defaults: 4 rounds, 180s apart
  bash ~/.codex/skills/greptile/scripts/greptile-loop.sh 123 6 120     # 6 rounds, 120s apart
  ```

The two-phase model + round cap keep it from churning, and the give-up window is
derived from the PR's own timestamps, so it converges the same way however the ticks
are driven.

## Requirements

- `gh` (GitHub CLI) authenticated in the repo you run it in.
- Greptile enabled on the repo (Codex reviewer optional).

## Good to know

- **Repo-agnostic** — works in any repo with Greptile/Codex review.
- **It pauses before anything outward-facing** — opening a PR, committing
  uncommitted work, or pushing a conflict resolution all ask first. So local
  test/scratch files don't get published by surprise.
- **It never merges, closes, force-pushes, or rewrites history.**

See `SKILL.md` for the full behavior.
