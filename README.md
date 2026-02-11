# claude-code-config

Reference setup for Claude Code at Trail of Bits. Not a plugin -- just documentation and config files you copy into place.

## Contents

**[Getting Started](#getting-started)**
- [Read These First](#read-these-first)
- [Prerequisites](#prerequisites)
- [Shell Setup](#shell-setup)
- [Settings](#settings)
- [Global CLAUDE.md](#global-claudemd)
- [Continuous Improvement](#continuous-improvement)

**[Configuration](#configuration)**
- [Sandboxing](#sandboxing)
- [Hooks](#hooks)
- [Plugins and Skills](#plugins-and-skills)
- [MCP Servers](#mcp-servers)
- [Fast Mode](#fast-mode)

**[Usage](#usage)**
- [Web Browsing](#web-browsing)
- [Local Models](#local-models)
- [Example Commands](#example-commands)

## Getting Started

### Read These First

Before configuring anything, read these to understand the context for why this setup works the way it does:

- [Best practices for Claude Code](https://code.claude.com/docs/en/best-practices) -- Anthropic's official guide to working effectively with Claude Code
- [Here's how I use LLMs to help me write code](https://simonwillison.net/2025/Mar/11/using-llms-for-code/) -- Simon Willison on practical LLM-assisted coding techniques
- [AI-assisted coding for teams that can't get away with vibes](https://blog.nilenso.com/blog/2025/05/29/ai-assisted-coding/) -- Nilenso's playbook for teams integrating AI tools with high standards
- [My AI Skeptic Friends Are All Nuts](https://fly.io/blog/youre-all-nuts/) -- Thomas Ptacek on why dismissing LLMs for coding is a mistake
- [Harness engineering](https://openai.com/index/harness-engineering/) -- OpenAI on building a product with zero manually-written code

### Prerequisites

#### Terminal: Ghostty

Use [Ghostty](https://ghostty.org). It's the best terminal for Claude Code because it uses native Metal GPU rendering, so it handles the high-volume text output from long AI sessions without lag or memory bloat (~500MB vs ~8GB for two VS Code terminal sessions). Shift+Enter and key bindings work out of the box with no `/terminal-setup` needed, built-in split panes (Cmd+D / Cmd+Shift+D) let you run Claude Code alongside a dev server without tmux, and it never crashes during extended autonomous runs.

```bash
brew install --cask ghostty
```

macOS only. On Linux, see the [Ghostty install docs](https://ghostty.org/docs/install/binary#linux-(official)). No Windows support yet -- use WezTerm there.

#### Tools

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

LM Studio (for [local models](#local-models)):

```bash
curl -fsSL https://lmstudio.ai/install.sh | bash
```

This installs `lms` (the CLI) and `llmster` (the headless daemon). Or install the [LM Studio desktop app](https://lmstudio.ai/download) if you prefer a GUI.

### Shell Setup

Add to `~/.zshrc`:

```bash
alias claude-yolo="claude --dangerously-skip-permissions"
```

`--dangerously-skip-permissions` bypasses all permission prompts. This is the recommended way to run Claude Code for maximum throughput -- pair it with sandboxing (below).

### Settings

Copy `settings.json` to `~/.claude/settings.json` (or merge entries into your existing file). The template includes:

- **`permissions`** -- deny rules that block reading credentials/secrets and editing shell config (see [Sandboxing](#sandboxing))
- **`cleanupPeriodDays: 365`** -- keeps conversation history for a year instead of the default 30 days, so `/insights` has more data
- **`hooks`** -- two `PreToolUse` hooks on Bash that block `rm -rf` and direct push to main (see [Hooks](#hooks))
- **`statusLine`** -- points to the statusline script (see below)

#### Statusline

A two-line status bar at the bottom of the terminal:

```
 claude-code-config │ main │ +42 -17
 Claude Opus 4.6 │ $0.83 │ 12m 34s │ 72% ↻89%
```

Line 1 shows the repo name, git branch, and lines changed. Line 2 shows the model, session cost, elapsed time, context window remaining (color-coded: green >50%, yellow >20%, red below), and prompt cache hit rate.

Copy the script:

```bash
mkdir -p ~/.claude
cp scripts/statusline.sh ~/.claude/statusline.sh
chmod +x ~/.claude/statusline.sh
```

The `statusLine` entry in `settings.json` points to this script. Requires `jq`.

### Global CLAUDE.md

The global `CLAUDE.md` file at `~/.claude/CLAUDE.md` sets default instructions for every Claude Code session. It defines code quality limits, tooling preferences, workflow conventions, and skill triggers.

Copy the template into place:

```bash
cp claude-md-template.md ~/.claude/CLAUDE.md
```

Review and customize it for your own preferences. The template is opinionated -- it assumes specific tools (`ruff`, `ty`, `oxlint`, `cargo clippy`, etc.) and enforces hard limits on function length, complexity, and line width. For background on how CLAUDE.md files work (hierarchy, auto memory, modular rules, imports), see [Manage Claude's memory](https://code.claude.com/docs/en/memory).

### Continuous Improvement

Most people's use of Claude Code plateaus early. You find a workflow that works, repeat it, and never discover what you're leaving on the table. The fix is a deliberate feedback loop: review what happened, adjust your setup, and let the next week benefit from what you learned.

#### Keep history longer

By default Claude Code deletes conversation history after 30 days. Increase this so `/insights` and your own review have more data to work with:

Add to `~/.claude/settings.json`:

```json
{
  "cleanupPeriodDays": 365
}
```

#### Run /insights weekly

`/insights` analyzes your recent sessions and surfaces patterns -- what's working, what's failing, where you're spending time. Run it once a week. When it tells you something useful, act on it: add a rule to your CLAUDE.md, write a hook to block a mistake you keep making, extract a repeated workflow into a skill. Each adjustment compounds. After a few weeks your setup is meaningfully different from the defaults, tuned to how you actually work.

## Configuration

### Sandboxing

At Trail of Bits we run Claude Code in bypass-permissions mode (`--dangerously-skip-permissions`). This means you need to understand your sandboxing options -- the agent will execute commands without asking, so the sandbox is what keeps it from doing damage.

#### Built-in sandbox (`/sandbox`)

Claude Code has a native sandbox that provides filesystem and network isolation using OS-level primitives (Seatbelt on macOS, bubblewrap on Linux). Enable it by typing `/sandbox` in a session. In auto-allow mode, Bash commands that stay within sandbox boundaries run without permission prompts.

**Default behavior:** The agent can write only to the current working directory and its subdirectories, but it can **read the entire filesystem** (except certain denied directories). Network access is restricted to explicitly allowed domains. This means the sandbox protects your system from modification, but doesn't provide read isolation -- the agent can still read `~/.ssh`, `~/.aws`, etc.

**Hardening reads:** The `settings.json` template in this repo includes `Read` and `Edit` deny rules that block access to credentials and secrets:

- **SSH/GPG keys** -- `~/.ssh/**`, `~/.gnupg/**`
- **Cloud credentials** -- `~/.aws/**`, `~/.azure/**`, `~/.kube/**`, `~/.docker/config.json`
- **Package registry tokens** -- `~/.npmrc`, `~/.npm/**`, `~/.pypirc`, `~/.gem/credentials`
- **Git credentials** -- `~/.git-credentials`, `~/.config/gh/**`
- **Shell config** -- `~/.bashrc`, `~/.zshrc` (edit denied, prevents backdoor planting)
- **macOS keychain** -- `~/Library/Keychains/**`
- **Crypto wallets** -- metamask, electrum, exodus, phantom, solflare app data

**How these rules interact with the sandbox:** Permission deny rules and the sandbox are two layers enforcing the same rules. Without `/sandbox`, a `Read(~/.ssh/**)` deny rule only blocks Claude's built-in Read tool -- a Bash command like `cat ~/.ssh/id_rsa` can still reach the file. With `/sandbox` enabled, the sandbox takes the same `Read` and `Edit` deny rules and enforces them at the OS level (Seatbelt/bubblewrap), so Bash commands are also blocked. Use both: deny rules as the baseline, `/sandbox` for OS-level enforcement that survives prompt injection.

For the design rationale behind sandboxing, see Anthropic's [engineering blog post](https://www.anthropic.com/engineering/claude-code-sandboxing). For the full configuration reference, see the [sandboxing docs](https://code.claude.com/docs/en/sandboxing).

#### Devcontainer

For full read and write isolation, use a devcontainer. The agent runs in a container with only the project files mounted -- it has no access to your host filesystem, SSH keys, cloud credentials, or anything else outside the container.

- [trailofbits/claude-code-devcontainer](https://github.com/trailofbits/claude-code-devcontainer) -- preconfigured devcontainer with VS Code integration, Claude Code pre-installed, and common development tools

#### Remote droplets

For complete isolation from your local machine, run the agent on a disposable cloud instance:

- [trailofbits/dropkit](https://github.com/trailofbits/dropkit) -- CLI tool for managing DigitalOcean droplets with automated setup, SSH config, and Tailscale VPN. Create a droplet, SSH in, run Claude Code, destroy it when done.

### Hooks

Hooks are shell commands (or LLM prompts) that fire at specific points in Claude Code's lifecycle. They are a way to talk to the LLM at decision points it wouldn't otherwise pause at. Every `PreToolUse` hook is a chance to say "stop, think about this" or "don't do that, do this instead." Every `PostToolUse` hook is a chance to say "now that you did that, here's what you should know." Every `Stop` hook is a chance to say "you're not done yet."

This is more powerful than system prompt instructions alone because hooks fire at specific, contextual moments. An instruction in your CLAUDE.md saying "never use `rm -rf`" can be forgotten or overridden by context pressure. A `PreToolUse` hook that blocks `rm -rf` fires every single time, with the error message right at the point of decision.

Hooks are not a security boundary -- a prompt injection can work around them. They are **structured prompt injection at opportune times**: intercepting tool calls, injecting context, blocking known-bad patterns, and steering agent behavior. Guardrails, not walls.

Use hooks for:
- **Blocking known-bad patterns** (`rm -rf`, push to main, plan mode in constrained environments)
- **Injecting context at decision points** (post-write lint results, pre-tool security warnings)
- **Enforcing workflow conventions** (require tests pass before marking tasks complete)
- **Adapting agent behavior** without modifying the agent itself (Agent SDK, MCP integrations)

Guide and examples: [Automate workflows with hooks](https://code.claude.com/docs/en/hooks-guide)

#### Hook events

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

#### Exit codes

| Exit code | Behavior |
|-----------|----------|
| 0 | Action allowed (stdout parsed for JSON control) |
| 1 | Error, non-blocking (stderr shown in verbose mode) |
| 2 | Blocking error (stderr fed back to Claude as error message) |

#### Examples

**Blocking patterns** (`PreToolUse`, in `settings.json`): The two hooks in this repo's `settings.json` block `rm -rf` (suggests `trash` instead) and direct push to main/master (requires feature branches). Both read the Bash command from stdin via `jq`, match with regex, and exit 2 with an error message that tells Claude what to do instead.

**Audit logging** (`PostToolUse`): A hook that logs every write operation to a JSONL changelog. This example tracks GAM (Google Apps Manager) commands -- it classifies each command as read or write using verb pattern lists, skips reads, and logs mutations with timestamp, action, command, and exit status. After a successful write, it prints a banner reminding the operator a mutation occurred. Adapt the verb patterns for any CLI tool where you want an audit trail.

```bash
#!/bin/bash
set -euo pipefail
# PostToolUse hook — logs GAM write operations to JSONL
INPUT=$(cat)
COMMAND=$(echo "${INPUT}" | jq -r '.tool_input.command // empty')

[[ -z "${COMMAND}" ]] && exit 0
[[ "${COMMAND}" != *'gam7/gam '* ]] && exit 0

# Verb lists verified against GamCommands.txt v7.33.00
READ_PATTERN='(print|show|info|get|list|report|check|version|help)'
WRITE_PATTERN='(create|add|update|delete|remove|suspend|unsuspend|wipe|sync|move|transfer|trash|purge|enable|disable|deprovision)'

GAM_ARGS="${COMMAND#*gam7/gam }"
FIRST_WORD="${GAM_ARGS%% *}"

# Skip read operations
echo "${FIRST_WORD}" | grep -qiE "^${READ_PATTERN}$" && exit 0

# Match write verb
ACTION=$(echo "${GAM_ARGS}" | grep -oiE "(^|[[:space:]])${WRITE_PATTERN}([[:space:]]|$)" \
  | head -1 | tr -d ' ' || true)
[[ -z "${ACTION}" ]] && exit 0

# Log the mutation
EXIT_CODE=$(echo "${INPUT}" | jq -r '.tool_result.exit_code // 0')
[[ "${EXIT_CODE}" == "0" ]] && STATUS="success" || STATUS="failed"
LOG_FILE="${CLAUDE_PROJECT_DIR}/google/.changelog-raw.jsonl"
mkdir -p "$(dirname "${LOG_FILE}")"

jq -nc \
  --arg ts "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg action "${ACTION}" \
  --arg command "${COMMAND}" \
  --arg status "${STATUS}" \
  '{timestamp: $ts, action: $action, command: $command, status: $status}' \
  >> "${LOG_FILE}"

# Remind the operator
if [[ "${STATUS}" == "success" ]]; then
  echo "GAM MUTATION: ${ACTION} — logged to ${LOG_FILE}"
fi
exit 0
```

Wire it up in `settings.json` as a `PostToolUse` hook on `Bash`, pointing the command at the script.

**Bash command log** (`PostToolUse`): Appends every Bash command the agent runs to a log file with a timestamp. Useful for post-session review of what the agent actually did.

```json
{
  "PostToolUse": [
    {
      "matcher": "Bash",
      "hooks": [
        {
          "type": "command",
          "command": "jq -r '\"[\" + (now | todate) + \"] \" + .tool_input.command' >> ~/.claude/bash-commands.log"
        }
      ]
    }
  ]
}
```

**Desktop notifications** (`Notification`): Fires a native OS notification when Claude needs your attention, so you can switch to other work during long autonomous runs instead of watching the terminal.

```json
{
  "Notification": [
    {
      "matcher": "",
      "hooks": [
        {
          "type": "command",
          "command": "osascript -e 'display notification \"Claude needs your attention\" with title \"Claude Code\"'"
        }
      ]
    }
  ]
}
```

On Linux, replace the command with `notify-send 'Claude Code' 'Claude needs your attention'`.

**Enforce package manager** (`PreToolUse`): If a project uses `pnpm`, block `npm` commands and tell Claude to use the right tool. Generalizes to any "use X not Y" convention.

```bash
#!/bin/bash
set -euo pipefail
# PreToolUse hook — enforce pnpm in projects that use it
CMD=$(jq -r '.tool_input.command // empty')
[[ -z "$CMD" ]] && exit 0

# Only enforce if this project uses pnpm
[[ ! -f "${CLAUDE_PROJECT_DIR}/pnpm-lock.yaml" ]] && exit 0

if echo "$CMD" | grep -qE '^npm\s'; then
  echo "BLOCKED: This project uses pnpm, not npm. Use pnpm instead." >&2
  exit 2
fi
exit 0
```

**Anti-rationalization gate** (`Stop`, prompt hook): Claude has a tendency to declare victory while leaving work undone. It rationalizes skipping things: "these issues were pre-existing," "fixing this is out of scope," "I'll leave these for a follow-up." A prompt-based `Stop` hook catches this by asking a fast model to review Claude's final response for cop-outs before allowing it to stop.

```json
{
  "Stop": [
    {
      "hooks": [
        {
          "type": "prompt",
          "prompt": "Review the assistant's final response. Reject it if the assistant is rationalizing incomplete work. Common patterns: claiming issues are 'pre-existing' or 'out of scope' to avoid fixing them, saying there are 'too many issues' to address all of them, deferring work to a 'follow-up' that was not requested, listing problems without fixing them and calling that done, or skipping test/lint failures with excuses. If the response shows any of these patterns, respond {\"ok\": false, \"reason\": \"You are rationalizing incomplete work. [specific issue]. Go back and finish.\"}. If the work is genuinely complete, respond {\"ok\": true}."
        }
      ]
    }
  ]
}
```

This uses `type: "prompt"` instead of `type: "command"` -- Claude Code sends the hook's prompt plus the assistant's response to a fast model (Haiku), which returns a yes/no judgment. If rejected, the `reason` is fed back to Claude as its next instruction, forcing it to continue.

### Plugins and Skills

Claude Code's capabilities come from plugins, which provide skills (reusable workflows), agents (specialized subagents), and commands (slash commands). Plugins are distributed through marketplaces.

#### Trail of Bits marketplaces

Install the three Trail of Bits marketplaces:

```bash
claude plugins install trailofbits@trailofbits
claude plugins install trailofbits-internal@trailofbits-internal
claude plugins install skills-curated@trailofbits-curated
```

| Repository | Description |
|------------|-------------|
| [trailofbits/skills](https://github.com/trailofbits/skills) | Security auditing, code review, smart contract analysis, reverse engineering, and development workflows. Open source -- contributions welcome. |
| [trailofbits/skills-internal](https://github.com/trailofbits/skills-internal) | Internal skills: report writing, scoping, recruiting, brand tools, and client-specific workflows. Private to Trail of Bits. |
| [trailofbits/skills-curated](https://github.com/trailofbits/skills-curated) | Vetted third-party skills and the canonical list of approved external marketplaces. |

For external marketplaces (Anthropic official, superpowers, compound-engineering, etc.), see [skills-curated](https://github.com/trailofbits/skills-curated) -- it maintains the approved list and install scripts.

#### Publishing skills

Where to publish depends on the audience:

- **Public and open source** -- submit a PR to [trailofbits/skills](https://github.com/trailofbits/skills). See its [CLAUDE.md](https://github.com/trailofbits/skills/blob/main/CLAUDE.md) for authoring guidelines.
- **Internal to Trail of Bits** -- submit a PR to [trailofbits/skills-internal](https://github.com/trailofbits/skills-internal).
- **Third-party skill you want approved** -- submit a PR to [trailofbits/skills-curated](https://github.com/trailofbits/skills-curated) with attribution to the original source. Every PR gets code review.

#### Writing custom skills

When you find yourself repeating the same multi-step workflow, extract it into a skill. Read Anthropic's [skill authoring best practices](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices) for guidance on structure, descriptions, and testing.

The short version: create `~/.claude/skills/my-skill/SKILL.md` with YAML frontmatter (`name`, `description`, `allowed-tools`) and markdown instructions. Test with `/my-skill`. Be specific in the `description` so Claude knows when to activate it.

### MCP Servers

Everyone at Trail of Bits should set up at least **Context7** and **Exa** as global MCP servers. Granola is a useful third if you use it for meeting notes.

| Server | What it does | Requirements |
|--------|-------------|--------------|
| Context7 | Up-to-date library documentation lookup | None (no API key) |
| Exa | Web and code search (see [Web Browsing](#web-browsing)) | `EXA_API_KEY` env var ([get one here](https://exa.ai)) |
| Granola | Meeting notes and transcripts | Granola app with paid plan |

#### Setup

MCP servers are configured in `.mcp.json` files. Claude Code merges configs from two locations:

- **`~/.mcp.json`** -- global servers available in every session
- **`.mcp.json` in the project root** -- project-specific servers

Copy `mcp-template.json` from this repo to `~/.mcp.json` for global availability. Replace `your-exa-api-key-here` with your actual key, or remove the `exa` entry if you don't have one. Add project-specific MCP servers (e.g., a local database tool) to the project's `.mcp.json`.

### Fast Mode

`/fast` toggles fast mode. Same Opus 4.6 model, ~2.5x faster output, 6x the cost per token. Leave it off by default.

The only time fast mode is worth it is **tight interactive loops** -- you're debugging live, iterating on output, and every second of latency costs you focus. If you're about to kick off an autonomous run (`/fix-issue`, a swarm, anything you walk away from), turn it off first. The agent doesn't benefit from lower latency; you're just burning money.

If you do use it, enable it at session start. Toggling it on mid-conversation reprices your entire context at fast-mode rates and invalidates prompt cache. See the [fast mode docs](https://code.claude.com/docs/en/fast-mode) for details.

## Usage

### Web Browsing

Claude Code has three ways to interact with the web.

#### Exa AI (MCP)

Semantic web search that returns clean, LLM-optimized text. Unlike the built-in `WebSearch` tool (which returns search result links that Claude then has to fetch and parse), Exa returns the actual content pre-extracted and formatted for LLM consumption. This saves context window and produces more relevant results. Your CLAUDE.md can instruct Claude to prefer Exa over `WebSearch`.

#### agent-browser

Headless browser automation via CLI. Runs its own Chromium instance -- it does **not** share your Chrome profile, cookies, or login sessions. This means it can't access authenticated pages (Google Docs, internal dashboards, etc.) without logging in from scratch. What it excels at is context efficiency: the snapshot/ref system (`@e1`, `@e2`) uses ~93% less context than sending full accessibility trees, so the agent can navigate complex multi-page workflows without exhausting its context window. Also supports video recording and parallel sessions.

```bash
agent-browser open <url>        # Navigate
agent-browser snapshot -i       # Get element refs (@e1, @e2)
agent-browser click @e1         # Click element
agent-browser fill @e2 "text"   # Fill input
agent-browser screenshot        # Capture screenshot
```

#### Claude in Chrome (MCP)

Browser automation via the [Claude in Chrome](https://chromewebstore.google.com/detail/claude-in-chrome/afnknkaociebljpilnhfkoigcfpaihih) extension. Operates inside your actual Chrome browser, so it has access to your existing login sessions, cookies, and extensions. This is the only option that can interact with authenticated pages (Gmail, Google Docs, Jira, internal tools) without re-authenticating. The tradeoff is that it uses screenshots and accessibility trees for page understanding, which consumes more context than agent-browser's ref system.

#### When to use which

| Need | Use |
|------|-----|
| Search the web for information | Exa |
| Automate multi-step workflows on public pages | agent-browser |
| Interact with authenticated/internal pages | Claude in Chrome |
| Record a video of browser actions | agent-browser |
| Inspect visual layout or take screenshots for analysis | Claude in Chrome |

### Local Models

Use [LM Studio](https://lmstudio.ai) to run local LLMs with Claude Code. LM Studio provides an Anthropic-compatible `/v1/messages` endpoint, so Claude Code connects with just a base URL change. On macOS it uses MLX for Apple Silicon-native inference, which is significantly faster than GGUF.

#### Recommended model: Qwen3-Coder-Next (as of February 2026)

[Qwen3-Coder-Next](https://lmstudio.ai/models/qwen3-coder-next) is an 80B mixture-of-experts model with only 3B active parameters, designed specifically for agentic coding. It handles tool use, long-horizon reasoning, and recovery from execution failures. The MLX 4-bit quantization is ~45GB and needs at least 64GB unified memory to load with a usable context window. 96GB or more is comfortable.

Local models move fast. When this recommendation is stale, check the [LM Studio featured models page](https://lmstudio.ai/models) and pick the top coding model that fits in your memory as an MLX 4-bit quantization.

#### Setup

Download, load, and serve -- all from the CLI:

```bash
lms get lmstudio-community/Qwen3-Coder-Next-MLX-4bit -y
lms load lmstudio-community/Qwen3-Coder-Next-MLX-4bit --context-length 32768 --gpu max -y
lms server start
```

`--context-length 32768` allocates a 32K context window at load time. Claude Code is context-heavy, so don't go below 25K. Sampling parameters (temperature, top-p, etc.) don't need to be configured on the server -- Claude Code sends its own in each API request.

#### Running Claude Code locally

Point Claude Code at LM Studio by setting the base URL and an auth token (any string works for local servers):

```bash
ANTHROPIC_BASE_URL=http://localhost:1234 \
ANTHROPIC_AUTH_TOKEN=lmstudio \
claude
```

To avoid typing that every time, add to `~/.zshrc`:

```bash
claude-local() {
  ANTHROPIC_BASE_URL=http://localhost:1234 \
  ANTHROPIC_AUTH_TOKEN=lmstudio \
  CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1 \
  claude "$@"
}
```

`claude-local` wraps `claude` with the local server env vars and disables telemetry pings that won't reach Anthropic anyway. Use it anywhere you'd normally run `claude`.

#### Environment variables

| Variable | Purpose |
|----------|---------|
| `ANTHROPIC_BASE_URL` | API endpoint (e.g., `http://localhost:1234`) |
| `ANTHROPIC_AUTH_TOKEN` | API key (any string for local servers) |
| `ANTHROPIC_DEFAULT_SONNET_MODEL` | Default model for most operations |
| `ANTHROPIC_DEFAULT_OPUS_MODEL` | Model for opus-tier tasks |
| `ANTHROPIC_DEFAULT_HAIKU_MODEL` | Model for summarization tasks |
| `CLAUDE_CODE_SUBAGENT_MODEL` | Model for subagent tasks |
| `CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC` | Set to `1` to disable telemetry |

### Example Commands

Custom slash commands are markdown files that define reusable workflows. Below are two examples you can adapt. Save them as `.claude/commands/<name>.md` in your project or `~/.claude/commands/<name>.md` globally.

#### Review PR

Reviews a GitHub PR with parallel agents, fixes findings, and pushes. Invoke with `/review-pr 456` where `456` is the PR number.

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

#### Fix Issue

Takes a GitHub issue and fully autonomously completes it -- plans, implements, tests, creates a PR, self-reviews with parallel agents, fixes its own findings, and comments on the issue when done. Invoke with `/fix-issue 123` where `123` is the issue number.

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
