#!/bin/bash

# CONFIGURATION: System overhead estimation (in tokens)
# Claude Code includes system components not tracked in transcript:
#   - System prompt: ~2.8k
#   - System tools: ~17.3k
#   - MCP tools: 1.8k (minimal) to 79.5k (all servers enabled)
#   - Custom agents: ~443
#   - Memory files: ~3.3k
#
# Auto-detection (default):
#   Reads MCP configuration from multiple locations (fallback order):
#   1. ~/.claude.json (Claude Code CLI config - most common)
#   2. ~/.claude/settings.json (project-specific)
#   3. ~/Library/Application Support/Claude/claude_desktop_config.json (Claude Desktop)
#   Estimates overhead: 24k-104k based on MCP count
#
# Manual override (optional):
#   Uncomment and set SYSTEM_OVERHEAD_MANUAL to override auto-detection
#   Example: SYSTEM_OVERHEAD_MANUAL=35000
#
# SYSTEM_OVERHEAD_MANUAL=

# Autocompact buffer - Claude Code 2.0+ ALWAYS reserves 45k tokens (22.5%)
# This is a constant that persists across sessions and even after /clear
# The buffer is NOT included in transcript cache metrics, so we must add it
# Reference: https://github.com/anthropics/claude-code/issues/10266
AUTOCOMPACT_BUFFER=45000

# Function to detect system overhead based on MCP server count
detect_mcp_servers() {
    # Try multiple configuration locations (fallback order)
    local claude_json="$HOME/.claude.json"
    local settings_file="$HOME/.claude/settings.json"
    local desktop_config="$HOME/Library/Application Support/Claude/claude_desktop_config.json"
    local mcp_count=""

    # Try reading from ~/.claude.json first (Claude Code CLI config)
    if [[ -f "$claude_json" ]]; then
        mcp_count=$(jq '
            .mcpServers // {} |
            to_entries |
            map(select(.value.disabled != true)) |
            length
        ' "$claude_json" 2>/dev/null)
    fi

    # If no MCP servers found, try ~/.claude/settings.json
    if [[ -z "$mcp_count" || "$mcp_count" == "null" || "$mcp_count" == "0" ]] && [[ -f "$settings_file" ]]; then
        mcp_count=$(jq '
            .mcpServers // {} |
            to_entries |
            map(select(.value.disabled != true)) |
            length
        ' "$settings_file" 2>/dev/null)
    fi

    # If still no MCP servers found, try Claude Desktop config
    if [[ -z "$mcp_count" || "$mcp_count" == "null" || "$mcp_count" == "0" ]] && [[ -f "$desktop_config" ]]; then
        mcp_count=$(jq '
            .mcpServers // {} |
            to_entries |
            map(select(.value.disabled != true)) |
            length
        ' "$desktop_config" 2>/dev/null)
    fi

    # Final fallback if all failed
    if [[ -z "$mcp_count" || "$mcp_count" == "null" ]]; then
        echo "25000"
        return
    fi

    # Calculate overhead based on MCP server count
    local base=24000
    case "$mcp_count" in
        0) echo "$base" ;;
        1|2) echo "$((base + 10000))" ;;  # 34k
        3|4) echo "$((base + 30000))" ;;  # 54k
        5|6) echo "$((base + 50000))" ;;  # 74k
        *) echo "$((base + 80000))" ;;    # 104k
    esac
}

# Auto-detect overhead or use manual override
if [[ -z "$SYSTEM_OVERHEAD_MANUAL" ]]; then
    SYSTEM_OVERHEAD=$(detect_mcp_servers)
else
    SYSTEM_OVERHEAD=$SYSTEM_OVERHEAD_MANUAL
fi

# Read JSON input from stdin
input=$(cat)

# DEBUG: Save input to file for inspection (temporary)
echo "$input" > "$HOME/.claude/statusline-debug.json" 2>/dev/null

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
        # Get token usage from transcript
        # Formula: cache_read + cache_creation + autocompact_buffer
        # - cache_read = cached context from previous API calls
        # - cache_creation = new content being cached this turn
        # - autocompact_buffer = Claude Code 2.0+ constant 45k reservation
        tokens=$(tail -1 "$transcript" | jq -r 'select(.message.usage != null) | .message.usage | ((.cache_read_input_tokens // 0) + (.cache_creation_input_tokens // 0))' 2>/dev/null)

        # Add autocompact buffer to match /context output
        if [[ -n "$tokens" && "$tokens" != "0" && "$tokens" != "null" ]]; then
            tokens=$((tokens + AUTOCOMPACT_BUFFER))
        fi
    fi

    # If still no tokens, try to find most recent transcript file with actual data
    if [[ "$tokens" == "0" || "$tokens" == "null" || -z "$tokens" ]]; then
        # Get directory where transcripts are stored based on current cwd
        transcript_dir=$(dirname "$transcript" 2>/dev/null)

        # Try to find tokens in transcript_dir first (if exists)
        if [[ -d "$transcript_dir" ]]; then
            for latest_transcript in $(ls -t "$transcript_dir"/*.jsonl 2>/dev/null | grep -v 'agent-' | head -5); do
                if [[ -f "$latest_transcript" && -s "$latest_transcript" ]]; then
                    tokens=$(tail -1 "$latest_transcript" | jq -r 'select(.message.usage != null) | .message.usage | ((.cache_read_input_tokens // 0) + (.cache_creation_input_tokens // 0))' 2>/dev/null)

                    if [[ -n "$tokens" && "$tokens" != "0" && "$tokens" != "null" ]]; then
                        # Add autocompact buffer
                        tokens=$((tokens + AUTOCOMPACT_BUFFER))
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

# If we still have 0 tokens (e.g., after /clear), use system overhead + autocompact buffer
# This matches /context behavior: system components + autocompact buffer (45k)
if [[ "$tokens" == "0" ]]; then
    tokens=$((SYSTEM_OVERHEAD + AUTOCOMPACT_BUFFER))
fi

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

    # Status indicator based on percentage (aligned with auto-compact ~92%)
    if [[ $percentage -lt 75 ]]; then
        status="✓"
    elif [[ $percentage -lt 90 ]]; then
        status="⚠"
    else
        status="⚠⚠"
    fi

    tokens_display=" ${status} ${tokens_k}k/${budget_k}k (${percentage}%)"
fi

# Output formatted status line (no ANSI colors - not supported by Claude Code)
printf "%s%s [%s]%s" "$display_dir" "$git_branch" "$model" "$tokens_display"
