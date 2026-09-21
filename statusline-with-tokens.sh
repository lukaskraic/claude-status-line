#!/bin/bash
#
# Claude Code status line - context usage measured against the auto-compact window.
#
# Claude Code reserves a fixed slice of every context window for the auto-compact
# summary. Auto-compact fires when usage reaches (context_window_size - buffer),
# so that difference - not the raw window - is the budget worth displaying.
#
# Measured on Claude Code 2.1.278: `/context` reports "Autocompact buffer | 33k"
# for a 200k window and for a 1M window alike (fixed, not proportional), and its
# headline "Tokens: X / window" excludes the buffer from X.
#
# The status line JSON reports usage against the *full* window, so the buffer has
# to be subtracted from the denominator here.
#
# Buffer resolution order:
#   1. AUTOCOMPACT_BUFFER_MANUAL (set below)
#   2. CLAUDE_CODE_AUTO_COMPACT_WINDOW env var  - an explicit effective window
#   3. autoCompactWindow in ~/.claude/settings.json (same meaning, accepts 500k/1m)
#   4. autoCompactEnabled:false in ~/.claude/settings.json - no buffer at all
#   5. AUTOCOMPACT_BUFFER below
#
# AUTOCOMPACT_BUFFER_MANUAL=

AUTOCOMPACT_BUFFER=33000

# Warn about account rate limits once either window crosses this percentage.
RATE_LIMIT_WARN_PCT=80

input=$(cat)

# One jq pass over the payload. context_window is present since Claude Code 2.1.6;
# total_input_tokens is exact, used_percentage is rounded to whole percent and is
# only a fallback.
IFS=$'\037' read -r cwd model window exact_tokens usage_tokens used_pct five_h seven_d <<<"$(
    jq -r '[
        (.workspace.current_dir // .cwd // ""),
        (.model.display_name // "?"),
        (.context_window.context_window_size // 0),
        (.context_window.total_input_tokens // 0),
        (.context_window.current_usage // {} |
            ((.input_tokens // 0)
             + (.cache_creation_input_tokens // 0)
             + (.cache_read_input_tokens // 0))),
        (.context_window.used_percentage // -1),
        (.rate_limits.five_hour.used_percentage // -1),
        (.rate_limits.seven_day.used_percentage // -1)
    ] | join("\u001f")' <<<"$input" 2>/dev/null
)"

# jq failed outright (no stdin, malformed JSON) - fall back to something printable.
model=${model:-?}

display_dir="${cwd/#$HOME/~}"

git_branch=""
if [[ -d "$cwd" ]] && branch=$(git -C "$cwd" branch --show-current 2>/dev/null) && [[ -n "$branch" ]]; then
    git_branch=" ($branch)"
fi

# Accept 500000, 500k or 1m for the configured auto-compact window.
# Lowercased with tr because macOS ships bash 3.2, which has no ${var,,}.
parse_window() {
    local raw
    raw=$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')
    case "$raw" in
        *k) awk "BEGIN{printf \"%.0f\", ${raw%k} * 1000}" ;;
        *m) awk "BEGIN{printf \"%.0f\", ${raw%m} * 1000000}" ;;
        *[!0-9]*|"") echo "" ;;
        *) echo "$raw" ;;
    esac
}

resolve_buffer() {
    local full=$1

    if [[ -n "$AUTOCOMPACT_BUFFER_MANUAL" ]]; then
        echo "$AUTOCOMPACT_BUFFER_MANUAL"
        return
    fi

    local configured
    configured=$(parse_window "$CLAUDE_CODE_AUTO_COMPACT_WINDOW")

    local settings="$HOME/.claude/settings.json"
    if [[ -z "$configured" && -f "$settings" ]]; then
        local enabled raw
        IFS=$'\037' read -r enabled raw <<<"$(
            jq -r '[(if .autoCompactEnabled == null then true else .autoCompactEnabled end),
                    (.autoCompactWindow // "")] | join("\u001f")' \
                "$settings" 2>/dev/null
        )"
        if [[ "$enabled" == "false" ]]; then
            echo 0
            return
        fi
        configured=$(parse_window "$raw")
    fi

    if [[ -n "$configured" ]] && (( configured > 0 && configured < full )); then
        echo $(( full - configured ))
        return
    fi

    echo "$AUTOCOMPACT_BUFFER"
}

# Prefer exact token counts; fall back to the rounded percentage.
tokens=0
if (( exact_tokens > 0 )); then
    tokens=$exact_tokens
elif (( usage_tokens > 0 )); then
    tokens=$usage_tokens
elif [[ "$used_pct" != "-1" ]] && (( window > 0 )); then
    tokens=$(awk "BEGIN{printf \"%.0f\", ($used_pct / 100) * $window}")
fi

# No context_window in the payload (Claude Code older than 2.1.6) - say nothing
# rather than display a guess.
tokens_display=""
if (( window > 0 && tokens > 0 )); then
    buffer=$(resolve_buffer "$window")
    effective=$(( window - buffer ))
    (( effective < 1 )) && effective=$window

    percentage=$(awk "BEGIN{p = ($tokens / $effective) * 100; if (p > 100) p = 100; printf \"%.0f\", p}")

    if (( percentage < 75 )); then
        status="✓"
    elif (( percentage < 90 )); then
        status="⚠"
    else
        status="⚠⚠"
    fi

    tokens_display=" ${status} $(( tokens / 1000 ))k/$(( effective / 1000 ))k (${percentage}%)"
fi

# Account rate limits are only worth the space once they get close.
limits_display=""
if (( five_h >= RATE_LIMIT_WARN_PCT || seven_d >= RATE_LIMIT_WARN_PCT )); then
    limits_display=" · 5h ${five_h}% 7d ${seven_d}%"
fi

printf "%s%s [%s]%s%s" "$display_dir" "$git_branch" "$model" "$tokens_display" "$limits_display"
