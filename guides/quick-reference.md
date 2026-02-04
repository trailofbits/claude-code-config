# Quick Reference

## Skills

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

## Compound Engineering Agents

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

## CLI Tools

| Tool | Replaces | Usage |
|------|----------|-------|
| `rg` | grep | `rg "pattern"` |
| `fd` | find | `fd "*.py"` |
| `ast-grep` | - | `ast-grep --pattern '$FUNC($$$)' --lang py` |
| `trash` | rm | `trash file` (recoverable) |
| `wt` | git worktree | `wt switch branch` |
| `prek` | pre-commit | `prek run` |

## Browser Automation (agent-browser)

```bash
agent-browser open <url>        # Navigate
agent-browser snapshot -i       # Get element refs (@e1, @e2)
agent-browser click @e1         # Click element
agent-browser fill @e2 "text"   # Fill input
agent-browser screenshot        # Capture screenshot
agent-browser wait --load networkidle
```

**Workflow:** open → snapshot → interact → re-snapshot (after navigation)

## Language Tooling

### Python (3.13)

| Purpose | Tool |
|---------|------|
| Deps | `uv` |
| Lint/Format | `ruff check` / `ruff format` |
| Types | `ty check` |
| Tests | `pytest -q` |

### Node/TypeScript (22 LTS)

| Purpose | Tool |
|---------|------|
| Lint | `oxlint` |
| Format | `oxfmt` |
| Types | `tsc --noEmit` |
| Tests | `vitest` |

### Rust

| Purpose | Tool |
|---------|------|
| Lint | `cargo clippy --all-targets --all-features -- -D warnings` |
| Format | `cargo fmt` |
| Tests | `cargo test` |
| Supply chain | `cargo deny check` |

## Code Quality Limits

- 100 lines/function max
- Cyclomatic complexity ≤8
- 5 positional params max
- 100-char line length
- No relative (`..`) imports
