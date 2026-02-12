# Trail of Bits Claude Code Config

Reference setup for Claude Code at Trail of Bits. Not a plugin -- just documentation and config files you copy into place.

From any Claude Code session:

```
/trailofbits:config
```

This fetches the latest config from GitHub, detects what you already have, and walks you through installing each component. Run it again after updates. To bootstrap it the first time, clone the repo and run `claude`, then `/trailofbits:config` -- it self-installs so future runs work from anywhere.

## Contents

**[Getting Started](#getting-started)**
- [Read These First](#read-these-first)
- [Prerequisites](#prerequisites)
- [Shell Setup](#shell-setup)
- [Settings](#settings)
- [Global CLAUDE.md](#global-claudemd)

**[Configuration](#configuration)**
- [Sandboxing](#sandboxing)
- [Hooks](#hooks)
- [Plugins and Skills](#plugins-and-skills)
- [MCP Servers](#mcp-servers)
- [Fast Mode](#fast-mode)
- [Local Models](#local-models)

**[Usage](#usage)**
- [Continuous Improvement](#continuous-improvement)
- [Context Management](#context-management)
- [Web Browsing](#web-browsing)
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

If you're using [local models](#local-models), also add:

```bash
claude-local() {
  ANTHROPIC_BASE_URL=http://localhost:1234 \
  ANTHROPIC_AUTH_TOKEN=lmstudio \
  CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1 \
  claude "$@"
}
```

`claude-local` wraps `claude` with the local server env vars and disables telemetry pings that won't reach Anthropic anyway. Use it anywhere you'd normally run `claude`.

### Settings

Copy `settings.json` to `~/.claude/settings.json` (or merge entries into your existing file). The `$schema` key enables autocomplete and validation in editors that support JSON Schema. The template includes:

- **`env`** -- `CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC` disables all non-essential traffic to Anthropic: Statsig telemetry, Sentry error reporting, feedback surveys, and the `/bug` command. No functional impact. The [admin analytics dashboard](https://code.claude.com/docs/en/analytics) is unaffected -- it's fed by API-level data, not these client-side streams.
- **`env` (agent teams)** -- `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` enables [multi-agent teams](https://code.claude.com/docs/en/agent-teams) where one session coordinates multiple teammates with independent context windows. Experimental -- known limitations around session resumption and task coordination.
- **`enableAllProjectMcpServers: false`** -- this is the default, set explicitly so it doesn't get flipped by accident. Project `.mcp.json` files live in git, so a compromised repo could ship malicious MCP servers.
- **`alwaysThinkingEnabled: true`** -- persists [extended thinking](https://code.claude.com/docs/en/common-workflows#use-extended-thinking-thinking-mode) across sessions. Toggle per-session with `Option+T`. Adds latency and cost on simple tasks; worth it for complex reasoning.
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

#### Project-level CLAUDE.md

The global file sets defaults; project-level `CLAUDE.md` files at the repo root add project-specific context. A good project CLAUDE.md includes architecture (directory tree, key abstractions), project-specific commands (`make dev`, `make test`), codebase navigation patterns (ast-grep examples for your codebase), domain-specific APIs and gotchas, and testing conventions unique to the project.

For an example of a well-structured project CLAUDE.md, see [crytic/slither's CLAUDE.md](https://github.com/crytic/slither/blob/master/CLAUDE.md). It layers slither-specific context -- SlithIR internals, detector traversal patterns, type handling pitfalls -- on top of the same global standards from this repo.

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

**Audit logging** (`PostToolUse`): [`hooks/log-gam.sh`](hooks/log-gam.sh) logs every write operation to a JSONL changelog. This example tracks GAM (Google Apps Manager) commands -- it classifies each command as read or write using verb pattern lists, skips reads, and logs mutations with timestamp, action, command, and exit status. After a successful write, it prints a banner reminding the operator a mutation occurred. Adapt the verb patterns for any CLI tool where you want an audit trail. Wire it up in `settings.json` as a `PostToolUse` hook on `Bash`, pointing the command at the script.

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

**Enforce package manager** (`PreToolUse`): [`hooks/enforce-package-manager.sh`](hooks/enforce-package-manager.sh) blocks `npm` commands in projects that use `pnpm` and tells Claude to use the right tool. Generalizes to any "use X not Y" convention.

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

The short version: don't write skills by hand. Ask Claude to create one for you — Anthropic ships a [skill creator](https://github.com/anthropics/skills/blob/main/skills/skill-creator/SKILL.md) skill for this. When you notice yourself repeating the same workflow, ask Claude to extract it into a skill. Be specific in the description so Claude knows when to activate it.

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

#### Connecting

Point Claude Code at LM Studio by setting the base URL and an auth token (any string works for local servers):

```bash
ANTHROPIC_BASE_URL=http://localhost:1234 \
ANTHROPIC_AUTH_TOKEN=lmstudio \
claude
```

Or use the `claude-local` shell function from [Shell Setup](#shell-setup) to avoid typing the env vars every time.

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

## Usage

Read Anthropic's [Best practices for Claude Code](https://code.claude.com/docs/en/best-practices) before anything in this section. It's the single most important resource for getting good results. Everything below builds on it.

### Continuous Improvement

Most people's use of Claude Code plateaus early. You find a workflow that works, repeat it, and never discover what you're leaving on the table. The fix is a deliberate feedback loop: review what happened, adjust your setup, and let the next week benefit from what you learned.

Run `/insights` once a week. It analyzes your recent sessions and surfaces patterns -- what's working, what's failing, where you're spending time. When it tells you something useful, act on it: add a rule to your CLAUDE.md, write a hook to block a mistake you keep making, extract a repeated workflow into a skill. Each adjustment compounds. After a few weeks your setup is meaningfully different from the defaults, tuned to how you actually work.

### Context Management

The context window is finite and irreplaceable mid-session. Every file read, tool call, and conversation turn consumes it. When it fills up, Claude auto-compacts -- summarizing the conversation to free space. Auto-compaction works, but it's lossy: subtle decisions, error details, and the thread of reasoning degrade each time. The best strategy is to avoid needing it.

#### Keeping sessions clean

**Scope work to one session.** Each feature, bug fix, or investigation should fit within a single context window. If a task is too large, break it into pieces and run each in a fresh session. This is the single most effective thing you can do for quality.

A session that stays within its context budget produces better code than one that compacts three times to limp across the finish line. When you notice context running low (check the statusline -- green >50%, yellow >20%, red below), it's time to wrap up and start a new session, not push through.

**Prefer `/clear` over `/compact`.** `/clear` wipes the conversation and starts fresh. `/compact` summarizes and continues. Default to `/clear` between tasks.

`/compact` is useful when you're mid-task and need to reclaim space without losing your place, but each compaction is a lossy compression -- details get dropped, and the model's understanding of your intent degrades slightly. Two compactions in a session is a sign the task was too large. `/clear` has no information loss because there's nothing to lose -- your CLAUDE.md reloads, git state is fresh, and the agent re-reads whatever files it needs. When you do use `/compact`, pass focus instructions to steer the summary: `/compact Focus on the auth refactor` preserves what matters and sheds the rest.

**Cut your losses after two corrections.** If you've corrected Claude twice on the same issue and it's still wrong, don't keep pushing -- the context is polluted with failed approaches. Use checkpoints (`Esc Esc` or `/rewind`) to roll back to before the first wrong attempt and try again with a better prompt. If the session is too far gone even for that, `/clear` and start fresh. A clean prompt that incorporates what you learned almost always outperforms a long session with accumulated corrections.

#### Tools for managing context

**Checkpoints** (`Esc Esc` or `/rewind`) restore code and conversation to any previous prompt in the session. They're your undo system -- use them aggressively. Try risky approaches knowing you can rewind if they don't work out.

The "Summarize from here" option in the rewind menu is a more surgical alternative to `/compact`: instead of compressing everything, you keep early context intact and only summarize the part that's eating space (like a verbose debugging tangent). This preserves your initial instructions at full fidelity.

**Offload research to subagents.** Subagents (Task tool, custom agents) each get their own context window. The main session only sees the subagent's summary, not its full working context.

Use this deliberately: when a task requires reading a lot of documentation, exploring unfamiliar code, or doing research that would bloat your main session, delegate it to a subagent. The main session stays lean and focused on implementation while subagents handle the context-heavy exploration.

**For complex features, interview first, implement second.** Have Claude interview you about the feature (requirements, edge cases, tradeoffs), then write a spec to a file. Start a fresh session to implement the spec. The implementation session has clean context focused entirely on building, and you have a written spec as the source of truth.

**Put stable context in CLAUDE.md, not the conversation.** Project architecture, coding standards, tool preferences, workflow conventions -- anything reusable goes in CLAUDE.md. It loads automatically every session and survives `/clear`.

If you need to pass context between sessions, commit your work, write a brief plan to a file, `/clear`, and start the next session by pointing Claude at that file. You can also resume previous sessions with `claude --continue` (picks up the last session) or `claude --resume` (lets you choose from recent sessions). But a fresh session with a written handoff is usually better than resuming a stale one -- the context is cleaner and the prompt cache is warm.

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

### Example Commands

Custom slash commands are markdown files that define reusable workflows. The `commands/` directory contains two examples you can copy into place:

```bash
mkdir -p ~/.claude/commands
cp commands/review-pr.md ~/.claude/commands/
cp commands/fix-issue.md ~/.claude/commands/
```

#### Review PR

[`commands/review-pr.md`](commands/review-pr.md) -- Reviews a GitHub PR with parallel agents, fixes findings, and pushes. Invoke with `/review-pr 456` where `456` is the PR number.

#### Fix Issue

[`commands/fix-issue.md`](commands/fix-issue.md) -- Takes a GitHub issue and fully autonomously completes it -- plans, implements, tests, creates a PR, self-reviews with parallel agents, fixes its own findings, and comments on the issue when done. Invoke with `/fix-issue 123` where `123` is the issue number.
