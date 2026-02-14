# Merge Dependabot PRs

@description Evaluate and merge dependabot PRs with parallel builds, dependency-aware batching, and transitive dep analysis.
@arguments $REPO: GitHub org/repo (e.g., trailofbits/algo). $OPTIONS: Optional flags — "--skip-config-audit" skips Phase 0 (use in batch runs where config audit is a separate pass).

Clone $REPO if not already available locally:

```bash
gh repo clone $REPO /tmp/depbot-eval-$(echo "$REPO" | tr '/' '-') -- --depth=50 2>/dev/null || \
  (cd /tmp/depbot-eval-$(echo "$REPO" | tr '/' '-') && git fetch origin)
```

Work from `/tmp/depbot-eval-{repo-slug}` for all subsequent phases.

Execute every phase below sequentially. Do not stop or ask for
confirmation at any phase.

## Turn Budget Management

If you are running as a background agent with a `max_turns` cap:

- **At 75% of turns used:** Stop launching new evaluations. Merge
  any PRs already evaluated as PASS. Skip Phase 5's detailed
  reports — print only the summary table.
- **At 90% of turns used:** Immediately print whatever summary you
  have and stop. Do not start new evaluations or re-tests.
- **Prioritize merging over analysis.** If you must choose between
  thorough analysis of the last PR and merging already-evaluated
  PASS PRs, merge first.

## Phase 0: Dependabot Config Audit

If `$OPTIONS` includes `--skip-config-audit`, skip this entire
phase and proceed to Phase 1.

Detect all package ecosystems present in the repo by checking for
these indicator files:

| Indicator file(s) | Ecosystem |
|---|---|
| `pyproject.toml` + `uv.lock` | `uv` |
| `pyproject.toml` (no `uv.lock`), `requirements*.txt`, `setup.py`, `setup.cfg` | `pip` |
| `Cargo.toml` | `cargo` |
| `package.json` | `npm` |
| `go.mod` | `gomod` |
| `Gemfile` | `bundler` |
| `Dockerfile`, `docker-compose.yml` | `docker` |
| `.github/workflows/*.yml` | `github-actions` |
| `composer.json` | `composer` |
| `*.csproj`, `*.fsproj` | `nuget` |

Read `.github/dependabot.yml`. Verify all five conditions:

1. **Coverage** — every detected ecosystem has a corresponding
   `updates` entry with the correct `package-ecosystem` value and
   appropriate `directory` (usually `"/"`)
2. **uv vs pip** — if a directory has both `pyproject.toml` and
   `uv.lock`, the ecosystem MUST be `uv`, not `pip`. The `pip`
   ecosystem does not update `uv.lock`, which causes PRs that
   modify `pyproject.toml` but leave `uv.lock` out of sync.
   If any entry uses `pip` where `uv` is correct, flag it for
   correction.
3. **Schedule** — every entry has `schedule.interval: "weekly"`
4. **Cooldown** — every entry has a `cooldown` block with
   `default-days: 7`. This prevents dependabot from flooding the
   PR queue with rapid re-attempts after a PR is closed or merged.
5. **Grouped updates** — every entry has a `groups` key with at
   least one group using `patterns: ["*"]` or more specific
   grouping patterns

If the file is missing or any condition fails, create a corrective
PR:

1. `git checkout -b fix/dependabot-config`
2. Write or update `.github/dependabot.yml`. Every `updates` entry
   MUST include all four required blocks. Use this template for each
   ecosystem entry:

   ```yaml
   - package-ecosystem: "{ecosystem}"
     directory: "/"
     schedule:
       interval: "weekly"
     cooldown:
       default-days: 7
     groups:
       {ecosystem}-dependencies:
         patterns:
           - "*"
   ```

   When updating an existing file, preserve any extra fields already
   present (labels, reviewers, open-pull-requests-limit, etc.) and
   only add missing blocks.

3. `git commit -m "chore: update dependabot config for full coverage, weekly schedule, 7-day cooldown, and grouped updates"`
4. `git push origin fix/dependabot-config`
5. `gh pr create --repo $REPO --title "Update dependabot configuration" --body "Adds missing ecosystem coverage, enforces weekly schedule, 7-day cooldown, and grouped updates."`
6. `git checkout main`

Continue to Phase 1 regardless — this PR is non-blocking.

## Phase 1: Discovery & Baseline

### 1a. Fetch dependabot PRs

