# claude-code-config

Reference setup for Claude Code at Trail of Bits. Not a plugin -- just documentation and config files you copy into place.

## Contents

- [Prerequisites](#prerequisites)
- [Shell Setup](#shell-setup)
- [Sandboxing](#sandboxing)
- [Global CLAUDE.md](#global-claudemd)
- [Hooks](#hooks)
- [Settings](#settings)
- [Plugins and Skills](#plugins-and-skills)
- [MCP Servers](#mcp-servers)
- [Web Browsing](#web-browsing)
- [Local Models](#local-models)
- [Example Commands](#example-commands)
- [Continuous Improvement](#continuous-improvement)
- [Recommended Reading](#recommended-reading)

## Prerequisites

Install core tools via Homebrew:

```bash
brew install jq ripgrep fd ast-grep shellcheck shfmt \
  actionlint zizmor macos-trash node@22 pnpm uv
```

Python tools (via uv):

```bash
uv tool install ruff
uv tool install ty
uv tool install pip-audit
```

Rust toolchain:

```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
cargo install prek worktrunk cargo-deny cargo-careful
```

Node tools:

```bash
npm install -g oxlint agent-browser
```

## Shell Setup

Add to `~/.zshrc`:

```bash
alias claude-yolo="claude --dangerously-skip-permissions"
```

`--dangerously-skip-permissions` bypasses all permission prompts. This is the recommended way to run Claude Code for maximum throughput -- pair it with sandboxing (next section).

## Sandboxing

At Trail of Bits we run Claude Code in bypass-permissions mode (`--dangerously-skip-permissions`). This means you need to understand your sandboxing options -- the agent will execute commands without asking, so the sandbox is what keeps it from doing damage.

### Built-in sandbox (`/sandbox`)

Claude Code has a native sandbox that provides filesystem and network isolation using OS-level primitives (Seatbelt on macOS, bubblewrap on Linux). Enable it by typing `/sandbox` in a session. In auto-allow mode, Bash commands that stay within sandbox boundaries run without permission prompts.

**Default behavior:** The agent can write only to the current working directory and its subdirectories, but it can **read the entire filesystem** (except certain denied directories). Network access is restricted to explicitly allowed domains. This means the sandbox protects your system from modification, but doesn't provide read isolation -- the agent can still read `~/.ssh`, `~/.aws`, etc.

**Hardening reads:** You can restrict read access by adding `Read` deny rules in your [permission settings](https://code.claude.com/docs/en/permissions). For example, denying `Read` on `~/.ssh` prevents the agent from accessing your SSH keys. You can also set `"allowUnsandboxedCommands": false` in sandbox settings to prevent the agent from escaping the sandbox entirely.

See the [official sandboxing docs](https://code.claude.com/docs/en/sandboxing) for the full configuration reference.

### Devcontainer

For full read and write isolation, use a devcontainer. The agent runs in a container with only the project files mounted -- it has no access to your host filesystem, SSH keys, cloud credentials, or anything else outside the container.

- [trailofbits/claude-code-devcontainer](https://github.com/trailofbits/claude-code-devcontainer) -- preconfigured devcontainer with VS Code integration, Claude Code pre-installed, and common development tools

### Remote droplets

For complete isolation from your local machine, run the agent on a disposable cloud instance:

- [trailofbits/dropkit](https://github.com/trailofbits/dropkit) -- CLI tool for managing DigitalOcean droplets with automated setup, SSH config, and Tailscale VPN. Create a droplet, SSH in, run Claude Code, destroy it when done.

## Global CLAUDE.md

The global `CLAUDE.md` file at `~/.claude/CLAUDE.md` sets default instructions for every Claude Code session. It defines code quality limits, tooling preferences, workflow conventions, and skill triggers.

Copy the template into place:

```bash
cp claude-md-template.md ~/.claude/CLAUDE.md
```

Review and customize it for your own preferences. The template is opinionated -- it assumes specific tools (`ruff`, `ty`, `oxlint`, `cargo clippy`, etc.) and enforces hard limits on function length, complexity, and line width.

## Hooks

Hooks are shell commands (or LLM prompts) that fire at specific points in Claude Code's lifecycle. They are the primary mechanism for **policy enforcement** -- shaping what the agent does and doesn't do.

Hooks are not a security boundary. A determined attacker or a sufficiently creative agent can work around them. What hooks *are* good for is **structured prompt injection at opportune times**: intercepting tool calls, injecting context, blocking known-bad patterns, and steering agent behavior toward your preferred workflows. Think of them as guardrails, not walls.

Full reference: [Hooks documentation](https://code.claude.com/docs/en/hooks)

### Hook events

| Event | When it fires | Can block? |
|-------|---------------|------------|
| `PreToolUse` | Before a tool call executes | Yes |
| `PostToolUse` | After a tool call succeeds | No (already ran) |
| `UserPromptSubmit` | When user submits a prompt | Yes |
| `Stop` | When Claude finishes responding | Yes (forces continue) |
| `SessionStart` | When a session begins/resumes | No |
| `SubagentStart`/`Stop` | When a subagent spawns/finishes | Start: no, Stop: yes |
| `TaskCompleted` | When a task is marked complete | Yes |
| `TeammateIdle` | When a teammate is about to idle | Yes |

### Exit codes

| Exit code | Behavior |
|-----------|----------|
| 0 | Action allowed (stdout parsed for JSON control) |
| 1 | Error, non-blocking (stderr shown in verbose mode) |
| 2 | Blocking error (stderr fed back to Claude as error message) |

### Examples

The `settings.json` in this repo includes two `PreToolUse` hooks on the `Bash` tool:

| Hook | What it blocks |
|------|----------------|
| `rm -rf` blocker | Catches `rm -rf` commands, suggests `trash` instead |
| `git push to main` blocker | Catches direct push to main/master, requires feature branches |

Here is a more interesting example. Claude Code has an undocumented `EnterPlanMode` tool that it can invoke at any time, switching itself into a read-only planning mode. This is useful for complex tasks, but it can cause problems in the Agent SDK where tools like `ExitPlanMode` and `AskUserQuestion` may not be available, leaving the agent stuck in a loop. A `PreToolUse` hook solves this:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "EnterPlanMode",
        "hooks": [
          {
            "type": "command",
            "command": "echo 'EnterPlanMode is disabled. Skip planning and implement directly.' && exit 2"
          }
        ]
      }
    ]
  }
}
```

The agent tries to call `EnterPlanMode`, the hook fires, exit code 2 blocks the call, and the stderr message tells Claude to proceed without planning. No code change, no SDK modification -- just a hook that injects the right guidance at the right moment.

### Philosophy

The mental model: hooks are a way to talk to the LLM at decision points it wouldn't otherwise pause at. Every `PreToolUse` hook is a chance to say "stop, think about this" or "don't do that, do this instead." Every `PostToolUse` hook is a chance to say "now that you did that, here's what you should know." Every `Stop` hook is a chance to say "you're not done yet."

This is more powerful than system prompt instructions alone because hooks fire at specific, contextual moments. An instruction in your CLAUDE.md saying "never use `rm -rf`" can be forgotten or overridden by context pressure. A `PreToolUse` hook that blocks `rm -rf` fires every single time, with the error message right at the point of decision.

Use hooks for:
- **Blocking known-bad patterns** (`rm -rf`, push to main, plan mode in constrained environments)
- **Injecting context at decision points** (post-write lint results, pre-tool security warnings)
- **Enforcing workflow conventions** (require tests pass before marking tasks complete)
- **Adapting agent behavior** without modifying the agent itself (Agent SDK, MCP integrations)

## Settings

Copy `settings.json` to `~/.claude/settings.json` (or merge entries into your existing file). The hooks described above are defined in this file.

### Statusline

A two-line status bar showing repo context, git branch, lines changed, model name, cost, session time, context window remaining, and cache hit rate.

Copy the script:

```bash
mkdir -p ~/.claude
cp scripts/statusline.sh ~/.claude/statusline.sh
chmod +x ~/.claude/statusline.sh
```

The `statusLine` entry in `settings.json` points to this script. Requires `jq`.

## Plugins and Skills

Claude Code's capabilities come from plugins, which provide skills (reusable workflows), agents (specialized subagents), and commands (slash commands). Plugins are distributed through marketplaces.

### Trail of Bits marketplaces

Install the three Trail of Bits marketplaces:

```bash
claude plugins install trailofbits@trailofbits
claude plugins install trailofbits-internal@trailofbits-internal
claude plugins install skills-curated@trailofbits-curated
```

| Repository | Description |
|------------|-------------|
| [trailofbits/skills](https://github.com/trailofbits/skills) | Public skills for security auditing, code review, and development workflows |
| [trailofbits/skills-internal](https://github.com/trailofbits/skills-internal) | Internal skills for Trail of Bits engineers (private) |
| [trailofbits/skills-curated](https://github.com/trailofbits/skills-curated) | Curated third-party skills and recommended external marketplaces |

For external marketplaces and additional plugins, see [skills-curated](https://github.com/trailofbits/skills-curated) -- it maintains the canonical list of vetted marketplaces and install scripts.

### Writing custom skills

Skills are the highest-leverage way to encode team knowledge into Claude Code. When you find yourself repeating the same multi-step workflow, extract it into a skill.

A skill is a directory with a `SKILL.md` file:

```
~/.claude/skills/
└── my-skill/
    └── SKILL.md
```

The `SKILL.md` uses YAML frontmatter for metadata and markdown for instructions:

```markdown
---
name: my-skill
description: >-
  What this skill does and when Claude should use it.
  Be specific about triggers -- what the user says or
  what situation should activate this skill.
allowed-tools:
  - Read
  - Write
  - Bash
---

# My Skill

Step-by-step instructions for Claude to follow.
Reference files with `{baseDir}/path` for paths
relative to the skill directory.
```

Tips for effective skills:

- **Be specific about triggers** -- the `description` field tells Claude when to activate the skill. Vague descriptions lead to skills that never fire or fire at the wrong time.
- **Include "when NOT to use" guidance** -- negative examples prevent false activations.
- **Use `allowed-tools` to limit scope** -- a skill that only reads files can't accidentally write to them.
- **Keep reference data in sibling files** -- put templates, examples, or lookup tables next to `SKILL.md` and reference them with `{baseDir}/filename`.
- **Test with `/skill-name`** -- invoke the skill directly to verify it works before relying on auto-activation.

For team-wide skills, publish them to a plugin marketplace.

## MCP Servers

Copy `.mcp.json` to `~/.mcp.json` (or merge into your existing file). This configures Model Context Protocol servers that extend Claude Code's capabilities.

| Server | What it does | Requirements |
|--------|-------------|--------------|
| Context7 | Up-to-date library documentation lookup | None (no API key) |
| Exa | Web and code search (see [Web Browsing](#web-browsing)) | `EXA_API_KEY` environment variable |
| Granola | Meeting notes and transcripts | Granola app with paid plan |

Replace `your-exa-api-key-here` in `.mcp.json` with your actual Exa API key, or remove the `exa` entry if you don't have one.

## Web Browsing

Claude Code has three ways to interact with the web. They serve different purposes and work well together.

### Exa AI (MCP)

Web search that returns clean, LLM-ready content. Configured via `.mcp.json` (see [MCP Servers](#mcp-servers)). Best for finding documentation, researching libraries, reading articles, and answering questions about current events. Requires an API key from [exa.ai](https://exa.ai).

Your CLAUDE.md can instruct Claude to prefer Exa over the built-in `WebSearch` tool for higher-quality results.

### agent-browser

CLI-based browser automation. Install with `npm install -g agent-browser`. Best for form filling, scraping, multi-step web workflows, and tasks that need programmatic control. Supports video recording of sessions and parallel browser instances.

```bash
agent-browser open <url>        # Navigate
agent-browser snapshot -i       # Get element refs (@e1, @e2)
agent-browser click @e1         # Click element
agent-browser fill @e2 "text"   # Fill input
agent-browser screenshot        # Capture screenshot
```

Workflow: open -> snapshot -> interact -> re-snapshot after navigation.

### Claude in Chrome (MCP)

Browser automation via the [Claude in Chrome](https://chromewebstore.google.com/detail/claude-in-chrome/afnknkaociebljpilnhfkoigcfpaihih) extension. Best for visual inspection, screenshot-based analysis, and interacting with pages that need real browser rendering (SPAs, authenticated sessions, complex UIs). Connects as an MCP server -- no CLI needed.

Use agent-browser when you need scriptable, repeatable automation. Use Claude in Chrome when you need to see and reason about what's on the screen.

## Local Models

Use [LM Studio](https://lmstudio.ai) to run local LLMs with Claude Code. Set two environment variables to point Claude Code at the local server:

```bash
ANTHROPIC_BASE_URL=http://localhost:1234 \
ANTHROPIC_API_KEY=lmstudio \
claude
```

Or add a shell function to `~/.zshrc`:

```bash
local-claude() {
  ANTHROPIC_BASE_URL=http://localhost:1234 \
  ANTHROPIC_API_KEY=local \
  CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1 \
  claude "$@"
}
```

Additional environment variables for model overrides:

| Variable | Purpose |
|----------|---------|
| `ANTHROPIC_BASE_URL` | API endpoint (e.g., `http://localhost:1234`) |
| `ANTHROPIC_API_KEY` | API key (any string for local servers) |
| `ANTHROPIC_DEFAULT_SONNET_MODEL` | Default model for most operations |
| `ANTHROPIC_DEFAULT_OPUS_MODEL` | Model for opus-tier tasks |
| `ANTHROPIC_DEFAULT_HAIKU_MODEL` | Model for summarization tasks |
| `CLAUDE_CODE_SUBAGENT_MODEL` | Model for subagent tasks |
| `CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC` | Set to `1` to disable telemetry |

## Example Commands

Custom slash commands are markdown files that define reusable workflows. Below are two examples you can adapt. Save them as `.claude/commands/<name>.md` in your project or `~/.claude/commands/<name>.md` globally.

### Review PR

```markdown
# Review and Fix PR

@description Review an existing PR with parallel agents, fix findings, and push.
@arguments $PR_NUMBER: GitHub PR number to review and fix

Read PR #$PR_NUMBER thoroughly using `gh pr view`. Understand the
full context: description, linked issues, commit history, and the
diff against the base branch. Check out the PR branch locally.

Execute every step below sequentially. Do not stop or ask for
confirmation at any step.

## 1. Review

Use `/compound-engineering:workflows:review` to perform a full
multi-agent code review of PR #$PR_NUMBER. Produce a list of
findings ranked by severity (P1 = blocks merge, P2 = important,
P3 = nice to have, P4 = informational).

## 2. Fix findings

Address all P1-P3 findings. For each finding, either:

- **Fix it** -- apply the change, or
- **Dismiss it** -- explain why it's a false positive or not worth
  the churn (e.g. a stylistic disagreement or an impossible edge
  case). Document the reasoning inline.

P4 findings are informational -- note them but do not fix unless
trivial.

## 3. Verify

Run the project's full quality pipeline:

1. Build (compile/bundle if the project has a build step)
2. Run the full test suite -- iterate on failures until green
3. Run linting, formatting, and type-checking -- fix any issues

Refer to the project's CLAUDE.md or package.json/Makefile/etc.
for the correct commands.

## 4. Commit and push

- Commit the fixes as a separate commit (do not squash into the
  original -- preserve review history)
- Use commit message: `fix: resolve code review findings for
  PR #$PR_NUMBER`
- Push the branch (regular push, not force-push)
- Delete any todo files in `todos/` that were created by the
  review and are now resolved

## 5. Post summary

Add a comment on PR #$PR_NUMBER summarizing what was done:

- Total findings by severity (e.g. "3 P2, 5 P3")
- How many were fixed vs dismissed (with brief reasoning for
  any dismissals)
- Confirmation that the quality pipeline passes
```

### Fix Issue

```markdown
# Fix GitHub Issue

@description End-to-end: plan, implement, test, PR, review, fix findings, and comment on a GitHub issue.
@arguments $ISSUE_NUMBER: GitHub issue number to fix

Read GitHub Issue #$ISSUE_NUMBER thoroughly. Understand the full
context: problem description, acceptance criteria, linked PRs,
and any discussion. Follow linked issues, referenced PRs, and
external documentation to build complete understanding before
planning.

Execute every step below sequentially. Do not stop or ask for
confirmation at any step.

## 1. Plan

Write a detailed implementation plan to `plan-issue-$ISSUE_NUMBER.md`
in the repo root. The plan must:

- Summarize the issue requirements
- List every file to create or modify
- Describe the approach and key design decisions
- Call out risks or open questions
- Reference relevant code paths by file:line

## 2. Implement

Implement the plan across all necessary files. Follow the
project's CLAUDE.md standards. Keep changes minimal and focused
on the issue requirements -- no speculative features.

## 3. Build, test, lint

Run the project's full quality pipeline in this order:

1. Build (compile/bundle if the project has a build step)
2. Run the full test suite -- iterate on failures until green
3. Add new tests for the changed behavior
4. Run linting, formatting, and type-checking -- fix any issues

Refer to the project's CLAUDE.md or package.json/Makefile/etc.
for the correct commands.

## 4. Branch, commit, and push

- Determine the branch prefix from the issue type: `fix/` for
  bugs, `feat/` for features, `refactor/` for refactors, `docs/`
  for documentation. When ambiguous, use `fix/`.
- Create a branch named `{prefix}issue-$ISSUE_NUMBER`
- Delete the plan file (`plan-issue-$ISSUE_NUMBER.md`) -- it was a
  working artifact and should not be committed
- Commit all changes with a conventional commit message referencing
  the issue
- Push the branch

## 5. Create PR

Create a PR with:

- A concise title (under 70 chars)
- A description that maps changes back to the issue requirements
- Link to the issue with "Closes #$ISSUE_NUMBER" (or "Refs" if it
  doesn't fully close it)

## 6. Self-review

Use `/compound-engineering:workflows:review` to perform a full
multi-agent code review of the PR. Produce a list of findings
ranked by severity (P1 = blocks merge, P2 = important, P3 = nice
to have).

## 7. Fix findings

Address all P1-P3 findings. For each finding, either:

- **Fix it** -- apply the change, or
- **Dismiss it** -- explain why it's a false positive or not worth
  the churn (e.g. a stylistic disagreement or an impossible edge
  case). Document the reasoning inline.

After addressing all findings:

1. Re-run the full quality pipeline (build, test, lint)
2. Commit the fixes as a separate commit (do not squash into the
   original -- preserve review history)
3. Push the branch (regular push, not force-push)
4. Delete any todo files in `todos/` that were created by the
   review and are now resolved

## 8. Comment on issue

Post a summary comment on Issue #$ISSUE_NUMBER linking to the PR.
Include:

- What was implemented (1-3 bullet points)
- Key design decisions
- Link to the PR
```

## Continuous Improvement

### Keep history longer

By default Claude Code deletes conversation history after 30 days. Increase this so `/insights` and your own review have more data to work with:

Add to `~/.claude/settings.json`:

```json
{
  "cleanupPeriodDays": 365
}
```

### Run /insights weekly

The `/insights` command analyzes your recent sessions and surfaces patterns -- what's working, what's failing, where you're spending time. Run it once a week to catch blind spots before they become habits.

## Recommended Reading

- [Best practices for Claude Code](https://code.claude.com/docs/en/best-practices) -- Anthropic's official guide to working effectively with Claude Code
- [Here's how I use LLMs to help me write code](https://simonwillison.net/2025/Mar/11/using-llms-for-code/) -- Simon Willison on practical LLM-assisted coding techniques
- [AI-assisted coding for teams that can't get away with vibes](https://blog.nilenso.com/blog/2025/05/29/ai-assisted-coding/) -- Nilenso's playbook for teams integrating AI tools with high standards
- [My AI Skeptic Friends Are All Nuts](https://fly.io/blog/youre-all-nuts/) -- Thomas Ptacek on why dismissing LLMs for coding is a mistake
- [Harness engineering](https://openai.com/index/harness-engineering/) -- OpenAI on building a product with zero manually-written code
