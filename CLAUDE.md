# Global Development Standards

Global instructions for all projects. Project-specific CLAUDE.md files override these defaults.

## Philosophy

- **No speculative features** - Don't add "might be useful" functionality
- **No premature abstraction** - Don't create utilities until you've written the same code three times; but preserve abstractions that genuinely improve organization
- **Clarity over cleverness** - Prefer explicit, readable code over dense one-liners; reduce nesting with early returns
- **Justify new dependencies** - Each dependency is attack surface and maintenance burden
- **No unnecessary configuration** - Don't add flags unless users actively need them
- **No phantom features** - Don't document or validate features that aren't implemented

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

### Git hooks

Use `prek` for pre-commit hooks (Rust-based, no Python): `prek install`, `prek run`, `prek auto-update --cooldown-days 7`

### GitHub Actions

Pin actions to SHA hashes with version comments: `actions/checkout@<full-sha>  # vX.Y.Z` (use `persist-credentials: false`)

### Dependabot

Configure 7-day cooldowns in `.github/dependabot.yml` for supply chain protection (`cooldown.default-days: 7`).

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
