# Trail of Bits Claude Code Config

Opinionated defaults, documentation, and workflows for Claude Code at Trail of Bits. Covers sandboxing, permissions, hooks, skills, MCP servers, and usage patterns we've found effective across security audits, development, and research.

**First-time setup:**

```bash
git clone https://github.com/trailofbits/claude-code-config.git
cd claude-code-config
claude
```

Then inside the session, run `/trailofbits:config`. It walks you through installing each component, detects what you already have, and self-installs the command so future runs work from any directory. Run `/trailofbits:config` again after updates.

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
- [Local Models](#local-models)
- [Personalization](#personalization)

**[Usage](#usage)**
- [Continuous Improvement](#continuous-improvement)
- [Project-level CLAUDE.md](#project-level-claudemd)
- [Context Management](#context-management)
- [Web Browsing](#web-browsing)
- [Fast Mode](#fast-mode)
- [Commands](#commands)
- [Recommended Skills](#recommended-skills)
- [Recommended MCP Servers](#recommended-mcp-servers)

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

- **`env` (privacy)** -- disables three non-essential outbound streams: Statsig telemetry (`DISABLE_TELEMETRY`), Sentry error reporting (`DISABLE_ERROR_REPORTING`), and feedback surveys (`CLAUDE_CODE_DISABLE_FEEDBACK_SURVEY`). Avoid the umbrella `CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC` -- it also disables auto-updates.
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
 [Opus 4.6] 📁 claude-code-config │ 🌿 main
 ████⣿⣿⣿⣿⣿⣿⣿⣿ 28% │ $0.83 │ ⏱ 12m 34s ↻89%
```

Line 1 shows the model, current folder, and git branch. Line 2 shows a visual context usage bar (color-coded: green <50%, yellow 50-79%, red 80%+), session cost, elapsed time, and prompt cache hit rate.

Copy the script:

```bash
mkdir -p ~/.claude
cp scripts/statusline.sh ~/.claude/statusline.sh
chmod +x ~/.claude/statusline.sh
```

The `statusLine` entry in `settings.json` points to this script. Requires `jq`.

### Global CLAUDE.md

The global `CLAUDE.md` file at `~/.claude/CLAUDE.md` sets default instructions for every Claude Code session. It covers development philosophy (no speculative features, no premature abstraction, replace don't deprecate), code quality hard limits (function length, complexity, line width), language-specific toolchains for Python (`uv`, `ruff`, `ty`), Node/TypeScript (`oxlint`, `vitest`), Rust (`clippy`, `cargo deny`), Bash, and GitHub Actions, plus testing methodology, code review order, and workflow conventions (commits, hooks, PRs).

Copy the template into place:

```bash
cp claude-md-template.md ~/.claude/CLAUDE.md
```

Review and customize it for your own preferences. The template is opinionated -- adjust the language sections, tool choices, and hard limits to match your stack. For background on how CLAUDE.md files work (hierarchy, auto memory, modular rules, imports), see [Manage Claude's memory](https://code.claude.com/docs/en/memory).

## Configuration

### Sandboxing

At Trail of Bits we run Claude Code in bypass-permissions mode (`--dangerously-skip-permissions`). This means you need to understand your sandboxing options -- the agent will execute commands without asking, so the sandbox is what keeps it from doing damage.

#### Built-in sandbox (`/sandbox`)

Claude Code has a native sandbox that provides filesystem and network isolation using OS-level primitives (Seatbelt on macOS, bubblewrap on Linux). Enable it by typing `/sandbox` in a session. In auto-allow mode, Bash commands that stay within sandbox boundaries run without permission prompts.

**Default behavior:** Writes are restricted to the current working directory and its subdirectories. Reads are unrestricted -- the agent can still read `~/.ssh`, `~/.aws`, etc. Network access is limited to explicitly allowed domains.

**Hardening reads:** The `settings.json` template includes `Read` and `Edit` deny rules that block access to credentials and secrets:

- **SSH/GPG keys** -- `~/.ssh/**`, `~/.gnupg/**`
- **Cloud credentials** -- `~/.aws/**`, `~/.azure/**`, `~/.kube/**`, `~/.docker/config.json`
- **Package registry tokens** -- `~/.npmrc`, `~/.npm/**`, `~/.pypirc`, `~/.gem/credentials`
- **Git credentials** -- `~/.git-credentials`, `~/.config/gh/**`
- **Shell config** -- `~/.bashrc`, `~/.zshrc` (edit denied, prevents backdoor planting)
- **macOS keychain** -- `~/Library/Keychains/**`
- **Crypto wallets** -- metamask, electrum, exodus, phantom, solflare app data

Without `/sandbox`, deny rules only block Claude's built-in tools -- Bash commands bypass them. With `/sandbox` enabled, the same rules are enforced at the OS level (Seatbelt/bubblewrap), so Bash commands are also blocked. Use both.

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

In practice, use them to:
- **Block known-bad patterns** -- `rm -rf`, push to main, wrong package manager
- **Add your own logging** -- audit trails, bash command logs, mutation tracking
- **Nudge Claude to keep going** -- a `Stop` hook can review Claude's final response and force it to continue if it's rationalizing incomplete work
- **Inject context at decision points** -- post-write lint results, pre-tool security warnings

Guide and examples: [Automate workflows with hooks](https://code.claude.com/docs/en/hooks-guide)

Don't want to write hooks by hand? The [hookify plugin](https://github.com/anthropics/claude-plugins-official/tree/main/plugins/hookify) generates them from plain English -- `/hookify Warn me when I use rm -rf commands`.

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

> **These are patterns to adapt, not drop-in configs.** Only the two blocking hooks in `settings.json` are recommended defaults. Everything else below is here for inspiration -- read the code, understand what it does, and tailor it to your workflow before using it.

**Blocking patterns** (`PreToolUse`, in `settings.json`): The two hooks in this repo's `settings.json` block `rm -rf` (suggests `trash` instead) and direct push to main/master (requires feature branches). Both read the Bash command from stdin via `jq`, match with regex, and exit 2 with an error message that tells Claude what to do instead.

**Audit logging** (`PostToolUse`): [`hooks/log-gam.sh`](hooks/log-gam.sh) shows how to build an audit trail for a CLI tool. This example tracks GAM (Google Apps Manager) commands -- it classifies each as read or write using verb pattern lists, skips reads, and logs mutations with timestamp, action, command, and exit status. The pattern generalizes: swap the verb lists for any CLI where you want to log mutations. Wire it up as a `PostToolUse` hook on `Bash`.

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
claude plugin marketplace add trailofbits/skills
claude plugin marketplace add trailofbits/skills-internal
claude plugin marketplace add trailofbits/skills-curated
```

| Repository | Description |
|------------|-------------|
| [trailofbits/skills](https://github.com/trailofbits/skills) | Our public skills for security auditing, smart contract analysis, reverse engineering, code review, and development workflows. |
| [trailofbits/skills-internal](https://github.com/trailofbits/skills-internal) | Automated exploitation, fuzz harness generation, vulnerability-class-specific analysis, audit report writing in the Trail of Bits house style, engagement scoping, client deliverables, and proprietary workflows. Private to Trail of Bits. |
| [trailofbits/skills-curated](https://github.com/trailofbits/skills-curated) | Third-party skills and external marketplaces we've vetted and approved for use. Every addition gets code review. |

For external marketplaces (Anthropic official, superpowers, compound-engineering, etc.), see [skills-curated](https://github.com/trailofbits/skills-curated) -- it maintains the approved list and install scripts.

#### agent-browser skill

The `agent-browser` CLI (installed in [Prerequisites](#tools)) ships its own marketplace with a first-party skill that teaches Claude the snapshot/ref workflow, command syntax, session management, authentication flows, video recording, and proxy support (~2,000 lines of reference material plus reusable shell templates). agent-browser is new enough that it's not in the model's pretraining data -- without this skill, Claude won't know the ref lifecycle or command API.

```
/plugin marketplace add vercel-labs/agent-browser
/plugin install agent-browser@agent-browser
```

#### Publishing skills

Where to publish depends on the audience:

- **Public and open source** -- submit a PR to [trailofbits/skills](https://github.com/trailofbits/skills).
- **Internal to Trail of Bits** -- submit a PR to [trailofbits/skills-internal](https://github.com/trailofbits/skills-internal).
- **Third-party skill you want approved** -- submit a PR to [trailofbits/skills-curated](https://github.com/trailofbits/skills-curated) with attribution to the original source. Every PR gets code review.

#### Writing skills and agents

When you find yourself repeating the same multi-step workflow, extract it into a skill or agent. Read Anthropic's [skill authoring best practices](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices) first for guidance on structure, descriptions, and progressive disclosure.

**Skills vs. agents.** Skills load instructions into the current session. They're guidance: conventions, checklists, decision trees that enhance whatever the user is already doing. Agents run in their own context window with a dedicated system prompt. They're specialists you hand a job to and get results back from. Use an agent when the work benefits from a focused persona, would bloat the main session with context, needs a constrained tool set, or should run in parallel with other work.

**Agent personas for security work.** Agents are underused in our plugins. A "senior auditor who's triaged hundreds of reentrancy bugs" approaches code differently than a "fuzzing engineer thinking about coverage and crash triage." The system prompt shapes what the agent notices and prioritizes, not just what steps it follows. When you have deep expertise in a vulnerability class or analysis methodology, encode it as an agent persona, not just a skill checklist.

**Tooling.** The `plugin-dev` plugin (from `claude-plugins-official`) has workflows for both. `/plugin-dev:skill-development` walks you through a 6-step process for skills. `/plugin-dev:agent-development` does the same for agents. For a full plugin with multiple components, use `/plugin-dev:create-plugin` to orchestrate the process.

**Quality.** For security skills and agents, don't just describe the workflow. Bundle the reference material that makes it expert-level: analysis checklists, vulnerability patterns, example outputs, and the decision logic an experienced auditor would apply. Keep the SKILL.md lean (under 2,000 words) and move detailed content into `references/` files.

### MCP Servers

Everyone at Trail of Bits should set up at least **Context7** and **Exa** as global MCP servers.

| Server | What it does | Requirements |
|--------|-------------|--------------|
| Context7 | Up-to-date library documentation lookup | None (no API key) |
| Exa | Web and code search (see [Web Browsing](#web-browsing)) | `EXA_API_KEY` env var ([get one here](https://exa.ai)) |

#### Setup

MCP servers are configured in `.mcp.json` files. Claude Code merges configs from two locations:

- **`~/.mcp.json`** -- global servers available in every session
- **`.mcp.json` in the project root** -- project-specific servers

Copy `mcp-template.json` from this repo to `~/.mcp.json` for global availability. Replace `your-exa-api-key-here` with your actual key, or remove the `exa` entry if you don't have one. Add project-specific MCP servers (e.g., a local database tool) to the project's `.mcp.json`.

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

For the full list of environment variables (model overrides, subagent models, traffic controls, etc.), see the [model configuration docs](https://code.claude.com/docs/en/model-config).

### Personalization

You can customize the spinner verbs that appear while Claude is working. Ask Claude: "In my settings, make my spinner verbs Hackers themed" — or Doom, or Star Trek, or anything else.

# Usage

Read Anthropic's [Best practices for Claude Code](https://code.claude.com/docs/en/best-practices) before anything in this section. It's the single most important resource for getting good results. Everything below builds on it.

## Continuous Improvement

Most people's use of Claude Code plateaus early. You find a workflow that works, repeat it, and never discover what you're leaving on the table. The fix is a deliberate feedback loop: review what happened, adjust your setup, and let the next week benefit from what you learned.

Run `/insights` once a week. It analyzes your recent sessions and surfaces patterns -- what's working, what's failing, where you're spending time. When it tells you something useful, act on it: add a rule to your CLAUDE.md, write a hook to block a mistake you keep making, extract a repeated workflow into a skill. Each adjustment compounds. After a few weeks your setup is meaningfully different from the defaults, tuned to how you actually work.

## Project-level CLAUDE.md

For each project you work on, add a `CLAUDE.md` at the repo root with project-specific context. The [global CLAUDE.md](#global-claudemd) sets defaults; the project file layers on what's unique to this codebase. A good project CLAUDE.md includes architecture (directory tree, key abstractions), build and test commands (`make dev`, `make test`), codebase navigation patterns (ast-grep examples for your codebase), domain-specific APIs and gotchas, and testing conventions.

For an example of a well-structured project CLAUDE.md, see [crytic/slither's CLAUDE.md](https://github.com/crytic/slither/blob/master/CLAUDE.md). It layers slither-specific context -- SlithIR internals, detector traversal patterns, type handling pitfalls -- on top of the same global standards from this repo.

## Output Styles

Enable the **Explanatory** [output style](https://code.claude.com/docs/en/output-styles) (`/output-style explanatory` or `"outputStyle": "Explanatory"` in `settings.json`) when getting familiar with a new codebase. Claude explains frameworks and code patterns as it works, adding "★ Insight" blocks with reasoning and design choices alongside its normal output. Useful when auditing unfamiliar code, reviewing a language you don't write daily, or onboarding onto a client engagement. The tradeoff is context: longer responses mean earlier compaction. Switch back to the default when you want speed. You can also [create custom styles](https://code.claude.com/docs/en/output-styles) as markdown files in `~/.claude/output-styles/`.

## Context Management

The context window is finite and irreplaceable mid-session. Every file read, tool call, and conversation turn consumes it. When it fills up, Claude auto-compacts -- summarizing the conversation to free space. Auto-compaction works, but it's lossy: subtle decisions, error details, and the thread of reasoning degrade each time. The best strategy is to avoid needing it.

### Keeping sessions clean

**Scope work to one session.** Each feature, bug fix, or investigation should fit within a single context window. If a task is too large, break it into pieces and run each in a fresh session. This is the single most effective thing you can do for quality.

A session that stays within its context budget produces better code than one that compacts three times to limp across the finish line. When you notice context running low (check the statusline -- green >50%, yellow >20%, red below), it's time to wrap up and start a new session, not push through.

**Prefer `/clear` over `/compact`.** `/clear` wipes the conversation and starts fresh. `/compact` summarizes and continues. Default to `/clear` between tasks.

`/compact` is useful when you're mid-task and need to reclaim space without losing your place, but each compaction is a lossy compression -- details get dropped, and the model's understanding of your intent degrades slightly. Two compactions in a session is a sign the task was too large. `/clear` has no information loss because there's nothing to lose -- your CLAUDE.md reloads, git state is fresh, and the agent re-reads whatever files it needs. When you do use `/compact`, pass focus instructions to steer the summary: `/compact Focus on the auth refactor` preserves what matters and sheds the rest.

**Cut your losses after two corrections.** If you've corrected Claude twice on the same issue and it's still wrong, don't keep pushing -- the context is polluted with failed approaches. Use checkpoints (`Esc Esc` or `/rewind`) to roll back to before the first wrong attempt and try again with a better prompt. If the session is too far gone even for that, `/clear` and start fresh. A clean prompt that incorporates what you learned almost always outperforms a long session with accumulated corrections.

### Tools for managing context

**Checkpoints** (`Esc Esc` or `/rewind`) restore code and conversation to any previous prompt in the session. They're your undo system -- use them aggressively. Try risky approaches knowing you can rewind if they don't work out.

The "Summarize from here" option in the rewind menu is a more surgical alternative to `/compact`: instead of compressing everything, you keep early context intact and only summarize the part that's eating space (like a verbose debugging tangent). This preserves your initial instructions at full fidelity.

**Offload research to subagents.** Subagents (Task tool, custom agents) each get their own context window. The main session only sees the subagent's summary, not its full working context.

Use this deliberately: when a task requires reading a lot of documentation, exploring unfamiliar code, or doing research that would bloat your main session, delegate it to a subagent. The main session stays lean and focused on implementation while subagents handle the context-heavy exploration.

**For complex features, interview first, implement second.** Have Claude interview you about the feature (requirements, edge cases, tradeoffs), then write a spec to a file. Start a fresh session to implement the spec.

**Put stable context in CLAUDE.md, not the conversation.** Project architecture, coding standards, tool preferences, workflow conventions -- anything reusable goes in CLAUDE.md. It loads automatically every session and survives `/clear`.

If you need to pass context between sessions, commit your work, write a brief plan to a file, `/clear`, and start the next session by pointing Claude at that file. You can also resume previous sessions with `claude --continue` (picks up the last session) or `claude --resume` (lets you choose from recent sessions). But a fresh session with a written handoff is usually better than resuming a stale one -- the context is cleaner and the prompt cache is warm.

## Web Browsing

Claude Code has three ways to interact with the web.

### Exa AI (MCP)

Semantic web search that returns clean, LLM-optimized text. Unlike the built-in `WebSearch` tool (which returns search result links that Claude then has to fetch and parse), Exa returns the actual content pre-extracted and formatted for LLM consumption. This saves context window and produces more relevant results. Your CLAUDE.md can instruct Claude to prefer Exa over `WebSearch`.

### agent-browser

Headless browser automation via CLI. Runs its own Chromium instance -- it does **not** share your Chrome profile, cookies, or login sessions. This means it can't access authenticated pages (Google Docs, internal dashboards, etc.) without logging in from scratch. What it excels at is context efficiency: the snapshot/ref system (`@e1`, `@e2`) uses ~93% less context than sending full accessibility trees, so the agent can navigate complex multi-page workflows without exhausting its context window. Also supports video recording and parallel sessions.

```bash
agent-browser open <url>        # Navigate
agent-browser snapshot -i       # Get element refs (@e1, @e2)
agent-browser click @e1         # Click element
agent-browser fill @e2 "text"   # Fill input
agent-browser screenshot        # Capture screenshot
```

You need to install the first-party skill for Claude to use agent-browser effectively -- see [agent-browser skill](#agent-browser-skill) in Configuration.

### Claude in Chrome (MCP)

Browser automation via the [Claude in Chrome](https://chromewebstore.google.com/detail/claude/fcoeoabgfenejglbffodgkkbkcdhcgfn) extension. Operates inside your actual Chrome browser, so it has access to your existing login sessions, cookies, and extensions. This is the only option that can interact with authenticated pages (Gmail, Google Docs, Jira, internal tools) without re-authenticating. The tradeoff is that it uses screenshots and accessibility trees for page understanding, which consumes more context than agent-browser's ref system.

### When to use which

| Need | Use |
|------|-----|
| Search the web for information | Exa |
| Automate multi-step workflows on public pages | agent-browser |
| Interact with authenticated/internal pages | Claude in Chrome |
| Record a video of browser actions | agent-browser |
| Inspect visual layout or take screenshots for analysis | Claude in Chrome |

## Fast Mode

`/fast` toggles fast mode. Same Opus 4.6 model, ~2.5x faster output, 6x the cost per token. Leave it off by default.

The only time fast mode is worth it is **tight interactive loops** -- you're debugging live, iterating on output, and every second of latency costs you focus. If you're about to kick off an autonomous run (`/fix-issue`, a swarm, anything you walk away from), turn it off first. The agent doesn't benefit from lower latency; you're just burning money.

If you do use it, enable it at session start. Toggling it on mid-conversation reprices your entire context at fast-mode rates and invalidates prompt cache. See the [fast mode docs](https://code.claude.com/docs/en/fast-mode) for details.

## Commands

Custom slash commands are markdown files that define reusable workflows. The two in `commands/` were extracted from manual workflows that kept showing up in `/insights` -- if you notice yourself repeating the same multi-step sequence, it's a good candidate for a command.

```bash
mkdir -p ~/.claude/commands
cp commands/review-pr.md ~/.claude/commands/
cp commands/fix-issue.md ~/.claude/commands/
```

### Review PR

[`commands/review-pr.md`](commands/review-pr.md) -- Reviews a GitHub PR with parallel agents, fixes findings, and pushes. Invoke with `/review-pr 456` where `456` is the PR number.

### Fix Issue

[`commands/fix-issue.md`](commands/fix-issue.md) -- Takes a GitHub issue and fully autonomously completes it -- plans, implements, tests, creates a PR, self-reviews with parallel agents, fixes its own findings, and comments on the issue when done. Invoke with `/fix-issue 123` where `123` is the issue number.

Once a workflow is a command, it's not just faster for you -- it's something an agent can run too. You can point `/fix-issue` at 50 issues in parallel across worktrees, run `/review-pr` on every open PR in a repo, or schedule either as part of CI. Commands turn manual workflows into scalable operations.

## Recommended Skills

Skills come from plugins you install via the Trail of Bits marketplaces and third-party marketplaces. Here are the ones worth knowing about from each.

### Trail of Bits ([trailofbits/skills](https://github.com/trailofbits/skills))

Security auditing, code analysis, and development workflows. Installed automatically with the Trail of Bits marketplace.

| Skill | What it does | When to use it |
|-------|-------------|----------------|
| `ask-questions-if-underspecified` | Asks 1-5 targeted clarification questions before starting work | Any underspecified request -- prevents building the wrong thing |
| `modern-python` | Configures projects with uv, ruff, ty, pytest, prek | New Python projects or migrating from pip/Poetry/mypy/black |
| `audit-context-building` | Line-by-line code analysis using First Principles and 5 Whys methodology | Building deep understanding of unfamiliar code before an audit |
| `differential-review` | Security-focused review of code changes with blast radius analysis | Reviewing PRs or commits where security impact matters |

### Superpowers ([obra/superpowers](https://github.com/obra/superpowers))

Workflow discipline -- enforces planning before coding, structured debugging, and verification before declaring victory. The skills chain together: brainstorm → plan → execute → verify.

| Skill | What it does | When to use it |
|-------|-------------|----------------|
| `/superpowers:brainstorm` | Refines ideas through Socratic questioning before implementation | Starting any non-trivial feature -- catches unclear requirements early |
| `/superpowers:systematic-debugging` | Structured 4-phase root cause analysis | Any bug where the cause isn't obvious -- prevents treating symptoms |

### Anthropic Official ([anthropics/claude-code/plugins](https://github.com/anthropics/claude-code/tree/main/plugins))

Official plugins maintained in the Claude Code repo. Install via the `claude-plugins-official` marketplace.

| Skill | What it does | When to use it |
|-------|-------------|----------------|
| `frontend-design` | Auto-invoked on frontend tasks with guidance on bold design, typography, animations, and visual polish -- avoids generic AI aesthetics | Building web components, pages, or applications where visual quality matters |
| `/pr-review-toolkit:review-pr` | Runs 6 specialized agents in parallel: comments, tests, error handling, type design, code quality, and code simplification | PR review -- run with `all` or pick specific aspects (`simplify`, `tests`, `errors`, etc.) |

The `code-simplifier` agent inside `pr-review-toolkit` can also be targeted individually with `/pr-review-toolkit:review-pr simplify` for a focused simplification pass.

### Compound Engineering ([EveryInc/compound-engineering-plugin](https://github.com/EveryInc/compound-engineering-plugin))

Multi-agent workflows for planning and review.

| Skill | What it does | When to use it |
|-------|-------------|----------------|
| `/workflows:plan` | Turns feature descriptions into implementation plans with parallel research agents | Starting a feature that touches multiple files or components |
| `/workflows:review` | Runs 15 specialized review agents in parallel (security, performance, architecture, style) | Before merging any significant PR -- catches what solo review misses |

## Recommended MCP Servers

Beyond the core Context7 and Exa servers (see [MCP Servers](#mcp-servers)), these are worth adding for specific workflows.

| Server | What it does | Requirements |
|--------|-------------|--------------|
| [Granola](https://granola.ai) | Meeting notes and transcripts | Granola app with paid plan |
| [slither-mcp](https://github.com/trailofbits/slither-mcp) | Slither static analysis for Solidity smart contracts -- vulnerability detection, call graphs, inheritance mapping, function metadata | Python 3.11+, Solidity compiler (Foundry/Hardhat) |
| [pyghidra-mcp](https://github.com/clearbluejar/pyghidra-mcp) | Headless Ghidra reverse engineering -- binary analysis, decompilation, cross-references, semantic search via embeddings | Ghidra (`GHIDRA_INSTALL_DIR` env var) |
| [Serena](https://github.com/oraios/serena) | Symbol-level code navigation and editing across 30+ languages via LSP -- find symbols, references, and edit by symbol rather than line number | `uv`, language-specific LSP servers |
