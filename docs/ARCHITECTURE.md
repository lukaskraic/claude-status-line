# Architecture Documentation

Technical implementation details for Claude Code Status Line with Token Counter.

## Table of Contents

- [Overview](#overview)
- [Data Flow](#data-flow)
- [Token Extraction Strategy](#token-extraction-strategy)
- [Auto-compact Buffer Resolution](#auto-compact-buffer-resolution)
- [Display Formatting](#display-formatting)
- [Error Handling](#error-handling)
- [Dependencies](#dependencies)
- [Performance](#performance)
- [Debugging](#debugging)

## Overview

The status line is a single bash script. Claude Code runs it on every status line
refresh, hands it a JSON payload on stdin and prints whatever it writes to stdout.

```
Claude Code ──JSON on stdin──▶ statusline-with-tokens.sh ──string on stdout──▶ status line
```

Everything the script needs is in that payload. It keeps no state: no cache files,
no transcript reads, no configuration beyond two constants at the top and the
auto-compact settings Claude Code already stores.

## Data Flow

### Input JSON Structure

The fields this script reads, as emitted by Claude Code 2.1.278:

```json
{
  "workspace": { "current_dir": "/Users/username/project" },
  "cwd": "/Users/username/project",
  "model": { "display_name": "Opus 5" },
  "context_window": {
    "context_window_size": 1000000,
    "total_input_tokens": 138419,
    "used_percentage": 14,
    "current_usage": {
      "input_tokens": 2,
      "output_tokens": 248,
      "cache_creation_input_tokens": 4343,
      "cache_read_input_tokens": 59035
    }
  },
  "rate_limits": {
    "five_hour": { "used_percentage": 11 },
    "seven_day": { "used_percentage": 8 }
  }
}
```

The payload carries considerably more (`session_id`, `transcript_path`, `cost`,
`prompt_cache`, `effort`, `thinking`, `vim`, `worktree`, `pr`, …); the script
ignores everything it does not display.

`context_window` arrives from Claude Code 2.1.6 onwards. `rate_limits` from 2.1.251.

### Output Format

```
~/project (main) [Opus 5] ✓ 138k/967k (14%)
```

Components:

1. **Directory**: `~/project` (with `~` expansion)
2. **Git Branch**: `(main)` — omitted outside a git repository
3. **Model Name**: `[Opus 5]`
4. **Token Info**: `✓ 138k/967k (14%)` — indicator, used, effective window, percentage
5. **Rate limits**: ` · 5h 82% 7d 50%` — appended only above `RATE_LIMIT_WARN_PCT`

## Token Extraction Strategy

One `jq` pass pulls every field at once, joined by `\u001f` (unit separator) rather
than tabs — tab is IFS whitespace, so bash collapses runs of it and an empty field
would shift every value after it.

```bash
IFS=$'\037' read -r cwd model window exact_tokens usage_tokens used_pct five_h seven_d <<<"$(
    jq -r '[ ... ] | join("\u001f")' <<<"$input" 2>/dev/null
)"
```

Three token sources, in descending order of precision:

| Source | Precision | When used |
|--------|-----------|-----------|
| `context_window.total_input_tokens` | exact | normal operation |
| sum of `context_window.current_usage` | exact | older payloads without `total_input_tokens` |
| `used_percentage × context_window_size` | ±1% of the window (10k on a 1M window) | last resort |

If none of them yield a positive value, the token segment is omitted entirely. The
script never substitutes an estimate — a missing number is more honest than a
fabricated one.

## Auto-compact Buffer Resolution

Claude Code reserves a fixed slice of the context window for the auto-compact
summary and reports it as a separate `/context` row:

```
| Free space         | 148.2k | 74.1% |
| Autocompact buffer | 33k    | 16.5% |
```

Measured on 2.1.278, that buffer is **33,000 tokens on both a 200k and a 1M
window** — fixed, not proportional. Usage counts against
`context_window_size - buffer`, because that is where compaction fires.

`used_percentage` in the payload is measured against the *full* window and
excludes the buffer, so the subtraction happens here.

`resolve_buffer()` walks these in order and returns on the first match:

| Source | Meaning |
|--------|---------|
| `AUTOCOMPACT_BUFFER_MANUAL` | buffer in tokens, set in the script |
| `CLAUDE_CODE_AUTO_COMPACT_WINDOW` | effective window; buffer is `full - value` |
| `autoCompactWindow` (settings.json) | same; accepts `500000`, `500k`, `1m` |
| `autoCompactEnabled: false` | buffer `0` |
| `AUTOCOMPACT_BUFFER` | default `33000` |

Note that `jq`'s `//` operator treats `false` as absent, so the enabled check uses
an explicit null test:

```bash
jq -r '[(if .autoCompactEnabled == null then true else .autoCompactEnabled end), ...]'
```

## Display Formatting

### Percentage Calculation

```bash
effective=$(( window - buffer ))
percentage=$(awk "BEGIN{p = ($tokens / $effective) * 100; if (p > 100) p = 100; printf \"%.0f\", p}")

# Example: 750000 / 967000 = 0.7756 → 78%
```

The cap matters: usage can exceed the effective window in the moment before
auto-compact runs, and `103%` reads as a bug rather than as a warning.

### Visual Indicators

```bash
if (( percentage < 75 )); then
    status="✓"
elif (( percentage < 90 )); then
    status="⚠"
else
    status="⚠⚠"
fi
```

| Indicator | Range | Meaning |
|-----------|-------|---------|
| ✓ | <75% | Safe (plenty of context) |
| ⚠ | 75-89% | Warning (approaching auto-compact) |
| ⚠⚠ | ≥90% | Critical (auto-compact imminent) |

### Final Output

```bash
printf "%s%s [%s]%s%s" \
    "$display_dir" "$git_branch" "$model" "$tokens_display" "$limits_display"
```

## Error Handling

| Failure | Behaviour |
|---------|-----------|
| No stdin / malformed JSON | prints ` [?]`, no token segment |
| No `context_window` in payload | directory, branch and model only |
| `cwd` missing or not a directory | branch omitted, `git` never invoked |
| Unreadable `settings.json` | falls through to the default buffer |
| Usage above the effective window | percentage capped at 100% |

All `jq` invocations are `2>/dev/null` and every numeric comparison runs in an
arithmetic context, where an empty variable evaluates to `0`.

## Dependencies

### Required

- **bash**: 3.2+ — macOS still ships 3.2, so no `${var,,}`, no associative arrays,
  no `mapfile`
- **jq**: JSON processor

### Standard Utilities

- `cat` — read stdin
- `git` — branch detection (optional; skipped when `cwd` is not a directory)
- `awk` — percentage arithmetic
- `tr` — lowercasing for `parse_window` (bash 3.2 has no case conversion)
- `printf` — format output

## Performance

Two `jq` invocations at most: one over the payload, one over `settings.json` (only
when no environment override is set). Typical execution is well under 50ms,
dominated by `git branch --show-current`.

Claude Code debounces status line refreshes at 300ms, so the script is not invoked
more than a few times per second even during heavy output.

## Debugging

### Test Manually

```bash
echo '{"workspace":{"current_dir":"'"$PWD"'"},"model":{"display_name":"Opus 5"},
       "context_window":{"context_window_size":1000000,"total_input_tokens":750000}}' \
  | ~/.claude/statusline-with-tokens.sh
# ~/your/dir (main) [Opus 5] ⚠ 750k/967k (78%)
```

### Capture a Real Payload

Point `statusLine.command` at a wrapper that tees stdin before calling the script:

```bash
#!/bin/bash
tee ~/.claude/statusline-payload.json | ~/.claude/statusline-with-tokens.sh
```

Note that Claude Code does not run the status line in headless (`claude -p`) mode,
so payloads can only be captured from an interactive session.

### Verify Against `/context`

Run `/context` in Claude Code. Its headline `Tokens: X / window` should match this
script's numerator; the "Autocompact buffer" row should match the constant used to
derive the denominator.

## References

- [Claude Code status line documentation](https://code.claude.com/docs/en/statusline)
- [jq Manual](https://stedolan.github.io/jq/manual/)
- [Bash Reference Manual](https://www.gnu.org/software/bash/manual/)
