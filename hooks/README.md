# Hooks

Safety hooks for `~/.claude/settings.json`. Copy the JSON snippets below.

## rm -rf Blocker

Blocks destructive `rm -rf` commands. Use `trash` instead.

```json
{
  "hooks": {
    "Bash": [
      {
        "type": "command",
        "command": "if echo \"$CLAUDE_TOOL_INPUT\" | grep -qE 'rm[[:space:]]+-[^[:space:]]*r[^[:space:]]*f'; then echo 'BLOCKED: Use trash instead of rm -rf' >&2; exit 2; fi"
      }
    ]
  }
}
```

## Git Push to Main Blocker

Blocks direct pushes to main/master. Use feature branches.

```json
{
  "hooks": {
    "Bash": [
      {
        "type": "command",
        "command": "if echo \"$CLAUDE_TOOL_INPUT\" | grep -qE 'git[[:space:]]+push.*(main|master)'; then echo 'BLOCKED: Use feature branches, not direct push to main' >&2; exit 2; fi"
      }
    ]
  }
}
```

## Combined Example

Both hooks together in settings.json:

```json
{
  "hooks": {
    "Bash": [
      {
        "type": "command",
        "command": "if echo \"$CLAUDE_TOOL_INPUT\" | grep -qE 'rm[[:space:]]+-[^[:space:]]*r[^[:space:]]*f'; then echo 'BLOCKED: Use trash instead of rm -rf' >&2; exit 2; fi"
      },
      {
        "type": "command",
        "command": "if echo \"$CLAUDE_TOOL_INPUT\" | grep -qE 'git[[:space:]]+push.*(main|master)'; then echo 'BLOCKED: Use feature branches, not direct push to main' >&2; exit 2; fi"
      }
    ]
  }
}
```

## How Hooks Work

| Exit Code | Behavior |
|-----------|----------|
| 0 | Command allowed |
| 1 | Command blocked (silent) |
| 2 | Command blocked (show stderr message) |

Hooks receive the command via `$CLAUDE_TOOL_INPUT` environment variable.