```bash
gh pr list --repo $REPO --author "app/dependabot" --state open \
  --json number,title,headRefName,labels,files,mergeable
```

If zero PRs are returned, print "No open dependabot PRs for $REPO"
and stop.

### 1b. Categorize PRs

For each PR, examine its changed files:

- **Actions dep** — all changed files are under `.github/workflows/`
  or `.github/actions/`
- **Library dep** — everything else (lockfiles, manifests, version
  pins, dependency specification files)

Store the categorized list for later phases.

### 1c. Baseline build and test

Verify the main branch is healthy before evaluating any PR.

1. Check out the default branch: use whatever
   `gh repo view --repo $REPO --json defaultBranchRef` reports
2. Discover the build system — follow the same discovery process
   described in Phase 3's subagent instructions (read CI workflows
   first, then Makefile, then language-specific defaults)
3. Run the build command. If it fails, **stop the entire command**
   and report: "Main branch build is broken. Fix main before
   processing dependabot PRs." Include the error output.
4. Run the test command. If tests fail, **stop the entire command**
   and report: "Main branch tests are failing. Fix main before
   processing dependabot PRs." Include which tests fail.
5. Record the baseline:
   - Full dependency tree from lockfile(s) (`pip freeze`,
     `cargo tree`, `npm ls --all`, `go list -m all`, etc.)
   - List of passing tests
   - Build output summary

Store the baseline data — subagents need it for comparison.

## Phase 2: Dependency Graph Analysis

### 2a. Build the transitive dependency map

Parse the repo's lockfile(s) to understand the full dependency
tree:

| Ecosystem | Lockfile | Tree command |
|---|---|---|
| uv | `uv.lock` | `uv pip freeze` (after `uv sync`) |
| pip | `poetry.lock`, `requirements*.txt` | `pip freeze` |
| cargo | `Cargo.lock` | `cargo tree` |
| npm | `package-lock.json`, `pnpm-lock.yaml` | `npm ls --all` or `pnpm ls --depth=Infinity` |
| gomod | `go.sum` | `go list -m all` |
| bundler | `Gemfile.lock` | `bundle list` |

For each library dep PR, identify which direct dependency it bumps
(from the PR title and changed files). Look up that package in the
dependency tree to find all its transitive dependents and
dependencies.

### 2b. Group overlapping PRs into batches

Two PRs overlap if:
- PR A bumps package X, PR B bumps package Y, and X depends on Y
  (or Y depends on X) in the transitive tree
- Both PRs modify the same lockfile section for shared transitive
  dependencies

Group overlapping PRs into **batches**. PRs with no overlaps
remain **independent** work units.

Actions dep PRs are always independent work units — they don't
interact with library dependency trees.

### 2c. Sort and queue

Sort work units in topological order — leaf dependencies first,
core/shared dependencies last. This ensures earlier merges are
less likely to affect later ones.

If there are more than 5 work units total, process in **waves
of 5**. The first wave starts immediately; subsequent waves start
after the previous wave completes.

Print the grouping plan before proceeding:
- List each work unit (batch or independent)
- Show which PRs are in each batch and why they were grouped
- Show the evaluation order

## Phase 3: Parallel Evaluation

### 3a. Fetch PR branches

For each work unit, fetch the PR branch into the local repo:

```bash
git fetch origin pull/{number}/head:pr-{number}
```

Do NOT use `wt switch` — shallow clones do not support worktrees
reliably. Use `git checkout` directly when evaluating each PR.

### 3b. Launch subagents

Launch up to 5 subagents in parallel using the Task tool. Each
call must use:
- `subagent_type: "general-purpose"`
- The appropriate prompt below (library or actions)

Send all Task calls in a **single message** for parallel execution.
If more than 5 work units, wait for the current wave to complete
before launching the next.

Pass each subagent:
- The repo directory path
- The PR number(s) and title(s)
- The baseline dependency tree from Phase 1
- The repo's build and test commands discovered in Phase 1

### Subagent prompt: Library Dep Evaluation

Use this prompt for each library dep work unit.

---

You are evaluating dependabot PR(s) for merge safety. Work
in the repo directory: {repo_path}

**Repo:** $REPO
**PR(s) to evaluate:** {pr_numbers_and_titles}
**Baseline dependency tree from main:**

```
{baseline_dep_tree}
```

**Build command:** {build_command}
**Test command:** {test_command}

