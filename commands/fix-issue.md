# Fix GitHub Issue

@description End-to-end: plan, implement, test, review, fix, push, and PR for a GitHub issue.
@arguments $ISSUE_NUMBER: GitHub issue number to fix

Read GitHub Issue #$ISSUE_NUMBER from the canonical repo
(`gh issue view $ISSUE_NUMBER --repo <owner/name>`) thoroughly.
Understand the full context: problem description, acceptance
criteria, linked PRs, and any discussion. Follow linked issues,
referenced PRs, and external documentation to build complete
understanding before planning.

Detect the upstream repository: if a git remote named `upstream`
exists, use it as the canonical repo (fetch from it, base branches
on it, and submit PRs to it). Otherwise, fall back to `origin`.
Resolve the canonical repo's `owner/name` (e.g. from `git remote
get-url upstream`) and store it — use `--repo <owner/name>` on
every `gh` command (issue views, PR creation, issue comments) to
ensure they target the correct repository. Run
`git fetch <upstream-remote>` to ensure you are working with
up-to-date code.

Execute every step below sequentially. Do not stop or ask for
confirmation at any step.

## 1. Research (if needed)

Before planning, determine if the issue requires external context
you don't already have — unfamiliar APIs, protocols, libraries,
error messages, or domain-specific concepts. If so, use Exa
(`mcp__exa__web_search_exa`) to search for:

- Official documentation for referenced libraries or APIs
- Known solutions for the error messages or symptoms described
- Implementation patterns used by similar projects

Skip this step for straightforward bugs where the fix is clear
from the codebase alone.

## 2. Plan

Write a detailed implementation plan to `plan-issue-$ISSUE_NUMBER.md`
in the repo root. The plan must:

- Summarize the issue requirements
- List every file to create or modify
- Describe the approach and key design decisions
- Call out risks or open questions
- Reference relevant code paths by file:line

## 3. Create branch

Create the working branch before writing any code so changes are
never left uncommitted on main.

- Determine the branch prefix from the issue type: `fix/` for
  bugs, `feat/` for features, `refactor/` for refactors, `docs/`
  for documentation. When ambiguous, use `fix/`.
- Create a branch named `{prefix}issue-$ISSUE_NUMBER` based on
  the upstream remote's main branch (e.g. `upstream/main` if the
  `upstream` remote exists, otherwise `origin/main`)

## 4. Implement

Implement the plan across all necessary files. Follow the
project's CLAUDE.md standards. Keep changes minimal and focused
on the issue requirements — no speculative features.

Add tests for the changed behavior as part of implementation —
tests are code, not a quality gate.

When stuck during implementation — a confusing error, an
unfamiliar API, or an approach that isn't working — use Exa
to search for solutions rather than spinning.

## 5. Build, test, lint

### 5a. Discover project checks (CI is the source of truth)

Before running anything, read the project's CI configuration to
learn what the project *actually* runs. This takes priority over
the fallback tables below.

1. **Read CI workflows.** Scan `.github/workflows/` for the main
   CI workflow (typically `ci.yml`, `test.yml`, or `build.yml`).
   Extract:
   - Test commands with feature flags (e.g.
     `cargo test --features foo,bar`)
   - Lint/format commands with non-default flags
   - Any step that runs a command then checks `git diff --exit-code`
     — these are **codegen sync checks** (schema generation,
     snapshot updates, help text, etc.). Record the command.
   - Docs/site build commands (e.g. `make site`, `mkdocs build`)
2. **Read the Makefile** (if present). Cross-reference targets
   used in CI — these are the ones that matter.
3. **Read CLAUDE.md** (if present at repo root or `.claude/`).
   It may define project-specific quality gates.

Store the discovered commands. They override the fallback table
for any overlapping step.

### 5b. Run the quality pipeline

Detect the project language from manifest files (`Cargo.toml` →
Rust, `pyproject.toml`/`setup.py` → Python, `package.json` →
Node/TypeScript, `go.mod` → Go). A project may use multiple
languages; run checks for each.

Run checks in this order. For each step, use the CI-discovered
command if one was found; otherwise fall back to the default.

1. **Build** — compile or bundle
2. **Test** — run the full test suite with the same feature flags
   CI uses. Iterate on failures until green.
3. **Lint and format** — fix any issues
4. **Extended checks** — per-language extras (see fallback table)
5. **Codegen sync** — for every codegen check discovered in 5a,
   run the command and verify `git diff --exit-code`. If the diff
   is non-empty, the generated files are stale — regenerate and
   stage them.
6. **Docs build** — if the changes touch documentation files and a
   docs build command exists, run it to verify the docs compile.

### Fallback defaults (when CI config is absent or unclear)

**Rust** (detected by `Cargo.toml`):

| step         | command                                        |
|--------------|------------------------------------------------|
| build        | `cargo build`                                  |
| test         | `cargo test`                                   |
| lint         | `cargo clippy -- --deny warnings`              |
| format       | `cargo fmt --check`                            |
| supply chain | `cargo deny check` (if `deny.toml` exists)    |
| careful      | `cargo careful test` (if `cargo-careful` installed) |

**Python** (detected by `pyproject.toml` or `setup.py`):

| step         | command                                        |
|--------------|------------------------------------------------|
| test         | `pytest -q`                                    |
| lint         | `ruff check`                                   |
| format       | `ruff format --check`                          |
| types        | `ty check` (or `mypy` if configured)           |
| supply chain | `pip-audit`                                    |

**Node/TypeScript** (detected by `package.json`):

| step         | command                                        |
|--------------|------------------------------------------------|
| build        | per project (`npm run build`, `tsc`, etc.)     |
| test         | `vitest` (or project test script)              |
| lint         | `oxlint` (or project lint script)              |
| format       | `oxfmt --check` (or project format script)     |
| types        | `tsc --noEmit`                                 |
| supply chain | `pnpm audit --audit-level=moderate`            |

**Go** (detected by `go.mod`):

| step         | command                                        |
|--------------|------------------------------------------------|
| build        | `go build ./...`                               |
| test         | `go test ./...`                                |
| lint         | `golangci-lint run`                            |
| format       | `gofmt -l .`                                   |
| vet          | `go vet ./...`                                 |

If a tool is not installed, skip it with a note rather than
failing the pipeline.

## 6. Self-review

For docs-only changes, do a focused manual review (verify links,
check prose accuracy, confirm rendering). For code changes, use
`/pr-review-toolkit:review-pr` to run a deep review against the
diff (compare working tree to the upstream main branch). Produce a
list of findings ranked by severity (P1 = blocks merge,
P2 = important, P3 = nice to have).

## 7. Fix findings

Address all P1–P3 findings. For each finding, either:

- **Fix it** — apply the change, or
- **Dismiss it** — explain why it's a false positive or not worth
  the churn (e.g. a stylistic disagreement or an impossible edge
  case). Document the reasoning inline.

After addressing all findings, review your own fixes: read the
diff of changes made in this step and verify each fix is correct,
doesn't introduce new issues, and doesn't regress other parts of
the implementation. If you spot a problem, fix it before
proceeding.

Then re-run the full quality pipeline (build, test, lint). Iterate
until clean.

## 8. Commit and push

- Delete the plan file (`plan-issue-$ISSUE_NUMBER.md`) — it was a
  working artifact and should not be committed
- Commit all changes with a conventional commit message referencing
  the issue
- Push the branch

## 9. Create PR

Create a PR with:

- A concise title (under 70 chars)
- A description that maps changes back to the issue requirements
- Link to the issue with "Closes #$ISSUE_NUMBER" (or "Refs" if it
  doesn't fully close it)
- If an `upstream` remote exists, submit the PR to the upstream
  repo using `gh pr create --repo <upstream-owner/repo>`

## 10. Comment on issue

Post a summary comment on Issue #$ISSUE_NUMBER in the canonical
repo (`gh issue comment $ISSUE_NUMBER --repo <owner/name>`)
linking to the PR. Include:

- What was implemented (1–3 bullet points)
- Key design decisions
- Link to the PR
