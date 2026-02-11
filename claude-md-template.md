# Global Development Standards

Global instructions for all projects. Project-specific CLAUDE.md files override these defaults.

## Philosophy

- **No speculative features** - Don't add "might be useful" functionality
- **No premature abstraction** - Don't create utilities until you've written the same code three times; but preserve abstractions that genuinely improve organization
- **Clarity over cleverness** - Prefer explicit, readable code over dense one-liners; reduce nesting with early returns
- **Justify new dependencies** - Each dependency is attack surface and maintenance burden
- **No unnecessary configuration** - Don't add flags unless users actively need them
- **No phantom features** - Don't document or validate features that aren't implemented
- **Agent-native by default** - Design so agents can achieve any outcome users can. Tools are atomic primitives; features are outcomes described in prompts. Prefer file-based state for transparency and portability. When adding UI capability, ask: can an agent achieve this outcome too?

## Code Quality

### Hard limits

1. ≤100 lines/function, cyclomatic complexity ≤8
2. ≤5 positional params, ≤12 branches, ≤6 returns
3. 100-char line length
4. Ban relative (`..`) imports
5. Google-style docstrings on non-trivial public APIs
6. All code must pass type checking—no `type: ignore` without justification

### Comments

Code should be self-documenting. If you need a comment to explain WHAT the code does, refactor.

- No comments that repeat what code does
- No commented-out code (delete it)
- No obvious comments ("increment counter")
- No comments instead of good naming

### Error handling

- Fail fast with clear, actionable messages
- Never swallow exceptions silently
- Include context (what operation, what input, suggested fix)

### When uncertain

- State your assumption and proceed for small decisions
- Ask before changes with significant unintended consequences

### Reviewing code

Evaluate in this order: architecture (component boundaries, coupling, data flow, scaling, single points of failure) → code quality (DRY violations, error handling gaps, tech debt hotspots) → tests (coverage gaps, missing edge cases, untested error paths) → performance (N+1 queries, memory, caching opportunities, high-complexity paths).

For each issue found:
- Describe concretely with file:line references
- Present 2–3 options (including "do nothing" where reasonable)
- For each option: effort, risk, impact on other code, maintenance burden
- Give your recommended option and why
- Ask before proceeding

## Development

### CLI tools

| tool | replaces | usage |
|------|----------|-------|
| `rg` (ripgrep) | grep | `rg "pattern"` - 10x faster regex search |
| `fd` | find | `fd "*.py"` - fast file finder |
| `ast-grep` | - | `ast-grep --pattern '$FUNC($$$)' --lang py` - AST-based code search |
| `shellcheck` | - | `shellcheck script.sh` - shell script linter |
| `shfmt` | - | `shfmt -i 2 -w script.sh` - shell formatter |
| `actionlint` | - | `actionlint .github/workflows/` - GitHub Actions linter |
| `zizmor` | - | `zizmor .github/workflows/` - Actions security audit |
| `prek` | pre-commit | `prek run` - fast git hooks (Rust, no Python) |
| `wt` | git worktree | `wt switch branch` - manage parallel worktrees |
| `trash` | rm | `trash file` - moves to macOS Trash (recoverable). **Never use `rm -rf`** |

```bash
# ast-grep structural search (prefer over grep for code patterns)
ast-grep --pattern 'print($$$)' --lang py              # Find function calls
ast-grep --pattern 'class $NAME: $$$' --lang py        # Find classes
ast-grep --pattern 'async def $F($$$): $$$' --lang py  # Find async functions
# $NAME = identifier, $$$ = any code. Languages: py, js, ts, rust, go
```

### Python

**Runtime:** 3.13 with `uv venv`

| purpose | tool |
|---------|------|
| deps & venv | `uv` |
| lint & format | `ruff check` · `ruff format` |
| static types | `ty check` |
| tests | `pytest -q` |

```bash
uv run ruff check --fix
uv run ty check
pytest -q
```

- `uv` instead of pip; `uv_build` for pure Python, `hatchling` for extensions
- `ruff` only for linting (replaces black/pylint/flake8)
- `ty check` for type checking; configure strictness via `[tool.ty.rules]` in pyproject.toml

### Node/TypeScript

**Runtime:** Node 22 LTS

| purpose | tool |
|---------|------|
| lint | `oxlint` |
| format | `oxfmt` |
| test | `vitest` |
| types | `tsc --noEmit` |