Execute every step. Do not skip steps. Do not ask for confirmation.

**STEP 1 — Checkout**

```bash
cd {repo_path}
git fetch origin pull/{number}/head:pr-{number}
git checkout pr-{number}
```

For batches (multiple PRs), create a temporary merge branch:

```bash
cd {repo_path}
git checkout -b test-batch-{batch_id} main
git fetch origin pull/{pr1}/head:pr-{pr1}
git fetch origin pull/{pr2}/head:pr-{pr2}
git merge pr-{pr1} pr-{pr2} --no-edit
```

If the merge has conflicts, report FAIL with the conflicting files
and stop.

**STEP 2 — Transitive dependency analysis**

Generate the full dependency tree using the same command that
produced the baseline. Compare against the baseline and report:

```
DIRECT CHANGES:
  - {package}: {old_version} → {new_version}

TRANSITIVE CHANGES:
  - {package}: {old_version} → {new_version}  (depended on by: {parent})

NEW TRANSITIVE DEPS:
  - {package} {version}  (pulled in by: {parent})

REMOVED TRANSITIVE DEPS:
  - {package} {version}

FLAGS:
  - DOWNGRADE: {package} went from {higher} to {lower}
  - MAJOR BUMP: {package} crossed a major version boundary
```

If there are zero flags and zero new/removed transitive deps,
note "Clean transitive dependency change."

**STEP 3 — Build**

Run the build command: {build_command}

If the build command was not provided (blank), discover it:

1. Read `.github/workflows/` for build steps
2. Check `Makefile` or `justfile` for a `build` target
3. Language-specific defaults:

| Manifest | Default |
|---|---|
| `Cargo.toml` | `cargo build` |
| `pyproject.toml` | `uv pip install -e ".[dev]"` |
| `package.json` | `pnpm install && pnpm build` |
| `go.mod` | `go build ./...` |
| `Gemfile` | `bundle install` |

If the build fails, report FAIL with exact error output and stop.

**STEP 4 — Test**

Run the test command: {test_command}

If the test command was not provided (blank), discover it using the
same approach as Step 3:

| Manifest | Default |
|---|---|
| `Cargo.toml` | `cargo test` |
| `pyproject.toml` | `pytest -q` |
| `package.json` | `pnpm test` |
| `go.mod` | `go test ./...` |
| `Gemfile` | `bundle exec rspec` or `bundle exec rake test` |

If tests fail, check whether the same tests also fail on the main
branch baseline. Pre-existing failures do not count against this PR.

If there are new test failures (pass on main, fail on this PR),
report FAIL with the failing test names and error output.

**STEP 5 — Build matrix gap analysis**

Read `.github/workflows/` for `strategy.matrix` blocks. For each
matrix dimension, report what was tested locally vs. what only
runs in CI:

| Dimension | Example values | Testable locally? |
|---|---|---|
| OS | ubuntu, macos, windows | Current OS only |
| Language version | python 3.9-3.12 | Installed version only |
| Dependency version | numpy 1.x, 2.x | PR's version only |

Report the matrix gaps and assess risk:
- **HIGH risk:** The dependency is known to have version-specific
  behavior (e.g., numpy/scipy ABI, pytorch CUDA builds, native
  extensions) and CI tests versions we couldn't test locally
- **LOW risk:** The matrix covers OS variants or formatting
  differences unlikely to be affected by a dependency bump

If there is no matrix strategy in CI, report "No CI matrix — single
configuration build."

**STEP 6 — Verdict**

**PASS** — all conditions met:
- Build succeeds
- All tests pass (or only pre-existing failures)
- No transitive dependency flags (downgrades, major bumps)
- No high-risk matrix gaps

**WARN** — build and tests pass, but concerns exist:
- New transitive dependencies introduced
- Transitive dep crossed a major version boundary
- High-risk matrix gaps
- List each specific concern

**FAIL** — any of:
- Build fails
- New test failures
- Merge conflicts

Format the final report:

```
## Evaluation Report: PR #{number} — {title}

**Verdict: {PASS|WARN|FAIL}**

### Transitive Dependency Analysis
{step 2 output}

### Build Result
{pass/fail with output if failed}

### Test Result
{pass/fail with details}

### Matrix Gap Analysis
{step 5 output}

### Concerns
{list of concerns, or "None"}
```

---

### Subagent prompt: Actions Dep Evaluation

