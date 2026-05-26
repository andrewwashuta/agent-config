# Agent Config

Personal agent settings, skills, agents, and rules, synced across machines via symlinks.

## Commands

```bash
./install.sh              # Set up symlinks (run after cloning)
./install.sh --dry-run    # Preview what would be done
./sync.sh                 # Show sync status
./sync.sh add <type> <name>     # Add a local agent/rule to repo
./sync.sh remove <type> <name>  # Remove an agent/rule from repo (keeps local)
./sync.sh pull            # Pull latest and reinstall symlinks
./sync.sh push            # Commit and push changes
./sync.sh undo            # Restore from last backup
./sync.sh validate        # Validate all skills
./sync.sh backups         # List available backups
bats tests/               # Run tests

npx skills add <source>   # Add a skill (skills are managed by npx skills)
npx skills update         # Update tracked skills to latest
npx skills list           # List installed skills
```

`sync.sh` add/remove types: `agent`, `rule`. Skills are managed by `npx skills` — the
store lives in `.agents/skills/` and `install.sh` symlinks it into `~/.claude` / `~/.codex`.

## Testing

Tests use Bats. Run `bats tests/` to execute all tests. Tests run in isolated temp directories.

See [.claude/rules/testing.md](.claude/rules/testing.md) for testing conventions.

## Key Files

- `install.sh` - Symlinks skills (`.agents/skills/`), agents, rules, settings into ~/.claude and ~/.codex
- `sync.sh` - Manages syncing agents/rules and validating skills; `push`/`pull`/`undo`
- `.agents/skills/` - Skill store, managed by `npx skills`; `skills-lock.json` tracks upstream sources
- `tests/` - Bats test suite

For detailed workflows, see [.claude/rules/workflows.md](.claude/rules/workflows.md).

## Verification

After making changes:
- `bats tests/` - Run all tests
- `./sync.sh validate` - Validate all skills
