# Claude Code Config

Shareable Claude Code configuration for team onboarding. Clone this repo and get an upgraded Claude Code experience with curated settings, skills, and tooling.

## What's Included

| Component | Description |
|-----------|-------------|
| `CLAUDE.md` | Global development standards (code quality, tooling, workflows) |
| `hooks/` | Safety hooks (rm-rf blocker, git push protection) |
| `scripts/` | Statusline, local LLM server |
| `skills/` | Skill setup (agent-browser) |
| `mcp-servers/` | Context7, Exa MCP configs |
| `guides/` | Quick reference cheatsheet |

## Quick Start

```bash
git clone <repo-url> ~/claude-code-config
cd ~/claude-code-config

# Symlink global instructions
ln -sf "$(pwd)/CLAUDE.md" ~/.claude/CLAUDE.md

# Copy statusline script
cp scripts/statusline.sh ~/.claude/statusline.sh

# Add hooks to ~/.claude/settings.json (see hooks/README.md)
# Add MCP servers to ~/.claude/settings.json (see mcp-servers/README.md)
```

See [INSTALL.md](INSTALL.md) for detailed setup options.

## File Overview

```
claude-code-config/
├── README.md              # This file
├── INSTALL.md             # Setup instructions
├── CLAUDE.md              # Global development standards
├── hooks/
│   └── README.md          # Hook configs (copy-paste JSON)
├── scripts/
│   ├── statusline.sh      # Two-line status bar
│   └── mlx-serve          # Local LLM server (Apple Silicon)
├── skills/
│   └── README.md          # Skill setup (agent-browser)
├── mcp-servers/
│   └── README.md          # MCP server configs
└── guides/
    └── quick-reference.md # Skills/commands cheatsheet
```

## Requirements

- Claude Code CLI
- Node.js 22+
- macOS (for statusline, mlx-serve)
