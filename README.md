# Claude Code Status Line with Token Counter

Beautiful, informative status line for Claude Code with per-window token tracking.

## Features

- ✅ **Per-Window Token Tracking**: Each Claude Code window maintains its own independent token counter
- ✅ **Visual Indicators**:
  - ✓ Safe (<50% usage)
  - ⚠ Warning (50-80% usage)
  - ⚠⚠ Critical (>80% usage)
- ✅ **Intelligent Fallbacks**: Automatically tries JSON → transcript → cache for maximum reliability
- ✅ **Git Integration**: Shows current branch when in a git repository
- ✅ **Compact Display**: Human-readable format (45k instead of 45000)
- ✅ **Model Display**: Shows which Claude model you're using
- ✅ **Session Persistence**: Token count survives temporary data unavailability

## Demo

```
Format: ~/directory (branch) [Model Name] ✓ XXk/YYYk (ZZ%)

Examples:
~/Work/myproject (main) [Claude Sonnet 4.5] ✓ 45k/200k (22%)
~/Documents (develop) [Claude Haiku 4.5] ⚠ 140k/200k (70%)
~/.claude [Claude Opus 4.5] ⚠⚠ 180k/200k (90%)
```

## Quick Install

### Prerequisites

- [Claude Code](https://code.claude.com) installed
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

That's it! Your status line will now show token usage for each window independently.

## How It Works

The status line script:

1. **Receives JSON input** from Claude Code with session metadata
2. **Extracts token usage** from `.context.usage.total`
3. **Falls back intelligently**:
   - Primary: JSON data from Claude Code
   - Secondary: Parse transcript file
   - Tertiary: Read from cache file
4. **Uses per-window cache**: Each session gets `~/.claude/.token-cache-{session_id}`
5. **Formats and displays**: directory, branch, model, tokens with visual indicators

### Per-Window Isolation

Each window gets a unique `session_id` from Claude Code, ensuring completely independent token tracking. You can have multiple windows open with different conversations, and each will track its own token usage.

### Visual Indicators

The status indicator helps you quickly assess context usage:

| Indicator | Usage | Meaning |
|-----------|-------|---------|
| ✓ | <50% | Safe - plenty of context remaining |
| ⚠ | 50-80% | Warning - approaching limit |
| ⚠⚠ | >80% | Critical - near context limit |

## Configuration

The script automatically detects and displays:

- **Current directory**: With `~` expansion for home directory
- **Git branch**: Shown in parentheses when in a git repository
- **Model name**: The Claude model you're currently using
- **Token usage**: Current usage / budget limit (percentage)

### Customization

You can modify the script to customize:

- Threshold percentages for visual indicators (lines 88-96)
- Display format (line 103)
- Token formatting (lines 84-99)

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for technical details.

## Troubleshooting

### Token counter shows 0

The script has a 3-tier fallback system. If you see 0:
- Check that `jq` is installed: `which jq`
- Verify the script is executable: `ls -l ~/.claude/statusline-with-tokens.sh`
- Check Claude Code logs for errors

### Status line not updating

- Restart Claude Code
- Check that `settings.json` points to the correct script path
- Verify the script runs: `echo '{}' | ~/.claude/statusline-with-tokens.sh`

### jq not found

Install `jq`:
```bash
brew install jq  # macOS
sudo apt install jq  # Linux
```

### Multiple windows show same count

This was fixed in v1.0.0 with session-based caching. Make sure you have the latest version:
```bash
curl -o ~/.claude/statusline-with-tokens.sh \
  https://raw.githubusercontent.com/lukaskraic/claude-status-line/main/statusline-with-tokens.sh
chmod +x ~/.claude/statusline-with-tokens.sh
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