```bash
oxlint .
oxfmt --write .
vitest run
tsc --noEmit
```

### Rust

**Runtime:** Latest stable via `rustup`

| purpose | tool |
|---------|------|
| build & deps | `cargo` |
| lint | `cargo clippy --all-targets --all-features -- -D warnings` |
| format | `cargo fmt` |
| test | `cargo test` |
| supply chain | `cargo deny check` (advisories, licenses, bans) |
| safety check | `cargo careful test` (stdlib debug assertions + UB checks) |

**MANDATORY:** Run every tool in the table above before committing. Fix all warnings and ensure all checks pass—no exceptions.

**Style:**
- Prefer `for` loops with mutable accumulators over iterator chains
- Shadow variables through transformations (no `raw_x`/`parsed_x` prefixes)
- No wildcard matches; avoid `matches!` macro—explicit destructuring catches field changes
- Use `let...else` for early returns; keep happy path unindented

**Type design:**
- Newtypes over primitives (`UserId(u64)` not `u64`)
- Enums for state machines, not boolean flags
- `thiserror` for libraries, `anyhow` for applications
- `tracing` for logging (`error!`/`warn!`/`info!`/`debug!`), not println

**Optimization:**
- All code must be fully optimized: algorithmic efficiency, parallelization, SIMD where applicable
- Profile before optimizing; measure after

**Cargo.toml lints:**
```toml
[lints.clippy]
pedantic = { level = "warn", priority = -1 }
# Panic prevention
unwrap_used = "deny"
expect_used = "warn"
panic = "deny"
panic_in_result_fn = "deny"
unimplemented = "deny"
# No cheating
allow_attributes = "deny"
# Code hygiene
dbg_macro = "deny"
todo = "deny"
print_stdout = "deny"
print_stderr = "deny"
# Safety
await_holding_lock = "deny"
large_futures = "deny"
exit = "deny"
mem_forget = "deny"
# Pedantic relaxations (too noisy)
module_name_repetitions = "allow"
similar_names = "allow"
```

### Bash

All scripts must start with `set -euo pipefail`. Lint: `shellcheck script.sh && shfmt -d script.sh`

## Workflow

### Making changes

1. Run linters and type checker before committing
2. Run relevant tests (not full suite) after changes
3. Use `git diff` to verify changes before committing
4. Never commit changes that break rules above—refactor instead
5. For large reviews or multi-area changes, work one section at a time and pause for feedback before moving on

### Git

- Commit messages: imperative mood, ≤72 char subject line
- One logical change per commit
- Never amend/rebase commits already pushed to shared branches
- Never push directly to main—use feature branches and PRs

### Git worktrees

Use `wt` (worktrunk) for managing parallel workspaces—enables running multiple agents simultaneously.

```bash
wt list                    # List all worktrees
wt switch <branch>         # Create/switch to worktree for branch
wt remove <branch>         # Clean up worktree and optionally delete branch
wt merge <branch>          # Merge with squash/rebase options
```

**MANDATORY: Parallel subagents require worktrees.** When launching multiple subagents to work on separate issues/branches:
- Each subagent MUST work in its own worktree (not the main repo)
- Create worktree first: `wt switch <branch>` → gives path like `~/.worktrees/repo/branch`
- Pass the worktree path to the subagent, not the main repo path
- Never have multiple subagents share the same working directory

Use `/parallel-issue-fixing` skill for the full workflow template.

### Git hooks

Use `prek` for pre-commit hooks (Rust-based, no Python): `prek install`, `prek run`, `prek auto-update --cooldown-days 7`

### GitHub Actions

Pin actions to SHA hashes with version comments: `actions/checkout@<full-sha>  # vX.Y.Z` (use `persist-credentials: false`)

### Dependabot

Configure 7-day cooldowns in `.github/dependabot.yml` for supply chain protection (`cooldown.default-days: 7`).

## Code Review

Before reviewing or comparing PR code, always ensure the local repo is synced to the latest remote state (`git pull` or `git fetch origin`) to avoid reviewing stale code.

## Pull Requests

When creating PRs, describe the current state of the code — not the journey of how it got there. If multiple approaches were tried across commits, the PR description should only reflect what actually landed. Do not include aspirational or planned changes that aren't in the diff.

## Skills

**Proactive skill usage is mandatory.** Before starting any non-trivial task:
1. Review available skills for applicability
2. Use the Skill tool to invoke matching skills—don't just announce them
3. If no skill applies, proceed normally

