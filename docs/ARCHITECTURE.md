# Architecture

Technical details of `statusline-with-tokens.sh`.

## Overview

Claude Code runs the status line command on every refresh and pipes a JSON payload to its stdin. The script is stateless: it reads that payload, does a little arithmetic, and prints one line. No transcript parsing, no cache files, nothing written to disk.

```
Claude Code ──JSON──▶ statusline-with-tokens.sh ──▶ one line of text
                         │
                         ├─ jq (single pass over payload)
                         ├─ git -C <cwd> branch --show-current
                         └─ ~/.claude/settings.json (only to resolve the auto-compact buffer)
```

## Input

Relevant part of the payload (Claude Code 2.1.x):

```json
{
  "workspace": { "current_dir": "/Users/me/Work/project" },
  "model": { "display_name": "Opus 5" },
  "context_window": {
    "total_input_tokens": 139291,
    "context_window_size": 1000000,
    "current_usage": {
      "input_tokens": 2,
      "cache_creation_input_tokens": 872,
      "cache_read_input_tokens": 138417
    },
    "used_percentage": 14
  },
  "rate_limits": {
    "five_hour": { "used_percentage": 14, "resets_at": 1789988400 },
    "seven_day": { "used_percentage": 9,  "resets_at": 1790384400 }
  }
}
```

- `context_window` exists since Claude Code 2.1.6.
- `rate_limits` exists only for Pro/Max subscriptions and only after the first API response in the session. `resets_at` is a Unix timestamp in seconds.

All fields are extracted with one `jq` call, joined with the ASCII unit separator (`\x1f`) and split with `IFS=$'\037' read`. Rate-limit percentages are rounded in `jq` because bash arithmetic is integer-only.

## Output

```
<dir> (<branch>) [<model>] <status> <tokens>k/<budget>k (<pct>%) · Session <s>% (reset <time>) · Week <w>%
```

Every part after `[<model>]` is optional and disappears when its data is missing. Claude Code doesn't render ANSI colors in this mode, so the output is plain text.

## Context usage

### Token count

Sources in order of preference:

1. `context_window.total_input_tokens` — exact
2. Sum of `context_window.current_usage` (`input_tokens + cache_creation_input_tokens + cache_read_input_tokens`)
3. `context_window.used_percentage × context_window_size` — rounded to whole percent, last resort

If none is available (old Claude Code, nothing sent yet) the token part is omitted rather than guessed.

### Budget

Claude Code reserves a fixed buffer for the auto-compact summary and compacts when usage reaches `window − buffer`. The script displays usage against that effective budget:

```
effective = context_window_size − buffer
pct       = min(100, tokens / effective × 100)
```

Measured on Claude Code 2.1.278, `/context` reports `Autocompact buffer | 33k` for both 200k and 1M windows — fixed, not proportional. Hence `AUTOCOMPACT_BUFFER=33000`.

Buffer resolution (`resolve_buffer`):

1. `AUTOCOMPACT_BUFFER_MANUAL` in the script
2. `CLAUDE_CODE_AUTO_COMPACT_WINDOW` env var → `buffer = window − value`
3. `autoCompactWindow` in `~/.claude/settings.json` → same; accepts `500000`, `500k`, `1m`
4. `autoCompactEnabled: false` in `~/.claude/settings.json` → buffer 0
5. `AUTOCOMPACT_BUFFER`

A configured window ≥ the real window is ignored.

### Status indicator

| Indicator | Usage of effective budget |
|-----------|---------------------------|
| ✓ | 0-74% |
| ⚠ | 75-89% |
| ⚠⚠ | 90-100% |

## Rate limits

| Display | Source |
|---------|--------|
| `Session S%` | `rate_limits.five_hour.used_percentage` |
| `(reset 2h05m)` | `rate_limits.five_hour.resets_at − now`, rounded up to the minute |
| `Week W%` | `rate_limits.seven_day.used_percentage` |

- Percentages ≥ `RATE_LIMIT_WARN_PCT` (default 80) get a `⚠` prefix.
- The countdown is formatted as `XhMMm` from one hour up, `Mm` below.
- If `resets_at` is already in the past the countdown is hidden: the payload is stale until the next API response refreshes it.
- The countdown only changes when Claude Code redraws the status line.

## Error handling

- `jq` failure (empty or malformed stdin) leaves variables empty; they default to "no data" and the script prints just ` [?]`.
- Missing `cwd` or non-git directory → no branch.
- `jq` errors go to `/dev/null`; the script never exits non-zero on bad input.

## Dependencies

- `bash` 3.2+ (macOS default; no `${var,,}` used)
- `jq`
- `awk`, `date`, `tr`, `git` (optional)

## Customization points

| What | Where |
|------|-------|
| Auto-compact buffer | `AUTOCOMPACT_BUFFER`, `AUTOCOMPACT_BUFFER_MANUAL` |
| Rate-limit warning threshold | `RATE_LIMIT_WARN_PCT` |
| Context indicator thresholds | `if (( percentage < 75 ))` block |
| Rate-limit labels / format | `limits_display` block |
| Final layout | last `printf` |

## Debugging

Capture what Claude Code actually sends by temporarily adding after `input=$(cat)`:

```bash
echo "$input" > /tmp/statusline-input.json
```

Then replay it:

```bash
~/.claude/statusline-with-tokens.sh < /tmp/statusline-input.json
```

Remove the line afterwards — it writes on every refresh.

## References

- [Claude Code status line docs](https://code.claude.com/docs/en/statusline)
