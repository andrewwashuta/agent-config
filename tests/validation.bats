#!/usr/bin/env bats
# Tests for skills validation

load 'test_helper'

setup() {
    setup_test_env
}

teardown() {
    teardown_test_env
}

# =============================================================================
# Validate Command Tests
# =============================================================================

@test "sync.sh validate shows 'no skills' when empty" {
    run run_sync validate
    [[ "$output" == *"No skills found"* ]]
}

@test "sync.sh validate passes for valid skills" {
    create_fake_skill "valid-skill"
    run run_sync validate
    [[ "$status" -eq 0 ]]
    [[ "$output" == *"valid-skill"* ]]
    [[ "$output" == *"All"*"valid"* ]]
}

@test "sync.sh validate passes for multiple valid skills" {
    create_fake_skill "skill-one"
    create_fake_skill "skill-two"
    create_fake_skill "skill-three"
    run run_sync validate
    [[ "$status" -eq 0 ]]
    [[ "$output" == *"skill-one"* ]]
    [[ "$output" == *"skill-two"* ]]
    [[ "$output" == *"skill-three"* ]]
}

@test "sync.sh validate fails for skill without SKILL.md" {
    create_skill_no_md "bad-skill"
    run run_sync validate
    [[ "$status" -ne 0 ]]
    [[ "$output" == *"bad-skill"* ]]
    [[ "$output" == *"Missing SKILL.md"* ]]
}

@test "sync.sh validate fails for skill without frontmatter" {
    create_invalid_skill "bad-skill"
    run run_sync validate
    [[ "$status" -ne 0 ]]
    [[ "$output" == *"bad-skill"* ]]
    [[ "$output" == *"Missing frontmatter"* ]]
}

@test "sync.sh validate fails for skill missing name" {
    mkdir -p "$FAKE_REPO/.agents/skills/bad-skill"
    cat > "$FAKE_REPO/.agents/skills/bad-skill/SKILL.md" << EOF
---
description: Has description but no name
---

# Bad Skill
EOF
    run run_sync validate
    [[ "$status" -ne 0 ]]
    [[ "$output" == *"Missing 'name'"* ]]
}

@test "sync.sh validate fails for skill missing description" {
    mkdir -p "$FAKE_REPO/.agents/skills/bad-skill"
    cat > "$FAKE_REPO/.agents/skills/bad-skill/SKILL.md" << EOF
---
name: bad-skill
---

# Bad Skill
EOF
    run run_sync validate
    [[ "$status" -ne 0 ]]
    [[ "$output" == *"Missing 'description'"* ]]
}

@test "sync.sh validate checks both repo and local skills" {
    # Create one in repo
    create_fake_skill "repo-skill"

    # Create one locally only
    create_fake_skill "local-skill" "$FAKE_HOME/.claude/skills"

    run run_sync validate
    [[ "$status" -eq 0 ]]
    [[ "$output" == *"repo-skill"* ]]
    [[ "$output" == *"local-skill"* ]]
    [[ "$output" == *"(local)"* ]]
}

@test "sync.sh validate checks codex local skills" {
    create_fake_skill "codex-local-skill" "$FAKE_HOME/.codex/skills"

    run run_sync validate
    [[ "$status" -eq 0 ]]
    [[ "$output" == *"codex-local-skill"* ]]
    [[ "$output" == *"(local)"* ]]
}

@test "sync.sh validate doesn't double-count synced skills" {
    create_fake_skill "my-skill"
    run_install

    run run_sync validate

    # Should only appear once (as synced, not as local)
    # grep -c counts lines, not occurrences, and we expect exactly 1 line with "my-skill"
    local count
    count=$(echo "$output" | grep "my-skill" | grep -v "(local)" | wc -l | tr -d ' ')
    [[ "$count" -eq 1 ]]
}

# =============================================================================
# Add Skill is Delegated to 'npx skills'
# =============================================================================

@test "sync.sh add skill is delegated to npx skills" {
    create_fake_skill "good-skill" "$FAKE_HOME/.claude/skills"

    run run_sync add skill good-skill
    [[ "$status" -ne 0 ]]
    [[ "$output" == *"npx skills"* ]]
}

@test "sync.sh add skill update guidance is shown" {
    run run_sync add skill anything
    [[ "$status" -ne 0 ]]
    [[ "$output" == *"npx skills update"* ]]
}

# =============================================================================
# Edge Cases
# =============================================================================

@test "sync.sh validate handles empty SKILL.md" {
    mkdir -p "$FAKE_REPO/.agents/skills/empty-skill"
    touch "$FAKE_REPO/.agents/skills/empty-skill/SKILL.md"

    run run_sync validate
    [[ "$status" -ne 0 ]]
    [[ "$output" == *"empty-skill"* ]]
}

@test "sync.sh validate fails for SKILL.md with only one frontmatter delimiter" {
    mkdir -p "$FAKE_REPO/.agents/skills/bad-skill"
    cat > "$FAKE_REPO/.agents/skills/bad-skill/SKILL.md" << EOF
---
name: bad-skill
description: Only one delimiter

# Bad Skill
EOF
    run run_sync validate
    [[ "$status" -ne 0 ]]
    [[ "$output" == *"bad-skill"* ]]
    [[ "$output" == *"Missing frontmatter"* ]]
}

@test "sync.sh validate passes skill with extra frontmatter fields" {
    mkdir -p "$FAKE_REPO/.agents/skills/extra-skill"
    cat > "$FAKE_REPO/.agents/skills/extra-skill/SKILL.md" << EOF
---
name: extra-skill
description: Has extra fields
version: 1.0.0
author: test
tags: [test, extra]
---

# Extra Skill
EOF
    run run_sync validate
    [[ "$status" -eq 0 ]]
    [[ "$output" == *"extra-skill"* ]]
}