Use this prompt for each GitHub Actions version bump PR.

---

You are evaluating a GitHub Actions version bump for merge safety.
Work in the repo directory: {repo_path}

**Repo:** $REPO
**PR to evaluate:** #{number} — {title}

Execute every step.

**STEP 1 — Checkout**

```bash
cd {repo_path}
git fetch origin pull/{number}/head:pr-{number}
git checkout pr-{number}
```

**STEP 2 — Diff analysis**

Run `git diff main -- .github/` to see what changed. Identify:
- Which action(s) were bumped
- Old and new versions (or SHA pins)
- Whether this is a patch, minor, or major version bump

For major version bumps, use Exa (`mcp__exa__web_search_exa`) to
search for breaking changes:
`{action_name} v{old_major} to v{new_major} migration breaking changes`

**STEP 3 — Workflow validation**

Run: `actionlint .github/workflows/`

If `actionlint` is not installed, note this and skip to Step 4.

Distinguish pre-existing errors (also present on main) from new
errors introduced by the version bump. Only new errors count
against this PR.

**STEP 4 — Pin verification**

Check every `uses:` line in changed workflow files. Verify the
SHA-pin format:

```yaml
# GOOD:
uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683  # v4.2.2

# BAD (tag only):
uses: actions/checkout@v4

# BAD (SHA without version comment):
uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683
```

Flag tag-only references as a WARN concern (not FAIL).

**STEP 5 — Verdict**

**PASS** — all conditions met:
- actionlint clean (or only pre-existing warnings)
- No breaking changes for major version bumps
- Actions are SHA-pinned with version comments

**WARN** — concerns exist:
- Tag pin instead of SHA pin
- Major version bump with breaking changes that appear handled

**FAIL** — any of:
- New actionlint errors
- Major version bump with unhandled breaking changes

Format the report the same way as library dep evaluations.

---

## Phase 4: Sequential Merge

Collect all subagent evaluation reports. Process work units in the
dependency order established in Phase 2.

### 4a. Merge passing PRs

For each work unit with a **PASS** verdict, in order:

1. Approve the PR:
   ```bash
   gh pr review --repo $REPO --approve {number} \
     --body "Automated evaluation: build, tests, and transitive dependency analysis passed."
   ```

2. Force merge as admin:
   ```bash
   gh pr merge --repo $REPO --squash --admin {number}
   ```

3. Verify the merge succeeded (gh pr merge produces no output on
   success):
   ```bash
   gh pr view --repo $REPO {number} --json state
   ```
   Confirm `state` is `"MERGED"`. If not, report the error and
   skip to the next work unit.

4. Update main locally:
   ```bash
   git checkout main && git pull origin main
   ```

5. **Re-test the next work unit** before merging it. Checkout its
   branch and rebase onto updated main:
   ```bash
   git checkout pr-{next_number}
   git merge main --no-edit
   ```
   Re-run the build and test commands. If the re-test fails, mark
   this work unit as **SKIPPED** with reason: "Passed independent
   evaluation but failed after merging prior PRs. Likely conflicts
   with: {previously merged PR numbers}." Continue to the next
   work unit.

For **batched** work units, merge each PR in the batch
sequentially using the same approve-then-merge flow.

### 4b. Handle WARN and FAIL verdicts

- **WARN** — do not merge. Include in final report with specific
  concerns. These need human review.
- **FAIL** — do not merge. Include full error context for diagnosis.

## Phase 5: Cleanup & Report

### 5a. Cleanup

Return to main and delete local PR branches:

```bash
git checkout main
git branch -D pr-{number} test-batch-{batch_id}  # for each evaluated PR/batch
```

### 5b. Summary report

Print a summary table:

```
## Dependabot PR Summary for $REPO

| PR | Title | Type | Verdict | Action | Notes |
|----|-------|------|---------|--------|-------|
```

Include every evaluated PR with its verdict and outcome.

Below the table, print totals:

```
**Merged:** {count}
**Skipped (WARN — needs human review):** {count}
**Failed:** {count}
**Skipped (post-merge conflict):** {count}
```

If a dependabot config PR was created in Phase 0:

```
**Dependabot config PR:** #{number}
```

### 5c. Detailed reports for non-merged PRs

For each WARN, FAIL, or SKIPPED PR, print the full evaluation
report from the subagent so the user has all context needed to
decide or fix the issue.
