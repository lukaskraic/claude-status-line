# Claude Code Status Line with Token Counter

Status line for Claude Code showing context usage against the auto-compact limit, plus your account's session and weekly rate limits.

## Features

- **Context usage** measured against the point where auto-compact fires, not the raw window
- **Visual indicators**: ✓ safe (0-74%), ⚠ warning (75-89%), ⚠⚠ critical (90-100%)
- **Session limit**: 5-hour rate-limit usage in % with countdown to reset
- **Week limit**: 7-day rate-limit usage in %
- **Git branch**, **model name**, **current directory**
- Works with any window size (200k, 1M) — read straight from Claude Code, no guessing

## Demo

```
Format: ~/directory (branch) [Model] ✓ XXk/YYYk (ZZ%) · Session S% (reset 1h23m) · Week W%

~/Work/myproject (main) [Opus 5] ✓ 139k/967k (14%) · Session 14% (reset 2h05m) · Week 9%
~/Documents (develop) [Sonnet 5] ⚠ 140k/167k (84%) · Session ⚠86% (reset 42m) · Week 31%
~/scripts [Haiku 5] ⚠⚠ 155k/167k (93%)
```

The last line is an API-key user: rate limits only exist on Pro/Max subscriptions, so that part is hidden.

## Quick Install

### Prerequisites

- [Claude Code](https://code.claude.com) 2.1.6 or newer (rate limits need a recent 2.1.x release)
- `jq`:
  ```bash
  brew install jq       # macOS
  sudo apt install jq   # Linux
  ```

### Installation

1. **Download the script**:
   ```bash
   curl -o ~/.claude/statusline-with-tokens.sh \
     https://raw.githubusercontent.com/lukaskraic/claude-status-line/main/statusline-with-tokens.sh
   chmod +x ~/.claude/statusline-with-tokens.sh
   ```

2. **Point Claude Code at it** (`~/.claude/settings.json`):
   ```json
   {
     "statusLine": {
       "type": "command",
       "command": "~/.claude/statusline-with-tokens.sh"
     }
   }
   ```

3. **Restart Claude Code** or start a new conversation.

See [INSTALL.md](INSTALL.md) for more options and verification steps.

## How It Works

Claude Code pipes a JSON payload to the script on every status line refresh. The script reads it in a single `jq` pass:

| Field | Used for |
|-------|----------|
| `context_window.total_input_tokens` | Tokens in context (fallbacks: `current_usage` sum, then `used_percentage`) |
| `context_window.context_window_size` | Full window size |
| `rate_limits.five_hour.used_percentage` / `resets_at` | Session % and time to reset |
| `rate_limits.seven_day.used_percentage` | Week % |
| `workspace.current_dir`, `model.display_name` | Directory, git branch, model |

### Context budget

Claude Code reserves a fixed **33k** buffer of every window for the auto-compact summary; auto-compact fires at `window − buffer`. The script shows usage against that effective budget (e.g. 167k for a 200k window, 967k for 1M), which matches what `/context` reports.

### Rate limits

- **Session** — 5-hour rolling window. `(reset 2h05m)` is the time until it resets; it's hidden once the reset time has passed and the payload hasn't been refreshed yet.
- **Week** — 7-day window.
- Values ≥ 80% get a `⚠` prefix.
- The countdown is recalculated whenever Claude Code redraws the status line.

## Configuration

Edit the variables at the top of `statusline-with-tokens.sh`:

| Variable | Default | Meaning |
|----------|---------|---------|
| `AUTOCOMPACT_BUFFER` | `33000` | Reserved auto-compact buffer |
| `AUTOCOMPACT_BUFFER_MANUAL` | unset | Hard override of the buffer |
| `RATE_LIMIT_WARN_PCT` | `80` | Threshold for the `⚠` on session/week limits |

The buffer is also derived automatically from your Claude Code settings, in this order:

1. `AUTOCOMPACT_BUFFER_MANUAL`
2. `CLAUDE_CODE_AUTO_COMPACT_WINDOW` env var (e.g. `500k`)
3. `autoCompactWindow` in `~/.claude/settings.json` (`500000`, `500k`, `1m`)
4. `autoCompactEnabled: false` in `~/.claude/settings.json` → no buffer, full window
5. `AUTOCOMPACT_BUFFER`

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for details.

## Troubleshooting

- **Only `[Model]` shown, no tokens** — Claude Code is older than 2.1.6 (no `context_window` in payload) or no message has been sent yet. Update Claude Code.
- **No Session/Week** — you're on an API key, or no API response has arrived yet in this session.
- **Status line empty** — check `jq` is installed and the script is executable.

Test manually:
```bash
echo '{"workspace":{"current_dir":"'"$PWD"'"},"model":{"display_name":"Test"},"context_window":{"context_window_size":200000,"total_input_tokens":45000},"rate_limits":{"five_hour":{"used_percentage":14,"resets_at":'$(( $(date +%s) + 7500 ))'},"seven_day":{"used_percentage":9}}}' \
  | ~/.claude/statusline-with-tokens.sh
# ~/current/dir (branch) [Test] ✓ 45k/167k (27%) · Session 14% (reset 2h05m) · Week 9%
```

More in [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md).

## Documentation

- [Installation Guide](INSTALL.md)
- [Architecture](docs/ARCHITECTURE.md)
- [Troubleshooting](docs/TROUBLESHOOTING.md)
- [Output Examples](docs/examples/output-examples.txt)
- [Changelog](CHANGELOG.md)

## Contributing

Issues and pull requests are welcome.

## License

MIT License - see [LICENSE](LICENSE).

## Author

**Lukas Kraic** - [GitHub](https://github.com/lukaskraic)
