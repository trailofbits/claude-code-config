#!/bin/bash
# Two-line statusline with context window and session time
#
# Line 1: Repo/code context (cool blues)
# Line 2: Session/context info (warm tones)

# Read stdin (Claude Code passes JSON data via stdin)
stdin_data=$(cat)

# Single jq call - extract all values at once
IFS=$'\t' read -r current_dir model_name cost lines_added lines_removed duration_ms ctx_remaining cache_pct < <(
    echo "$stdin_data" | jq -r '[
        .workspace.current_dir // "unknown",
        .model.display_name // "Unknown",
        (try (.cost.total_cost_usd // 0 | . * 100 | floor / 100) catch 0),
        (.cost.total_lines_added // 0),
        (.cost.total_lines_removed // 0),
        (.cost.total_duration_ms // 0),
        (try (
            if (.context_window.context_window_size // 0) > 0 then
                100 - (((.context_window.current_usage.input_tokens // 0) +
                        (.context_window.current_usage.cache_creation_input_tokens // 0) +
                        (.context_window.current_usage.cache_read_input_tokens // 0)) * 100 /
                       .context_window.context_window_size) | floor
            else "null" end
        ) catch "null"),
        (try (
            (.context_window.current_usage // {}) |
            if (.input_tokens // 0) + (.cache_read_input_tokens // 0) > 0 then
                ((.cache_read_input_tokens // 0) * 100 /
                 ((.input_tokens // 0) + (.cache_read_input_tokens // 0))) | floor
            else 0 end
        ) catch 0)
    ] | @tsv'
)

# Bash-level fallback: if jq crashed entirely, extract critical fields individually
if [ -z "$current_dir" ] && [ -z "$model_name" ]; then
    current_dir=$(echo "$stdin_data" | jq -r '.workspace.current_dir // .cwd // "unknown"' 2>/dev/null)
    model_name=$(echo "$stdin_data" | jq -r '.model.display_name // "Unknown"' 2>/dev/null)
    cost=$(echo "$stdin_data" | jq -r '(.cost.total_cost_usd // 0)' 2>/dev/null)
    lines_added=$(echo "$stdin_data" | jq -r '(.cost.total_lines_added // 0)' 2>/dev/null)
    lines_removed=$(echo "$stdin_data" | jq -r '(.cost.total_lines_removed // 0)' 2>/dev/null)
    duration_ms=$(echo "$stdin_data" | jq -r '(.cost.total_duration_ms // 0)' 2>/dev/null)
    ctx_remaining=""
    cache_pct="0"
    : "${current_dir:=unknown}"
    : "${model_name:=Unknown}"
    : "${cost:=0}"
    : "${lines_added:=0}"
    : "${lines_removed:=0}"
    : "${duration_ms:=0}"
fi

# Git info
if cd "$current_dir" 2>/dev/null; then
    git_branch=$(git -c core.useBuiltinFSMonitor=false branch --show-current 2>/dev/null)
    git_root=$(git -c core.useBuiltinFSMonitor=false rev-parse --show-toplevel 2>/dev/null)
fi

# Build repo path display
if [ -n "$git_root" ]; then
    repo_name=$(basename "$git_root")
    if [ "$current_dir" = "$git_root" ]; then
        repo_path_display="$repo_name"
    else
        repo_path_display="$repo_name/${current_dir#$git_root/}"
    fi
else
    repo_path_display=$(basename "$current_dir")
fi

# Context color coding
if [ -n "$ctx_remaining" ] && [ "$ctx_remaining" != "null" ]; then
    if [ "$ctx_remaining" -gt 50 ]; then
        ctx_color='\033[92m'  # Green
    elif [ "$ctx_remaining" -gt 20 ]; then
        ctx_color='\033[93m'  # Yellow
    else
        ctx_color='\033[91m'  # Red
    fi
    ctx="${ctx_remaining}%"
else
    ctx=""
    ctx_color=""
fi

# Session time (human-readable)
if [ "$duration_ms" -gt 0 ] 2>/dev/null; then
    total_sec=$((duration_ms / 1000))
    hours=$((total_sec / 3600))
    minutes=$(((total_sec % 3600) / 60))
    seconds=$((total_sec % 60))
    if [ "$hours" -gt 0 ]; then
        session_time="${hours}h ${minutes}m"
    elif [ "$minutes" -gt 0 ]; then
        session_time="${minutes}m ${seconds}s"
    else
        session_time="${seconds}s"
    fi
else
    session_time=""
fi

# Separator
SEP='\033[2m│\033[0m'

# LINE 1: Repo/Code (cool blues)
line1=$(printf '\033[94m%s\033[0m' "$repo_path_display")
if [ -n "$git_branch" ]; then
    line1="$line1 $(printf '%b \033[96m%s\033[0m' "$SEP" "$git_branch")"
fi
if [ "$lines_added" != "0" ] || [ "$lines_removed" != "0" ]; then
    line1="$line1 $(printf '%b \033[92m+%s\033[0m \033[91m-%s\033[0m' "$SEP" "$lines_added" "$lines_removed")"
fi

# LINE 2: Session/Context (warm tones)
line2=$(printf '\033[37m%s\033[0m' "$model_name")
line2="$line2 $(printf '%b \033[33m$%s\033[0m' "$SEP" "$cost")"
if [ -n "$session_time" ]; then
    line2="$line2 $(printf '%b \033[33m%s\033[0m' "$SEP" "$session_time")"
fi
if [ -n "$ctx" ]; then
    line2="$line2 $(printf '%b %b%s\033[0m' "$SEP" "$ctx_color" "$ctx")"
    # Cache hit indicator (cyan) - only show if caching is active
    if [ "$cache_pct" -gt 0 ] 2>/dev/null; then
        line2="$line2 $(printf '\033[36m↻%s%%\033[0m' "$cache_pct")"
    fi
fi

printf '%b\n\n%b' "$line1" "$line2"
