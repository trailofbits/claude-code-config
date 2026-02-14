# Review and Fix PR

@description Review an existing PR with parallel agents, fix findings, and push.
@arguments $PR_NUMBER: GitHub PR number to review and fix

Read PR #$PR_NUMBER thoroughly using `gh pr view`. Understand the
full context: description, linked issues, commit history, and the
diff against the base branch.

Detect the upstream repository: if a git remote named `upstream`
exists, use it as the canonical repo. Otherwise, fall back to
`origin`. Resolve the canonical repo's `owner/name` (e.g. from
`git remote get-url upstream`) and store it — use
`--repo <owner/name>` on every `gh` command to ensure they target
the correct repository. Run `git fetch <upstream-remote>` to
ensure you are working with up-to-date code.

Check out the PR branch locally.

Execute every step below sequentially. Do not stop or ask for
confirmation at any step.

## 1. Review

Run two review passes in parallel, then merge findings.

### Pass A — pr-review-toolkit agents

Launch these Task tool agents **in parallel** (single message,
multiple tool calls), each with `subagent_type` from the
pr-review-toolkit plugin. Tell each agent which files changed
(from `git diff --name-only <base>...HEAD`):

| agent | focus |
|-------|-------|
| `pr-review-toolkit:code-reviewer` | Code quality, style, project guidelines |
| `pr-review-toolkit:silent-failure-hunter` | Silent failures, swallowed errors, bad fallbacks |
| `pr-review-toolkit:pr-test-analyzer` | Test coverage gaps and missing edge cases |

### Pass B — external second opinion

Launch these Task tool agents **in parallel with Pass A** — all
5 agents in a single message, multiple tool calls. Each uses
`subagent_type: general-purpose`.

**Codex reviewer** — tell the agent to run:

```bash
codex review --base <upstream-remote>/<base-branch> \
  -c model='"gpt-5.3-codex"' \
  -c model_reasoning_effort='"xhigh"'
```

- `--base` does not accept custom prompts (codex reads
  `AGENTS.md` at the repo root if one exists)
- If `gpt-5.3-codex` fails with an auth error, retry with
  `gpt-5.2-codex`
- Set `timeout: 600000` on the Bash call
- Tell the agent to summarize findings only — skip
  `[thinking]`/`[exec]` blocks and sandbox warnings
- If `codex` is not installed, report and skip

**Gemini reviewer** — tell the agent to run:

```bash
git diff <upstream-remote>/<base-branch>...HEAD > /tmp/pr-review-diff.txt

# Build prompt file (avoids heredoc shell expansion issues)
{
  echo "Review this diff for code quality, bugs, and improvements."
  if [ -f CLAUDE.md ] || [ -f .claude/CLAUDE.md ]; then
    echo ""
    echo "Project conventions:"
    echo "---"
    cat CLAUDE.md .claude/CLAUDE.md 2>/dev/null
    echo "---"
  fi
  echo ""
  echo "Diff:"
  cat /tmp/pr-review-diff.txt
} > /tmp/pr-review-prompt.txt

# Pipe prompt via stdin to avoid shell metacharacter issues
cat /tmp/pr-review-prompt.txt | gemini -p - \
  -m gemini-3-pro-preview \
  --yolo
```

- Uses stdin (`-p -`) instead of heredoc to avoid shell
  expansion issues with `$`, backticks, etc. in diffs
- Set `timeout: 600000` on the Bash call
- If `gemini` is not installed, report and skip

### Merge findings

Collect results from all 5 sources (3 toolkit agents + Codex +
Gemini). Deduplicate overlapping findings — if multiple sources
flag the same issue, keep the most specific description and note
the consensus. Rank every finding by severity:

- **P1** — blocks merge (correctness bugs, security issues)
- **P2** — important (missing error handling, test gaps, logic flaws)
- **P3** — nice to have (style, naming, minor simplifications)
- **P4** — informational (observations, suggestions for future work)

## 2. Fix findings

Address all P1–P3 findings. For each finding, either:

- **Fix it** — apply the change, or
- **Dismiss it** — explain why it's a false positive or not worth
  the churn (e.g. a stylistic disagreement or an impossible edge
  case). Document the reasoning inline.

When a fix requires external context — unfamiliar library behavior,
unclear API semantics, or an error you don't recognize — use Exa
(`mcp__exa__web_search_exa`) to search for solutions rather than
guessing.

P4 findings are informational — note them but do not fix unless
trivial.

After addressing all findings, review your own fixes: read the
diff of changes made in this step and verify each fix is correct,
doesn't introduce new issues, and doesn't regress other parts of
the PR. If you spot a problem, fix it before proceeding.

## 3. Verify

### 3a. Discover project checks (CI is the source of truth)

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

### 3b. Run the quality pipeline

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
5. **Codegen sync** — for every codegen check discovered in 3a,
   run the command and verify `git diff --exit-code`. If the diff
   is non-empty, the generated files are stale — regenerate and
   stage them.
6. **Docs build** — if the PR changes documentation files and a
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

## 4. Commit and push

- Commit the fixes as a separate commit (do not squash into the
  original — preserve review history)
- Write a detailed commit message that covers:
  - Subject: `fix: resolve code review findings for PR #$PR_NUMBER`
  - Body: list findings by severity, what was fixed vs dismissed
    (with brief reasoning), and confirmation that the quality
    pipeline passes
- Push the branch (regular push, not force-push)
- Delete any todo files in `todos/` that were created by the
  review and are now resolved

## 5. PR comment

Post a review summary as a PR comment using
`gh pr comment $PR_NUMBER --repo <owner/name>`.

Format the comment body as:

```
## Review Summary

### Findings

[For each severity level that has findings, list them as a table:]

| # | Severity | Finding | Resolution |
|---|----------|---------|------------|
| 1 | P1 | [description] | Fixed: [what was done] |
| 2 | P2 | [description] | Dismissed: [reasoning] |
| ... | ... | ... | ... |

### Verification

- **Tests**: [pass/fail count]
- **Lint**: [clean/issues]
- **Format**: [clean/issues]

### Commit

[commit SHA and subject line]
```
