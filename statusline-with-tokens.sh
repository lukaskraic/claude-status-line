#!/bin/bash

# Read JSON input from stdin
input=$(cat)

# Extract session_id for per-window cache isolation
session_id=$(echo "$input" | jq -r '.session_id // "default"' 2>/dev/null)

# Cache file for last known token count (per session/window)
CACHE_FILE="$HOME/.claude/.token-cache-${session_id}"

# Extract basic info
cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // ""')
display_dir="${cwd/#$HOME/~}"
model=$(echo "$input" | jq -r '.model.display_name // ""')
transcript_path=$(echo "$input" | jq -r '.transcript_path // ""')

# Get git branch
git_branch=""
if cd "$cwd" 2>/dev/null && git rev-parse --git-dir > /dev/null 2>&1; then
    branch=$(git branch --show-current 2>/dev/null)
    if [[ -n "$branch" ]]; then
        git_branch=" ($branch)"
    fi
fi

# Get token metrics from input JSON or transcript
tokens_display=""
tokens=$(echo "$input" | jq -r '.context.usage.total // 0' 2>/dev/null)
budget=$(echo "$input" | jq -r '.context.budget.limit // 200000' 2>/dev/null)

# If tokens not in JSON, try parsing transcript file
if [[ "$tokens" == "0" || "$tokens" == "null" || -z "$tokens" ]]; then
    transcript=$(echo "$input" | jq -r '.transcript_path // ""' 2>/dev/null)

    if [[ -f "$transcript" ]]; then
        # Get last assistant message's token usage (best approximation of current total)
        # Formula: cache_read (cumulative context) + input (new prompt) + output (response)
        tokens=$(tail -1 "$transcript" | jq -r 'select(.message.usage != null) | .message.usage | ((.cache_read_input_tokens // 0) + (.input_tokens // 0) + (.output_tokens // 0))' 2>/dev/null)
    fi

    # If still no tokens, try to find most recent transcript file with actual data
    if [[ "$tokens" == "0" || "$tokens" == "null" || -z "$tokens" ]]; then
        # Get directory where transcripts are stored based on current cwd
        transcript_dir=$(dirname "$transcript" 2>/dev/null)

        # Try to find tokens in transcript_dir first (if exists)
        if [[ -d "$transcript_dir" ]]; then
            for latest_transcript in $(ls -t "$transcript_dir"/*.jsonl 2>/dev/null | grep -v 'agent-' | head -5); do
                if [[ -f "$latest_transcript" && -s "$latest_transcript" ]]; then
                    tokens=$(tail -1 "$latest_transcript" | jq -r 'select(.message.usage != null) | .message.usage | ((.cache_read_input_tokens // 0) + (.input_tokens // 0) + (.output_tokens // 0))' 2>/dev/null)

                    if [[ -n "$tokens" && "$tokens" != "0" && "$tokens" != "null" ]]; then
                        break
                    fi
                fi
            done
        fi

        # If still no tokens, load from cache file (fast, no file searching)
        if [[ "$tokens" == "0" || "$tokens" == "null" || -z "$tokens" ]]; then
            if [[ -f "$CACHE_FILE" ]]; then
                tokens=$(cat "$CACHE_FILE" 2>/dev/null)
            fi
        fi
    fi
fi

# Ensure tokens and budget are always valid numbers
tokens=${tokens:-0}
[[ "$tokens" == "null" || -z "$tokens" ]] && tokens=0

budget=${budget:-200000}
[[ "$budget" == "null" || -z "$budget" ]] && budget=200000

# Save tokens to cache if we have real data (not zero)
if [[ -n "$tokens" && "$tokens" != "0" && "$tokens" != "null" ]]; then
    echo "$tokens" > "$CACHE_FILE" 2>/dev/null
fi

# Always display tokens (even when 0)
if [[ -n "$tokens" ]]; then
    # Calculate percentage
    percentage=$(awk "BEGIN {printf \"%.0f\", ($tokens / $budget) * 100}")

    # Format in K
    tokens_k=$(($tokens / 1000))
    budget_k=$(($budget / 1000))

    # Status indicator based on percentage
    if [[ $percentage -lt 50 ]]; then
        status="✓"
    elif [[ $percentage -lt 80 ]]; then
        status="⚠"
    else
        status="⚠⚠"
    fi

    tokens_display=" ${status} ${tokens_k}k/${budget_k}k (${percentage}%)"
fi

# Output formatted status line (no ANSI colors - not supported by Claude Code)
printf "%s%s [%s]%s" "$display_dir" "$git_branch" "$model" "$tokens_display"
