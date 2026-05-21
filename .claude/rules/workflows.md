# Workflows

## Setting up on a new machine

```bash
git clone git@github.com:andrewwashuta/claude-config.git ~/claude-config
cd ~/claude-config
./install.sh
```

Creates symlinks from `~/.claude/` to this repo, including the skill store in
`.agents/skills/` (which is committed, so skills come down with the clone).
Local-only items are preserved.

### Dry-run mode

Preview what would happen without making changes:

```bash
./install.sh --dry-run
```

### Handling conflicts

If a local file differs from the repo version, you'll be prompted:
- `[r]` Use repo version (backs up local first)
- `[l]` Keep local version (skip this item)
- `[d]` Show diff between versions
- `[q]` Quit

Use `--force` to automatically use repo versions (still creates backups).

## Sync status legend

```bash
./sync.sh
```

Shows status grouped by type (Skills, Agents, Rules):

- `✓` synced (symlinked to this repo)
- `○` local only (not in repo)
- `⚠` conflict (exists in both - run `./install.sh` to fix)
- `→` external (symlinked elsewhere)

## Adding skills

Skills are managed by [`npx skills`](https://skills.sh), not `sync.sh`:

```bash
npx skills add <github-source>   # e.g. npx skills add pbakaus/impeccable
npx skills update                # update tracked skills to latest
npx skills remove <name>
```

These write the skill store under `.agents/skills/`. Afterwards:

```bash
./install.sh        # refresh ~/.claude / ~/.codex symlinks
./sync.sh push      # commit the updated store + skills-lock.json
```

## Adding / removing agents and rules

```bash
./sync.sh add agent <name>   # Add an agent file (without .md extension)
./sync.sh add rule <name>    # Add a rule file (without .md extension)
./sync.sh remove agent <name>
./sync.sh remove rule <name>
./sync.sh push
```

`add` copies the item to the repo and replaces the local file with a symlink;
`remove` deletes it from the repo but keeps a local copy.

## Backups and undo

All destructive operations create timestamped backups in `.backup/`.

```bash
./sync.sh backups            # List available backups
./sync.sh undo               # Restore from last backup
./sync.sh undo --dry-run     # Preview what would be restored
```

## Validating skills

Check that all skills have valid SKILL.md files:

```bash
./sync.sh validate
```

Skills must have frontmatter with `name` and `description`:

```yaml
---
name: my-skill
description: What this skill does
---
```

## Dry-run mode

Preview any command without making changes:

```bash
./sync.sh --dry-run add agent my-agent
./sync.sh -n remove rule my-rule
./install.sh --dry-run
```

## Keeping items local-only

Any item in `~/.claude/` that isn't symlinked stays local. The install script only creates symlinks for what's in this repo—it never deletes local files.

Use this for work-specific or experimental items.

## Directory structure

```
~/.claude/
├── skills/          # Symlinks → claude-config/.agents/skills/* (managed by npx skills)
├── agents/          # Subagent markdown files
├── rules/           # Rule markdown files
├── settings.json
└── statusline.sh
```
