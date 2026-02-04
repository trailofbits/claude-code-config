# Installation

## Prerequisites

- Claude Code CLI installed
- Node.js 22+
- macOS (for statusline, mlx-serve)

## Option A: Symlinks (Recommended)

Symlinks keep your config in sync with this repo. Pull updates to get the latest.

```bash
cd ~/claude-code-config

# Global instructions
ln -sf "$(pwd)/CLAUDE.md" ~/.claude/CLAUDE.md

# Statusline script
cp scripts/statusline.sh ~/.claude/statusline.sh
```

## Option B: Copy

Copy files if you want to customize without affecting the repo.

```bash
cd ~/claude-code-config

# Global instructions
cp CLAUDE.md ~/.claude/CLAUDE.md

# Statusline script
cp scripts/statusline.sh ~/.claude/statusline.sh
```

## Configure Skills

See [skills/README.md](skills/README.md) for setting up agent-browser and other skills.

## Configure Hooks

Add hooks to `~/.claude/settings.json`. See [hooks/README.md](hooks/README.md) for copy-paste snippets.

## Configure MCP Servers

Add MCP servers to `~/.claude/settings.json`. See [mcp-servers/README.md](mcp-servers/README.md) for configs.

## Configure Statusline

Add to `~/.claude/settings.json`:

```json
{
  "status_line": {
    "script": "~/.claude/statusline.sh"
  }
}
```

## Verify Installation

```bash
# Check CLAUDE.md is linked/copied
cat ~/.claude/CLAUDE.md | head -5

# Check statusline works
~/.claude/statusline.sh

# Start Claude Code - statusline should appear
claude
```
