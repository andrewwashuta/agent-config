#!/usr/bin/env bats
# Tests for sync.sh

load 'test_helper'

setup() {
    setup_test_env
}

teardown() {
    teardown_test_env
}

# =============================================================================
# Status Display Tests
# =============================================================================

@test "sync.sh shows status by default" {
    run run_sync
    [[ "$output" == *"Agent Config Sync Status"* ]]
    [[ "$output" == *"Skills (~/.codex):"* ]]
    [[ "$output" == *"Legend:"* ]]
}

@test "sync.sh shows usage in status" {
    run run_sync
    [[ "$output" == *"./sync.sh add"* ]]
    [[ "$output" == *"./sync.sh remove"* ]]
    [[ "$output" == *"./sync.sh undo"* ]]
}

@test "sync.sh shows synced skills" {
    create_fake_skill "test-skill"
    run_install
    run run_sync
    [[ "$output" == *"test-skill"* ]]
    [[ "$output" == *"synced"* ]]
}

@test "sync.sh shows local-only skills" {
    # Create a local-only skill (not in repo)
    mkdir -p "$FAKE_HOME/.claude/skills/local-skill"
    echo "---" > "$FAKE_HOME/.claude/skills/local-skill/SKILL.md"
    echo "name: local" >> "$FAKE_HOME/.claude/skills/local-skill/SKILL.md"
    echo "description: local" >> "$FAKE_HOME/.claude/skills/local-skill/SKILL.md"
    echo "---" >> "$FAKE_HOME/.claude/skills/local-skill/SKILL.md"

    run run_sync
    [[ "$output" == *"local-skill"* ]]
    [[ "$output" == *"local only"* ]]
}

# =============================================================================
# Add Skill Tests (skills are managed by 'npx skills', not sync.sh)
# =============================================================================

@test "sync.sh add skill fails and points to npx skills" {
    create_fake_skill "my-skill" "$FAKE_HOME/.claude/skills"

    run run_sync add skill my-skill
    [[ "$status" -ne 0 ]]
    [[ "$output" == *"npx skills"* ]]

    # Repo should not have the skill
    [[ ! -d "$FAKE_REPO/.agents/skills/my-skill" ]]
}

@test "sync.sh add skill mentions 'npx skills add'" {
    run run_sync add skill nonexistent
    [[ "$status" -ne 0 ]]
    [[ "$output" == *"npx skills add"* ]]
}

# =============================================================================
# Add Agent Tests
# =============================================================================

@test "sync.sh add agent copies to repo and creates symlink" {
    create_fake_agent "my-agent" "$FAKE_HOME/.claude/agents"

    run_sync add agent my-agent

    assert_regular_file "$FAKE_REPO/agents/my-agent.md"
    assert_symlink "$FAKE_HOME/.claude/agents/my-agent.md" "$FAKE_REPO/agents/my-agent.md"
}

@test "sync.sh add agent creates backup" {
    create_fake_agent "my-agent" "$FAKE_HOME/.claude/agents"
    run_sync add agent my-agent
    assert_backup_exists
    assert_manifest_operation "add-agent"
}

# =============================================================================
# Add Rule Tests
# =============================================================================

@test "sync.sh add rule copies to repo and creates symlink" {
    create_fake_rule "my-rule" "$FAKE_HOME/.claude/rules"

    run_sync add rule my-rule

    assert_regular_file "$FAKE_REPO/rules/my-rule.md"
    assert_symlink "$FAKE_HOME/.claude/rules/my-rule.md" "$FAKE_REPO/rules/my-rule.md"
}

# =============================================================================
# Remove Skill Tests (skills are managed by 'npx skills', not sync.sh)
# =============================================================================

@test "sync.sh remove skill fails and points to npx skills" {
    create_fake_skill "my-skill"
    run_install

    run run_sync remove skill my-skill
    [[ "$status" -ne 0 ]]
    [[ "$output" == *"npx skills"* ]]

    # Repo should still have the skill
    assert_dir "$FAKE_REPO/.agents/skills/my-skill"
}

@test "sync.sh remove skill mentions 'npx skills remove'" {
    run run_sync remove skill nonexistent
    [[ "$status" -ne 0 ]]
    [[ "$output" == *"npx skills remove"* ]]
}

# =============================================================================
# Backups Command Tests
# =============================================================================

@test "sync.sh backups shows 'no backups' when empty" {
    run run_sync backups
    [[ "$output" == *"No backups found"* ]]
}

@test "sync.sh backups lists existing backups" {
    create_fake_agent "my-agent" "$FAKE_HOME/.claude/agents"
    run_sync add agent my-agent

    run run_sync backups
    [[ "$output" == *"Available Backups"* ]]
    [[ "$output" == *"add-agent"* ]]
}

# =============================================================================
# Undo Tests
# =============================================================================

@test "sync.sh undo fails when no backups exist" {
    run run_sync undo
    [[ "$status" -ne 0 ]]
    [[ "$output" == *"No backups found"* ]]
}

@test "sync.sh undo --dry-run shows what would be restored" {
    create_fake_agent "my-agent" "$FAKE_HOME/.claude/agents"
    run_sync add agent my-agent

    run run_sync --dry-run undo
    [[ "$output" == *"[dry-run]"* ]]
    [[ "$output" == *"Would restore"* ]]
}

@test "sync.sh undo restores original files" {
    # Create local agent with specific content
    create_fake_agent "my-agent" "$FAKE_HOME/.claude/agents"
    echo "original content" >> "$FAKE_HOME/.claude/agents/my-agent.md"

    # Add to repo (this backs up the original)
    run_sync add agent my-agent

    # Verify it's now a symlink
    assert_symlink "$FAKE_HOME/.claude/agents/my-agent.md" "$FAKE_REPO/agents/my-agent.md"

    # Undo (with yes response)
    echo "y" | run_sync undo

    # Should be restored as regular file
    [[ ! -L "$FAKE_HOME/.claude/agents/my-agent.md" ]]
    assert_regular_file "$FAKE_HOME/.claude/agents/my-agent.md"
}

# =============================================================================
# Dry-run Global Option Tests
# =============================================================================

@test "sync.sh -n works as global dry-run flag" {
    create_fake_agent "my-agent" "$FAKE_HOME/.claude/agents"
    run run_sync -n add agent my-agent
    [[ "$output" == *"[dry-run]"* ]]
    [[ ! -f "$FAKE_REPO/agents/my-agent.md" ]]
}

@test "sync.sh --dry-run works anywhere in args" {
    create_fake_agent "my-agent" "$FAKE_HOME/.claude/agents"
    run run_sync add --dry-run agent my-agent
    [[ "$output" == *"[dry-run]"* ]]
}
