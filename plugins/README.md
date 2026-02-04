# Plugins

Claude Code plugins extend functionality with skills, agents, and workflows.

## Marketplaces

Add marketplaces to `~/.claude/plugins/known_marketplaces.json`:

```json
{
  "superpowers-marketplace": {
    "source": {
      "source": "github",
      "repo": "obra/superpowers-marketplace"
    },
    "installLocation": "~/.claude/plugins/marketplaces/superpowers-marketplace"
  },
  "trailofbits": {
    "source": {
      "source": "github",
      "repo": "trailofbits/skills"
    },
    "installLocation": "~/.claude/plugins/marketplaces/trailofbits"
  },
  "trailofbits-internal": {
    "source": {
      "source": "github",
      "repo": "trailofbits/skills-internal"
    },
    "installLocation": "~/.claude/plugins/marketplaces/trailofbits-internal"
  },
  "every-marketplace": {
    "source": {
      "source": "github",
      "repo": "EveryInc/compound-engineering-plugin"
    },
    "installLocation": "~/.claude/plugins/marketplaces/every-marketplace"
  },
  "agent-browser": {
    "source": {
      "source": "github",
      "repo": "vercel-labs/agent-browser"
    },
    "installLocation": "~/.claude/plugins/marketplaces/agent-browser"
  }
}
```

## Enabled Plugins

Add to `~/.claude/settings.json`:

```json
{
  "enabledPlugins": {
    "superpowers@superpowers-marketplace": true,
    "superpowers-developing-for-claude-code@superpowers-marketplace": true,
    "compound-engineering@every-marketplace": true,
    "agent-browser@agent-browser": true
  }
}
```

## Recommended Plugins

| Plugin | Marketplace | Description |
|--------|-------------|-------------|
| `superpowers` | superpowers-marketplace | Brainstorming, TDD, debugging, verification workflows |
| `superpowers-developing-for-claude-code` | superpowers-marketplace | Plugin/skill development helpers |
| `compound-engineering` | every-marketplace | Planning, review, work execution workflows |
| `agent-browser` | agent-browser | Browser automation CLI |

## Installing Plugins

After configuring marketplaces, install plugins via Claude Code:

```
/plugins install superpowers
/plugins install compound-engineering
/plugins install agent-browser
```

Or use the CLI:

```bash
claude plugins install superpowers@superpowers-marketplace
claude plugins install compound-engineering@every-marketplace
```

## Updating Plugins

```bash
claude plugins update
```
