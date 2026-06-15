# greptile skill

Auto-tend a PR's [Greptile](https://greptile.com) review: create the PR if needed, implement the feedback that makes sense (skip the rest with a reason), push, re-tag `@greptileai`, wait for the re-review, and stop with a merge recommendation once it's clear. **It never merges — that's always yours.**

## Install

A skill is just a folder. Copy it into your Claude Code skills dir:

```bash
git clone https://github.com/andrewwashuta/agent-config /tmp/ac && \
  cp -r /tmp/ac/.agents/skills/greptile ~/.claude/skills/greptile
```

Then `/greptile` and `/loop /greptile` are available in Claude Code.

## Update

Re-run the same command — the `cp` overwrites your copy with the latest version.

## Requirements

- `gh` (GitHub CLI) authenticated in whatever repo you run it in.
- Greptile enabled on that repo.

## Usage

```
/loop /greptile        # from a feature branch: create the PR (if none) and tend its review continuously
/loop /greptile 123    # tend an existing PR continuously
/greptile              # single pass (create PR / one round of feedback), no continuous loop
```

It's repo-agnostic — works in any repo where Greptile is enabled. See `SKILL.md` for the full behavior.
