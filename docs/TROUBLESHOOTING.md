# Troubleshooting

## Table of Contents

- [Installation](#installation)
- [Token counter](#token-counter)
- [Session / Week limits](#session--week-limits)
- [Display](#display)
- [Upgrading from ≤ 1.4.0](#upgrading-from--140)
- [Debugging](#debugging)

## Installation

### Status line not appearing

1. Check `~/.claude/settings.json` is valid and points to the script:
   ```bash
   jq .statusLine ~/.claude/settings.json
   ```
2. Check the script exists and is executable:
   ```bash
   ls -l ~/.claude/statusline-with-tokens.sh
   chmod +x ~/.claude/statusline-with-tokens.sh
   ```
3. Restart Claude Code.

### `jq: command not found`

```bash
brew install jq       # macOS
sudo apt install jq   # Debian/Ubuntu
sudo dnf install jq   # Fedora/RHEL
```

Without `jq` the script prints only ` [?]`.

## Token counter

### Only `[Model]` shown, no tokens

The token part is hidden when the payload has no `context_window` data:

- **New conversation** — appears after the first response.
- **Claude Code < 2.1.6** — `context_window` isn't sent. Update: `claude update`.

### Numbers differ from `/context`

The budget is `window − 33k` (auto-compact buffer). If you changed the auto-compact window, the script picks it up from `CLAUDE_CODE_AUTO_COMPACT_WINDOW` or `autoCompactWindow` in `~/.claude/settings.json`.

If Claude Code changes the buffer size in a future version, set it in the script:

```bash
AUTOCOMPACT_BUFFER_MANUAL=40000
```

Compare against the `Autocompact buffer` row in `/context`.

### Budget shows full window (e.g. 200k, not 167k)

`autoCompactEnabled` is `false` in `~/.claude/settings.json` — without auto-compact there's no reserved buffer, so the full window is the budget. This is intended.

## Session / Week limits

### Not shown at all

- **API key / Console billing** — `rate_limits` only exists for Pro/Max subscriptions.
- **No response yet in this session** — appears after the first API response.
- **Old Claude Code** — update to the latest 2.1.x.

Check what your Claude Code sends (see [Debugging](#debugging)) and look for a `rate_limits` key.

### `(reset …)` missing but percentage shown

`resets_at` is in the past. The payload refreshes after the next API response; until then the countdown is hidden rather than showing a wrong value.

### Countdown not ticking

The script only runs when Claude Code redraws the status line (after messages, mode changes, etc.), so the countdown updates at that cadence, not every minute.

### `⚠` in front of the percentage

The limit crossed `RATE_LIMIT_WARN_PCT` (default 80). Change it at the top of the script.

## Display

### Garbled `✓` / `⚠` characters

Your terminal isn't using UTF-8:

```bash
echo $LANG   # should end with .UTF-8
export LANG=en_US.UTF-8
```

### Status line too long

Shorten labels in the `limits_display` block (e.g. `Session` → `5h`, `Week` → `7d`) or drop the directory from the final `printf`.

### Git branch not showing

The branch is read with `git -C <cwd> branch --show-current`. It's empty in a detached HEAD state or outside a git repo.

## Upgrading from ≤ 1.4.0

Versions up to 1.4.0 parsed transcripts, estimated overhead from MCP server count, and wrote per-session cache files plus a debug dump. None of that is used anymore. Clean up:

```bash
rm -f ~/.claude/.token-cache-* ~/.claude/statusline-debug.json
```

`SYSTEM_OVERHEAD_MANUAL` no longer exists; use `AUTOCOMPACT_BUFFER_MANUAL` if you need to adjust the budget.

## Debugging

### Test with a sample payload

```bash
echo '{"workspace":{"current_dir":"'"$PWD"'"},"model":{"display_name":"Test"},"context_window":{"context_window_size":200000,"total_input_tokens":45000},"rate_limits":{"five_hour":{"used_percentage":14,"resets_at":'$(( $(date +%s) + 7500 ))'},"seven_day":{"used_percentage":9}}}' \
  | ~/.claude/statusline-with-tokens.sh
# ~/current/dir (branch) [Test] ✓ 45k/167k (27%) · Session 14% (reset 2h05m) · Week 9%
```

### Capture the real payload

Temporarily add after `input=$(cat)` in the script:

```bash
echo "$input" > /tmp/statusline-input.json
```

Send a message, then inspect and replay:

```bash
jq '{context_window, rate_limits}' /tmp/statusline-input.json
~/.claude/statusline-with-tokens.sh < /tmp/statusline-input.json
```

Remove the line afterwards.

### Syntax check

```bash
bash -n ~/.claude/statusline-with-tokens.sh
```

## Getting help

[Open an issue](https://github.com/lukaskraic/claude-status-line/issues) with your Claude Code version (`claude --version`), OS, and the output of the sample-payload test above.
