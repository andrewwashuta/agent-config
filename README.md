# claude-config

My agent configuration for [Claude Code](https://docs.anthropic.com/en/docs/claude-code) and Codex, synced across machines via symlinks.

## Quick start

```bash
git clone https://github.com/andrewwashuta/claude-config.git
cd claude-config
./install.sh
```

## What's included

### Settings
- `settings.json` - Global permissions and preferences
- `statusline.sh` - Custom statusline showing token usage

### Skills
Reusable capabilities your coding agents can invoke, managed by [`npx skills`](https://skills.sh).
The skill store is committed to the repo at `.agents/skills/`; `install.sh` symlinks each skill
into `~/.claude/skills/` and `~/.codex/skills/`.

Run `npx skills list` to see everything installed. Five skills are tracked to an upstream
source and can be refreshed with `npx skills update`:

| Skill | Source |
|-------|--------|
| `impeccable` | `pbakaus/impeccable` — frontend design suite (audit, polish, animate, …) |
| `transitions-dev` | `jakubantalik/transitions.dev` — production-ready CSS transitions |
| `shadcn` | `shadcn/ui` — shadcn component workflows |
| `recall` | `arjunkmrm/recall` — search past sessions |
| `share-video` | `mainframecomputer/mainframe-plugins` — share short explainer videos via Mainframe |

The remaining skills are local (no upstream repo) — they live in the store and travel with
this repo. To give one update tracking later, re-add it: `npx skills add <github-source>`.

### Agents
- `security-reviewer` - Security review subagent

## Managing your config

```bash
# See what's synced vs local-only
./sync.sh

# Preview what install would do
./install.sh --dry-run

# Add / update / remove a skill (skills are managed by npx skills)
npx skills add <github-source>
npx skills update
npx skills remove <name>

# Add a local agent or rule to the repo
./sync.sh add agent my-agent
./sync.sh push

# Pull changes on another machine
./sync.sh pull
```

After `npx skills add/remove`, run `./install.sh` to refresh the `~/.claude` symlinks,
then `./sync.sh push` to commit the updated store.

### Safe operations with backups

All destructive operations create timestamped backups:

```bash
# List available backups
./sync.sh backups

# Restore from last backup
./sync.sh undo
```

### Validate skills

```bash
./sync.sh validate
```

Skills must have a `SKILL.md` with frontmatter containing `name` and `description`.

## Testing

Tests use [Bats](https://github.com/bats-core/bats-core) (Bash Automated Testing System).

```bash
# Install bats (one-time)
brew install bats-core

# Run all tests
bats tests/

# Run specific test file
bats tests/install.bats
bats tests/sync.bats
bats tests/validation.bats
```

Tests run in isolated temp directories and don't affect your actual `~/.claude` config.

## Directory structure

```
claude-config/
├── settings.json      # Claude Code settings
├── statusline.sh      # Optional statusline script
├── .agents/skills/    # Skill store (managed by npx skills)
├── skills-lock.json   # npx skills manifest (tracked skills + sources)
├── agents/            # Subagent definitions
├── tests/             # Bats tests
└── install.sh         # Symlink installer
```

## See also

- [Claude Code docs](https://docs.anthropic.com/en/docs/claude-code)
