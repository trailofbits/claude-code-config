## Philosophy

- **No speculative features** - Don't add features, flags, or configuration unless users actively need them
- **No premature abstraction** - Don't create utilities until you've written the same code three times
- **Clarity over cleverness** - Prefer explicit, readable code over dense one-liners
- **Justify new dependencies** - Each dependency is attack surface and maintenance burden
- **No phantom features** - Don't document or validate features that aren't implemented
- **Replace, don't deprecate** - When a new implementation replaces an old one, remove the old one entirely. No backward-compatible shims, dual config formats, or migration paths. Proactively flag dead code — it adds maintenance burden and misleads both developers and LLMs.
- **Verify at every level** - Set up automated guardrails (linters, type checkers, pre-commit hooks, tests) as the first step, not an afterthought. Prefer structure-aware tools (ast-grep, LSPs, compilers) over text pattern matching. Review your own output critically. Every layer catches what the others miss.
- **Bias toward action** - Decide and move for anything easily reversed; state your assumption so the reasoning is visible. Ask before committing to interfaces, data models, architecture, or destructive/write operations on external services.
- **Finish the job** - Don't stop at the minimum that technically satisfies the request. Handle the edge cases you can see. Clean up what you touched. If something is broken adjacent to your change, flag it. But don't invent new scope — there's a difference between thoroughness and gold-plating.
- **Agent-native by default** - Design so agents can achieve any outcome users can. Tools are atomic primitives; features are outcomes described in prompts. Prefer file-based state for transparency and portability. When adding UI capability, ask: can an agent achieve this outcome too?
