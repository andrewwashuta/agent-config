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

## Two reviewers

- **Greptile (primary)** — its verdict gates "ready to merge"; it's the one we re-tag.
- **Codex / `chatgpt-codex-connector` (advisory)** — read with a grain of salt:
  higher bar to act on, defers to Greptile on conflicts, never blocks merge-readiness,
  re-reviews automatically on push. Skipped Codex points are surfaced so you can override.

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
- **Codex** (no `/loop`): wrap repeated passes, e.g.
  `while :; do codex exec "/greptile 123"; sleep 180; done`

The pass is idempotent and the give-up window is derived from the PR's own
timestamps, so it converges the same way however the ticks are driven.

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
