#!/bin/bash
set -euo pipefail
# EXAMPLE: PreToolUse hook — blocks npm in projects that use pnpm.
# Adapt for any "use X not Y" convention (e.g., yarn vs npm, uv vs pip).
CMD=$(jq -r '.tool_input.command // empty')
[[ -z "$CMD" ]] && exit 0

# Only enforce if this project uses pnpm
[[ ! -f "${CLAUDE_PROJECT_DIR}/pnpm-lock.yaml" ]] && exit 0

if echo "$CMD" | grep -qE '^npm\s'; then
  echo "BLOCKED: This project uses pnpm, not npm. Use pnpm instead." >&2
  exit 2
fi
exit 0
