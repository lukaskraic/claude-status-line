# Claude Code Status Line with Token Counter

Beautiful, informative status line for Claude Code with per-window token tracking.

## Features

- ✅ **Per-Window Token Tracking**: Each Claude Code window maintains its own independent token counter
- ✅ **Visual Indicators**:
  - ✓ Safe (0-74% usage)
  - ⚠ Warning (75-89% usage)
  - ⚠⚠ Critical (90-100% usage, auto-compact imminent)
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
| ✓ | 0-74% | Safe - plenty of context remaining |
| ⚠ | 75-89% | Warning - approaching auto-compact |
| ⚠⚠ | 90-100% | Critical - auto-compact imminent (~92%) |

## Configuration

The script automatically detects and displays:

- **Current directory**: With `~` expansion for home directory
- **Git branch**: Shown in parentheses when in a git repository
- **Model name**: The Claude model you're currently using
- **Token usage**: Current usage / budget limit (percentage)

### System Overhead

The script automatically detects system overhead based on your MCP configuration using a multi-location fallback mechanism.

**Auto-detection** (default):
- Reads MCP configuration from multiple locations (in order):
  1. `~/.claude/settings.json` (project-specific)
  2. `~/Library/Application Support/Claude/claude_desktop_config.json` (global)
- Estimates overhead based on **enabled** MCP server count:
  - **0 servers**: 24k (base: system prompt + tools + agents + memory)
  - **1-2 servers**: 34k (base + minimal MCP overhead)
  - **3-4 servers**: 54k (base + moderate MCP overhead)
  - **5-6 servers**: 74k (base + high MCP overhead)
  - **7+ servers**: 104k (base + maximum MCP overhead)
- Handles disabled servers correctly (excludes them from count)
- Graceful fallbacks if both config files are missing or malformed
- **Dynamic detection**: Updates automatically when MCP servers are disabled/enabled (no restart needed)

**Manual override** (optional):

If auto-detection doesn't match your `/context` output, you can manually override:

```bash
# Edit ~/.claude/statusline-with-tokens.sh
# Uncomment and set your custom value:
SYSTEM_OVERHEAD_MANUAL=35000
```

**How to calibrate:**
1. Run `/context` in Claude Code
2. Note the total tokens shown (e.g., "162k/200k")
3. Compare with your status line
4. If they differ, set `SYSTEM_OVERHEAD_MANUAL` to fine-tune (adjust by ±5-10k)

**After `/clear` command:**
- Status line shows system overhead as minimum (instead of 0k)
- This matches `/context` behavior which always includes system overhead
- As soon as you send a new message, the count updates to include conversation tokens

### Customization

You can modify the script to customize:

- System overhead detection (see `detect_mcp_servers()` function or use `SYSTEM_OVERHEAD_MANUAL`)
- Threshold percentages for visual indicators
- Display format
- Token formatting

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
