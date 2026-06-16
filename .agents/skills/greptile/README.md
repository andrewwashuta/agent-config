# greptile skill

Auto-tend a PR's automated code review: create the PR if needed, implement the feedback that makes sense (skip the rest with a reason), push, re-tag `@greptileai`, wait for the re-review, keep the branch mergeable, and stop with a merge recommendation once it's clear. **It never merges — that's always yours.**

Reads **two** reviewers: [Greptile](https://greptile.com) (primary — gates merge-readiness, gets re-tagged) and Codex / `chatgpt-codex-connector` (secondary, advisory — taken with a grain of salt, never blocks).

## Install

A skill is just a folder. Copy it into your agent's skills dir — works in **Claude Code** and **Codex**:

```bash
git clone https://github.com/andrewwashuta/agent-config /tmp/ac
cp -r /tmp/ac/.agents/skills/greptile ~/.claude/skills/greptile   # Claude Code
cp -r /tmp/ac/.agents/skills/greptile ~/.codex/skills/greptile    # Codex
```

Then `/greptile` is available in that agent.

## Update

Re-run the relevant `cp` above — it overwrites your copy with the latest version.

## Requirements

- `gh` (GitHub CLI) authenticated in whatever repo you run it in.
- Greptile enabled on that repo (Codex reviewer optional).

## Usage

```
/greptile              # single pass: create the PR (if none) + one round of feedback
/greptile 123          # single pass on a specific PR
```

**Keep tending continuously:**

- Claude Code: `/loop /greptile` (or `/loop /greptile 123`)
- Codex (no `/loop`): wrap repeated passes, e.g. `while :; do codex exec "/greptile 123"; sleep 180; done`

The pass is idempotent and the give-up window is derived from the PR's own timestamps, so it converges the same way however the ticks are driven. Repo-agnostic — works in any repo where Greptile is enabled. See `SKILL.md` for full behavior.
