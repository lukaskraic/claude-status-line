# Claude Code Status Line with Token Counter

Status line for Claude Code that shows how much context you have left **before auto-compact fires** — not before the raw window ends.

## Features

- ✅ **Auto-compact aware**: measures usage against `context_window_size - autocompact_buffer`, which is the limit that actually triggers compaction
- ✅ **Exact token counts**: reads `context_window.total_input_tokens` from the status line JSON, no transcript parsing or guesswork
- ✅ **Visual Indicators**:
  - ✓ Safe (0-74% usage)
  - ⚠ Warning (75-89% usage)
  - ⚠⚠ Critical (90-100% usage, auto-compact imminent)
- ✅ **Rate limit warning**: appends your 5-hour / 7-day account usage once either crosses 80%
- ✅ **Respects your auto-compact config**: honours `CLAUDE_CODE_AUTO_COMPACT_WINDOW`, `autoCompactWindow` and `autoCompactEnabled`
- ✅ **Git Integration**: shows current branch when in a git repository
- ✅ **Model Display**: shows which Claude model you're using

## Demo

```
Format: ~/directory (branch) [Model Name] ✓ XXk/YYYk (ZZ%)

Examples:
~/Work/myproject (main) [Opus 5] ✓ 138k/967k (14%)
~/Documents (develop) [Sonnet 5] ⚠ 130k/167k (78%)
~/.claude [Haiku 4.5] ⚠⚠ 150k/167k (90%) · 5h 82% 7d 50%
```

The denominator is the effective window: 967k on a 1M model, 167k on a 200k model.

## Quick Install

### Prerequisites

- [Claude Code](https://code.claude.com) 2.1.6 or newer (the `context_window` field in the status line JSON)
- `jq` installed:
  ```bash
  brew install jq  # macOS
  sudo apt install jq  # Linux
  ```

### Installation

1. **Download and install the script**:
   ```bash
   curl -o ~/.claude/statusline-with-tokens.sh \
     https://raw.githubusercontent.com/lukaskraic/claude-status-line/main/statusline-with-tokens.sh
   chmod +x ~/.claude/statusline-with-tokens.sh
   ```

2. **Update Claude Code settings** (`~/.claude/settings.json`):
   ```json
   {
     "statusLine": {
       "type": "command",
       "command": "~/.claude/statusline-with-tokens.sh"
     }
   }
   ```

3. **Restart Claude Code** or start a new conversation

## How It Works

Claude Code passes a JSON payload on stdin. The script:

1. **Reads the token count** from `context_window`, preferring the exact sources:
   `total_input_tokens` → sum of `current_usage` → `used_percentage × context_window_size`
2. **Subtracts the auto-compact buffer from the window** to get the effective budget
3. **Formats** directory, branch, model, usage and (when high) rate limits

If the payload has no `context_window` object at all, the token segment is omitted rather than guessed.

### Why the denominator is not the full window

Claude Code reserves a fixed slice of every context window for the auto-compact summary. `/context` reports it as its own row:

```
| Free space        | 148.2k | 74.1% |
| Autocompact buffer| 33k    | 16.5% |
```

Measured on Claude Code 2.1.278, that buffer is **33,000 tokens, fixed** — the same value on a 200k window and on a 1M window, not a proportion. Auto-compact fires when usage reaches `window - 33k`, so that is the number worth counting against.

The `used_percentage` field in the status line JSON is computed against the **full** window and excludes the buffer, so the script does the subtraction itself.

### Visual Indicators

| Indicator | Usage of effective window | Meaning |
|-----------|---------------------------|---------|
| ✓ | 0-74% | Safe - plenty of context remaining |
| ⚠ | 75-89% | Warning - approaching auto-compact |
| ⚠⚠ | 90-100% | Critical - auto-compact imminent |

## Configuration

### Auto-compact window

The buffer is resolved in this order, first match wins:

| Source | Effect |
|--------|--------|
| `AUTOCOMPACT_BUFFER_MANUAL` in the script | exact buffer in tokens |
| `CLAUDE_CODE_AUTO_COMPACT_WINDOW` env var | an explicit effective window (`500000`, `500k`, `1m`) |
| `autoCompactWindow` in `~/.claude/settings.json` | same, also set by `/autocompact <size>` |
| `autoCompactEnabled: false` in `~/.claude/settings.json` | no buffer — full window is the budget |
| `AUTOCOMPACT_BUFFER` in the script | default `33000` |

If Anthropic changes the constant, edit `AUTOCOMPACT_BUFFER` at the top of the script. To check the current value, run `/context` and read the "Autocompact buffer" row.

### Rate limit warning

`RATE_LIMIT_WARN_PCT` (default `80`) controls when ` · 5h NN% 7d NN%` is appended. Set it to `101` to switch the segment off.

### Customization

Threshold percentages, the display format and token formatting are all plain shell at the bottom of the script. See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for technical details.

## Troubleshooting

### Token counter missing

The segment is omitted when the payload carries no `context_window` object — that means Claude Code is older than 2.1.6. Check with `claude --version`.

Otherwise:
- Check that `jq` is installed: `which jq`
- Verify the script is executable: `ls -l ~/.claude/statusline-with-tokens.sh`

### Numbers don't match `/context`

They intentionally differ: `/context` shows usage against the full window, this script shows it against the effective one. On a 1M window, 750k reads as `75%` in `/context` and `78%` here (750k / 967k).

If the *token* count differs, compare the "Autocompact buffer" row from `/context` with `AUTOCOMPACT_BUFFER` in the script.

### Status line not updating

- Restart Claude Code
- Check that `settings.json` points to the correct script path
- Verify the script runs: `echo '{}' | ~/.claude/statusline-with-tokens.sh`

### jq not found

```bash
brew install jq  # macOS
sudo apt install jq  # Linux
```

For more issues, see [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md).

## Documentation

- [Installation Guide](INSTALL.md) - Detailed installation instructions
- [Architecture](docs/ARCHITECTURE.md) - Technical implementation details
- [Troubleshooting](docs/TROUBLESHOOTING.md) - Common issues and solutions
- [Changelog](CHANGELOG.md) - Version history

## Contributing

Contributions are welcome! Please feel free to submit issues or pull requests.

## License

MIT License - see [LICENSE](LICENSE) file for details.

## Author

**Lukas Kraic** - [GitHub](https://github.com/lukaskraic)

## Acknowledgments

- Built for [Claude Code](https://code.claude.com)
- Inspired by the need for better context window visibility
- Uses `jq` for JSON parsing