**Recommend missed opportunities.** If you notice a skill would help but wasn't requested:
- Mention it briefly: "Consider using `/skill-name` for this—it handles [specific benefit]"
- Don't block on it—offer and continue

**Key triggers:**

| When... | Use |
|---------|-----|
| Starting non-trivial work | `/superpowers:brainstorm` first |
| Need implementation plan | `/superpowers:write-plan` |
| Executing a plan | `/superpowers:execute-plan` |
| Implementing features/bugfixes | `/superpowers:test-driven-development` |
| Debugging any failure | `/superpowers:systematic-debugging` |
| Before claiming "done" | `/superpowers:verification-before-completion` |
| Creating commits | `/commit` |
| Commit + push + PR | `/commit-push-pr` |
| PR ready for review | `/code-review` |
| Building frontend UIs | `/frontend-design` |
| Multi-phase feature work | `/feature-dev` |
| Need parallel workspace | `/superpowers:using-git-worktrees` |

### Compound Engineering

| When... | Use |
|---------|-----|
| Planning features/bugs | `/compound-engineering:workflows:plan` |
| Multi-agent code review | `/compound-engineering:workflows:review` |
| Executing work items | `/compound-engineering:workflows:work` |
| Documenting solved problems | `/compound-engineering:workflows:compound` |
| Performance analysis | `performance-oracle` agent |
| Architecture review | `architecture-strategist` agent |
| Research framework docs | `framework-docs-researcher` agent |
| Analyze git history | `git-history-analyzer` agent |
| Simplify code | `code-simplicity-reviewer` agent |
| Python code review | `kieran-python-reviewer` agent |
| Designing agent-native systems | `/compound-engineering:agent-native-architecture` |
| Auditing agent parity | `/compound-engineering:agent-native-audit` |
| Agent-native parity review | `agent-native-reviewer` agent |

### Browser Automation

Two options available:

| Tool | Best for |
|------|----------|
| `agent-browser` | CLI-based, scriptable, video recording, parallel sessions |
| Claude in Chrome (MCP) | Visual inspection, screenshots with image analysis |

**agent-browser quick reference:**
```bash
agent-browser open <url>        # Navigate
agent-browser snapshot -i       # Get interactive elements with refs
agent-browser click @e1         # Click by ref
agent-browser fill @e2 "text"   # Fill input
agent-browser screenshot        # Capture screenshot
agent-browser record start demo.webm && ... && agent-browser record stop
```

## Web Search

**Prefer Exa AI** (`mcp__exa__web_search_exa`) over the built-in `WebSearch` tool for all web searches. Exa returns higher-quality, more relevant results. Use `WebSearch` only as a fallback if Exa is unavailable or returns errors.

## Security

### Version verification

When adding dependencies, CI actions, or tool versions:
1. **Always web search** for the current stable version
2. Training data versions are stale—never assume from memory
3. Exception: Skip if user explicitly provides the version

### Secrets

- Never commit secrets, API keys, or credentials
- Use `.env` files (gitignored) for local dev
- Reference secrets via environment variables

### Python supply chain

- Run `pip-audit` before deploying
- Pin exact versions in production (`==` not `>=`)
- Verify hashes: `uv pip install --require-hashes`

### Node supply chain

```bash
# MANDATORY before any install
pnpm config set minimumReleaseAge 1440  # 24-hour delay
pnpm config set ignore-scripts true     # Block postinstall attacks
```

- Audit first: `pnpm audit --audit-level=moderate`
- Pin exact versions (no `^` or `~`) in production

## Testing

**Mock boundaries, not logic.** Only mock things that are slow (network, filesystem), non-deterministic (time, randomness), or external services you don't control.

**Verify tests catch failures:**
1. Write the test for the bug/behavior you're preventing
2. Temporarily break the code to verify the test fails
3. Fix and verify it passes

### Python test quality

- Extract shared setup into pytest fixtures
- Use `pytest.mark.parametrize` for test variations
- Use `pytest-httpx` to mock HTTP endpoints
- Use snapshot testing (`syrupy`) for complex outputs

### Conventions

- Python: `tests/` directory mirroring package structure
- Node/TS: colocated `*.test.ts` files
- No scheduled CI without code changes—activity without progress is theater

---

> Don't push until explicitly asked. Don't be hyperbolic in PR writeups.
