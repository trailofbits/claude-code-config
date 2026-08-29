## Development

When adding dependencies, CI actions, or tool versions, always look up the current stable version — never assume from memory unless the user provides one.

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

Prefer `ast-grep` over ripgrep when searching for code structure (function calls, class definitions, imports, pattern matching across arguments). Use ripgrep for literal strings and log messages.

### Python

**Runtime:** 3.13 with `uv venv`

| purpose | tool |
|---------|------|
| deps & venv | `uv` |
| lint & format | `ruff check` · `ruff format` |
| static types | `ty check` |
| tests | `pytest -q` |

**Always use uv, ruff, and ty** over pip/poetry, black/pylint/flake8, and mypy/pyright — they're faster and stricter. Configure `ty` strictness via `[tool.ty.rules]` in pyproject.toml. Use `uv_build` for pure Python, `hatchling` for extensions.

Tests in `tests/` directory mirroring package structure. Supply chain: `pip-audit` before deploying, pin exact versions (`==` not `>=`), verify hashes with `uv pip install --require-hashes`.

### Node/TypeScript

**Runtime:** Node 22 LTS, ESM only (`"type": "module"`)

| purpose | tool |
|---------|------|
| lint | `oxlint` |
| format | `oxfmt` |
| test | `vitest` |
| types | `tsc --noEmit` |

**Always use oxlint and oxfmt** over eslint/prettier — they're faster and stricter. Enable `typescript`, `import`, `unicorn` plugins.

**tsconfig.json strictness** — enable all of these:
```jsonc
"strict": true,
"noUncheckedIndexedAccess": true,
"exactOptionalPropertyTypes": true,
"noImplicitOverride": true,
"noPropertyAccessFromIndexSignature": true,
"verbatimModuleSyntax": true,
"isolatedModules": true
```

Colocated `*.test.ts` files. Supply chain: `pnpm audit --audit-level=moderate` before installing, pin exact versions (no `^` or `~`), enforce 24-hour publish delay (`pnpm config set minimumReleaseAge 1440`), block postinstall scripts (`pnpm config set ignore-scripts true`).

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
- Write efficient code by default — correct algorithm, appropriate data structures, no unnecessary allocations
- Profile before micro-optimizing; measure after

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

### GitHub Actions

Pin actions to SHA hashes with version comments: `actions/checkout@<full-sha>  # vX.Y.Z` (use `persist-credentials: false`). Scan workflows with `zizmor` before committing. Configure Dependabot with 7-day cooldowns and grouped updates. Use `uv` ecosystem (not `pip`) for Python projects so Dependabot updates `uv.lock`.
