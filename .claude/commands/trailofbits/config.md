You are installing or updating Trail of Bits' Claude Code configuration into the user's `~/.claude/` directory.

## Source files

Fetch each file from GitHub using WebFetch. The base URL is:

```
https://raw.githubusercontent.com/trailofbits/claude-code-config/main/
```

Files to fetch when needed:
- `settings.json`
- `claude-md-template.md`
- `mcp-template.json`
- `scripts/statusline.sh`
- `commands/review-pr.md`
- `commands/fix-issue.md`

## Steps

1. **Inventory what exists.** Read `~/.claude/settings.json`, `~/.claude/CLAUDE.md`, `~/.mcp.json`, `~/.claude/statusline.sh`, and check for `~/.claude/commands/review-pr.md` and `~/.claude/commands/fix-issue.md`. Note which files exist and which don't.

2. **Ask the user what to install.** Use AskUserQuestion with a single multi-select question. List each component with a short description. Pre-label components that are missing from `~/.claude/` as recommended. Components:
   - **settings.json** — permissions, hooks, telemetry, statusline config
   - **CLAUDE.md** — global development standards and tool preferences
   - **MCP servers** — Context7, Exa, Granola
   - **Statusline script** — two-line status bar with context/cost tracking
   - **review-pr command** — multi-agent PR review workflow
   - **fix-issue command** — end-to-end issue fixing workflow

3. **Fetch selected files.** Use WebFetch to download only the files needed for the user's selections from the GitHub URLs above. Extract the raw file content from each response.

4. **For each selected component, install it:**

   - **settings.json**: If `~/.claude/settings.json` doesn't exist, write it directly. If it does exist, read both files and merge the repo's keys into the existing file — preserve any user keys that don't conflict. Show the user the merged result and ask for confirmation before writing.

   - **CLAUDE.md**: If `~/.claude/CLAUDE.md` doesn't exist, write the fetched `claude-md-template.md` content to `~/.claude/CLAUDE.md`. If it already exists, tell the user it exists and ask whether to overwrite, skip, or show a diff. Never silently overwrite CLAUDE.md — it likely has personal customizations.

   - **MCP servers**: If `~/.mcp.json` doesn't exist, write the fetched template to `~/.mcp.json` and remind the user to replace `your-exa-api-key-here`. If it exists, read it, merge any missing server entries from the template, and show the result before writing.

   - **Statusline script**: Write to `~/.claude/statusline.sh` and `chmod +x` it. Safe to overwrite — it has no user customization.

   - **Commands**: Write to `~/.claude/commands/review-pr.md` and/or `~/.claude/commands/fix-issue.md`. Create the directory if needed. Safe to overwrite.

5. **Self-install.** After completing the user's selections, also install this setup command itself to `~/.claude/commands/trailofbits/config.md` so the user can run `/trailofbits:config` from any directory in the future without needing the repo cloned.

6. **Post-install.** Summarize what was installed/updated. If MCP servers were installed, remind the user about the Exa API key. If CLAUDE.md was installed, suggest they review and customize it.
