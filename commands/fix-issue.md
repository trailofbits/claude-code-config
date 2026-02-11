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
