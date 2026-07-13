# shepherd — take a PR from open to merge-ready

A Claude Code / Codex skill that shepherds one PR through automated review and
the repo's local-CI signoff until it's ready to merge, then hands the merge back
to you. It **never merges on its own.**

## What it does

From a feature branch, in one command, it will:

1. **Open the PR** if your branch doesn't have one yet
   (guards against opening from `main`; won't sweep in uncommitted files without asking).
2. **Keep the branch mergeable** — auto-updates if it's behind base; for real
   conflicts it resolves them, runs tests, and asks for your OK before pushing.
3. **Tend the review** — reads the bot feedback, implements what makes sense,
   skips the rest *with a reason*, pushes, and re-tags `@greptileai` for a re-review.
4. **Wait** for the re-review (gives up after ~20 min of silence).
5. **Sign off** — in repos that require local CI signoff (e.g. os-june), runs
   `make local-ci` on the final commit so the required `signoff/*` statuses are
   posted and the PR can actually merge.
6. **Stop at "ready to merge"** with a summary: what it did, what it skipped,
   CI status, and merge status. You do the final merge.

## Three reviewers, two phases

- **Greptile (primary)** — its verdict gates "ready to merge"; it's the one we re-tag.
- **Codex / `chatgpt-codex-connector` (advisory)** — read with a grain of salt; defers
  to Greptile on conflicts, never blocks, re-reviews automatically on push.
- **Octopus (advisory)** — a second bot; weaker bug-finder that buries findings in
  collapsed `<details>` tables in its review body. Treated like Codex — read it, but
  never gate or loop on it.

Because the advisory bots re-review on *every* push, acting on all reviewers each round
makes the loop churn (each fix spawns fresh nits — it never settles). So the loop runs in
**two phases**:

1. **Converge Greptile** — act on Greptile only; Codex and Octopus are read but not acted on.
2. **One advisory pass** — once Greptile is clear, implement only clearly-correct
   Codex/Octopus items once, confirm Greptile is still happy, then **stop**. Remaining
   advisory nits are surfaced for you to act on by hand.

A hard round cap (default 4) backstops the whole thing.

## Local CI signoff (os-june and repos like it)

Some repos replace expensive hosted PR checks with local commit-status signoffs that a
ruleset requires before merge. os-june requires `signoff/frontend` and `signoff/rust-macos`.
When it detects such a repo (a `make local-ci` target, `scripts/signoff-*.sh`, or required
`signoff/*` checks on the PR), the skill runs `make local-ci` on the final pushed commit —
path-aware, so it only runs the suites your diff touches. One-time prereq:
`gh extension install basecamp/gh-signoff`. In repos without this mechanism, the step is a no-op.

## Install

A skill is just a folder. Copy it into your agent's skills dir — works in
**Claude Code** and **Codex**:

```bash
git clone https://github.com/andrewwashuta/agent-config /tmp/ac
cp -r /tmp/ac/.agents/skills/shepherd ~/.claude/skills/shepherd   # Claude Code
cp -r /tmp/ac/.agents/skills/shepherd ~/.codex/skills/shepherd    # Codex
```

Then `/shepherd` is available in that agent.

## Update

Re-run the relevant `cp` above — it overwrites your copy with the latest.

## Usage

```
/shepherd              # single pass: open the PR (if needed) + one round of feedback
/shepherd 123          # single pass on a specific PR
```

**Keep tending continuously:**

- **Claude Code:** `/loop /shepherd` (or `/loop /shepherd 123`)
- **Codex** (no `/loop`): use the bundled wrapper — the `/loop` equivalent, with a
  built-in round cap and early-exit when the skill signals done:
  ```bash
  bash ~/.codex/skills/shepherd/scripts/shepherd-loop.sh 123          # defaults: 4 rounds, 180s apart
  bash ~/.codex/skills/shepherd/scripts/shepherd-loop.sh 123 6 120     # 6 rounds, 120s apart
  ```

The two-phase model + round cap keep it from churning, and the give-up window is
derived from the PR's own timestamps, so it converges the same way however the ticks
are driven.

## Requirements

- `gh` (GitHub CLI) authenticated in the repo you run it in.
- Greptile enabled on the repo (Codex / Octopus reviewers optional).
- For local signoff repos: the `basecamp/gh-signoff` gh extension; `signoff/rust-macos`
  is posted from macOS.

## Good to know

- **Repo-agnostic** — works in any repo with Greptile/Codex/Octopus review; the signoff
  step is skipped where it doesn't apply.
- **It pauses before anything outward-facing** — opening a PR, committing
  uncommitted work, or pushing a conflict resolution all ask first. So local
  test/scratch files don't get published by surprise.
- **It never merges, closes, force-pushes, or rewrites history.** It never fakes a
  signoff either — if a required suite can't run locally, it adds the escape-hatch label
  and tells you.

See `SKILL.md` for the full behavior.
