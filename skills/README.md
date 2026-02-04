# Skills

Skills extend Claude Code with domain-specific capabilities. This directory can hold custom skills or symlinks to installed ones.

## agent-browser

Browser automation CLI for AI agents. Handles web navigation, form filling, screenshots, and data extraction.

### Install

```bash
npm install -g agent-browser
```

### Link Skill to Claude Code

The skill file ships with agent-browser. Find and symlink it:

```bash
# Find the installed skill location
SKILL_PATH=$(npm root -g)/agent-browser/skills/agent-browser/SKILL.md

# Verify it exists
ls -la "$SKILL_PATH"

# Create skills directory and symlink
mkdir -p ~/.claude/skills/agent-browser
ln -sf "$SKILL_PATH" ~/.claude/skills/agent-browser/SKILL.md
```

### Verify

```bash
# Check symlink
ls -la ~/.claude/skills/agent-browser/

# Test agent-browser
agent-browser --version
agent-browser open https://example.com
agent-browser snapshot -i
agent-browser close
```

### Quick Reference

```bash
agent-browser open <url>        # Navigate
agent-browser snapshot -i       # Get element refs (@e1, @e2)
agent-browser click @e1         # Click element
agent-browser fill @e2 "text"   # Fill input
agent-browser screenshot        # Capture screenshot
agent-browser close             # Close browser
```

**Workflow:** open → snapshot → interact → re-snapshot (after navigation)

## Adding Custom Skills

Create a directory under `~/.claude/skills/` with a `SKILL.md` file:

```
~/.claude/skills/
└── my-skill/
    └── SKILL.md
```

Skill files use YAML frontmatter:

```markdown
---
name: my-skill
description: What this skill does and when to use it
---

# My Skill

Instructions for Claude...
```
