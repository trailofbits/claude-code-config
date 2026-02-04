# MCP Servers

MCP server configs for `~/.claude/settings.json`.

## Context7

Up-to-date library documentation. No API key required.

```json
{
  "mcpServers": {
    "context7": {
      "command": "npx",
      "args": ["-y", "@upstash/context7-mcp"]
    }
  }
}
```

**Usage:** Ask Claude to look up documentation for any library. Context7 provides current docs, not training data.

## Exa

Web and code search. Requires `EXA_API_KEY`.

```json
{
  "mcpServers": {
    "exa": {
      "command": "npx",
      "args": ["-y", "exa-mcp-server"],
      "env": {
        "EXA_API_KEY": "${EXA_API_KEY}"
      }
    }
  }
}
```

**Setup:**
1. Get API key from [exa.ai](https://exa.ai)
2. Add `export EXA_API_KEY="your-key"` to shell profile

**Usage:** Ask Claude to search the web or find code examples.

## Combined Example

Both servers in settings.json:

```json
{
  "mcpServers": {
    "context7": {
      "command": "npx",
      "args": ["-y", "@upstash/context7-mcp"]
    },
    "exa": {
      "command": "npx",
      "args": ["-y", "exa-mcp-server"],
      "env": {
        "EXA_API_KEY": "${EXA_API_KEY}"
      }
    }
  }
}
```
