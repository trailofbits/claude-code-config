# claude-code-config

Reference setup for Claude Code at Trail of Bits. Not a plugin -- just documentation and config files you copy into place.

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

Rust toolchain (optional -- skip if you don't write Rust):

```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
cargo install prek worktrunk cargo-deny cargo-careful
```

Node tools (optional):

```bash
npm install -g oxlint
```

## Shell Setup

Add to `~/.zshrc`:

```bash
alias claude-yolo="claude --dangerously-skip-permissions"
```

`--dangerously-skip-permissions` bypasses all permission prompts. This is the recommended way to run Claude Code for maximum throughput -- pair it with sandboxing (next section).

## Sandboxing

Bypass-permissions mode should be paired with a sandbox so the agent can't escape the project directory or affect the host system:

- [trailofbits/claude-code-devcontainer](https://github.com/trailofbits/claude-code-devcontainer) -- devcontainer-based sandbox with full VS Code integration
- [trailofbits/dropkit](https://github.com/trailofbits/dropkit) -- lightweight macOS sandbox using `sandbox-exec`

## Global CLAUDE.md

The global `CLAUDE.md` file at `~/.claude/CLAUDE.md` sets default instructions for every Claude Code session. It defines code quality limits, tooling preferences, workflow conventions, and skill triggers.

Copy the template into place:

```bash
cp claude-md-template.md ~/.claude/CLAUDE.md
```

Review and customize it for your own preferences. The template is opinionated -- it assumes specific tools (`ruff`, `ty`, `oxlint`, `cargo clippy`, etc.) and enforces hard limits on function length, complexity, and line width.

## Settings

Copy `settings.json` to `~/.claude/settings.json` (or merge entries into your existing file).

### Safety hooks

Two Bash hooks that block dangerous operations:

| Hook | What it blocks |
|------|----------------|
| `rm -rf` blocker | Catches `rm -rf` commands, suggests `trash` instead |
| `git push to main` blocker | Catches direct push to main/master, requires feature branches |

These are pre-tool hooks -- they run before Claude executes any Bash command and exit non-zero to block the operation.

Hook exit codes:

| Exit code | Behavior |
|-----------|----------|
| 0 | Command allowed |
| 1 | Command blocked (silent) |
| 2 | Command blocked (show stderr message to user) |

### Statusline

A two-line status bar showing repo context, git branch, lines changed, model name, cost, session time, context window remaining, and cache hit rate.

Copy the script:

```bash
mkdir -p ~/.claude
cp scripts/statusline.sh ~/.claude/statusline.sh
chmod +x ~/.claude/statusline.sh
```

The `statusLine` entry in `settings.json` points to this script. Requires `jq`.

### Plugins and marketplaces

The `settings.json` file includes `enabledPlugins` with four plugins enabled by default:

| Plugin | Marketplace | Purpose |
|--------|-------------|---------|
| `superpowers` | superpowers-marketplace | Brainstorming, TDD, debugging, verification workflows |
| `superpowers-developing-for-claude-code` | superpowers-marketplace | Plugin/skill development helpers |
| `compound-engineering` | every-marketplace | Planning, review, work execution workflows |
| `agent-browser` | agent-browser | Browser automation CLI |

Marketplaces are registered in `~/.claude/plugins/known_marketplaces.json`. The [trailofbits/skills-curated](https://github.com/trailofbits/skills-curated) repo maintains the recommended list of marketplaces -- see its README for the current JSON to copy into place.

Install the plugins:

```bash
claude plugins install superpowers@superpowers-marketplace
claude plugins install superpowers-developing-for-claude-code@superpowers-marketplace
claude plugins install compound-engineering@every-marketplace
claude plugins install agent-browser@agent-browser
```

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

## Skills Repositories

Trail of Bits maintains three skills repositories installed as Claude Code plugins:

- [trailofbits/skills](https://github.com/trailofbits/skills) -- public skills for security auditing, code review, and development workflows
- [trailofbits/skills-internal](https://github.com/trailofbits/skills-internal) -- internal skills for Trail of Bits engineers (private)
- [trailofbits/skills-curated](https://github.com/trailofbits/skills-curated) -- curated third-party skills and recommended plugin marketplaces

`skills-curated` also maintains the canonical `known_marketplaces.json` listing all vetted marketplaces.

Install from the Trail of Bits marketplace:

```bash
claude plugins install trailofbits@trailofbits
claude plugins install trailofbits-internal@trailofbits-internal
claude plugins install skills-curated@trailofbits-curated
```

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

## Quick Reference

### Skills

| Trigger | Skill | Purpose |
|---------|-------|---------|
| Starting work | `/superpowers:brainstorm` | Refine ideas before implementing |
| Need plan | `/superpowers:write-plan` | Create implementation plan |
| Executing plan | `/superpowers:execute-plan` | Run plan in batches |
| Features/bugfixes | `/superpowers:test-driven-development` | Write test first |
| Debugging | `/superpowers:systematic-debugging` | Four-phase debug framework |
| Before "done" | `/superpowers:verification-before-completion` | Verify before claiming complete |
| Creating commits | `/commit` | Guided commit workflow |
| Full PR workflow | `/commit-push-pr` | Commit, push, create PR |
| Code review | `/code-review` | Review PR |
| Frontend UIs | `/frontend-design` | Build interfaces |
| Browser automation | `/agent-browser` | Automate web interactions |

### Compound Engineering Agents

| Agent | Purpose |
|-------|---------|
| `performance-oracle` | Performance analysis |
| `architecture-strategist` | Architecture review |
| `framework-docs-researcher` | Research framework docs |
| `git-history-analyzer` | Analyze git history |
| `code-simplicity-reviewer` | Simplify code |
| `kieran-python-reviewer` | Python code review |
| `kieran-rails-reviewer` | Rails code review |
| `kieran-typescript-reviewer` | TypeScript code review |

### CLI Tools

| Tool | Replaces | Usage |
|------|----------|-------|
| `rg` | grep | `rg "pattern"` |
| `fd` | find | `fd "*.py"` |
| `ast-grep` | -- | `ast-grep --pattern '$FUNC($$$)' --lang py` |
| `trash` | rm | `trash file` (recoverable) |
| `wt` | git worktree | `wt switch branch` |
| `prek` | pre-commit | `prek run` |

### Language Tooling

**Python (3.13)**

| Purpose | Tool |
|---------|------|
| Deps | `uv` |
| Lint/Format | `ruff check` / `ruff format` |
| Types | `ty check` |
| Tests | `pytest -q` |

**Node/TypeScript (22 LTS)**

| Purpose | Tool |
|---------|------|
| Lint | `oxlint` |
| Format | `oxfmt` |
| Types | `tsc --noEmit` |
| Tests | `vitest` |

**Rust**

| Purpose | Tool |
|---------|------|
| Lint | `cargo clippy --all-targets --all-features -- -D warnings` |
| Format | `cargo fmt` |
| Tests | `cargo test` |
| Supply chain | `cargo deny check` |

### Code Quality Limits

- 100 lines/function max
- Cyclomatic complexity <=8
- 5 positional params max
- 100-char line length
- No relative (`..`) imports

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

### Write custom skills

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

For team-wide skills, publish them to a plugin marketplace (see [Skills Repositories](#skills-repositories)).

## Related Repositories

| Repository | Description |
|------------|-------------|
| [trailofbits/skills](https://github.com/trailofbits/skills) | Public plugin marketplace |
| [trailofbits/skills-internal](https://github.com/trailofbits/skills-internal) | Internal plugin marketplace (private) |
| [trailofbits/skills-curated](https://github.com/trailofbits/skills-curated) | Curated marketplaces and third-party skills |
| [trailofbits/dropkit](https://github.com/trailofbits/dropkit) | Lightweight macOS sandbox |
| [trailofbits/claude-code-devcontainer](https://github.com/trailofbits/claude-code-devcontainer) | VS Code devcontainer for Claude Code |
| [anthropics/knowledge-work-plugins](https://github.com/anthropics/knowledge-work-plugins) | Anthropic's knowledge work plugins |
| [coreyhaines31/marketingskills](https://github.com/coreyhaines31/marketingskills) | Marketing-focused skills |

## Recommended Reading

- [Best practices for Claude Code](https://code.claude.com/docs/en/best-practices) -- Anthropic's official guide to working effectively with Claude Code
- [Here's how I use LLMs to help me write code](https://simonwillison.net/2025/Mar/11/using-llms-for-code/) -- Simon Willison on practical LLM-assisted coding techniques
- [AI-assisted coding for teams that can't get away with vibes](https://blog.nilenso.com/blog/2025/05/29/ai-assisted-coding/) -- Nilenso's playbook for teams integrating AI tools with high standards
- [My AI Skeptic Friends Are All Nuts](https://fly.io/blog/youre-all-nuts/) -- Thomas Ptacek on why dismissing LLMs for coding is a mistake
- [Harness engineering](https://openai.com/index/harness-engineering/) -- OpenAI on building a product with zero manually-written code
