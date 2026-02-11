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
