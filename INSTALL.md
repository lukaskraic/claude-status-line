# Installation Guide

Complete installation instructions for Claude Code Status Line with Token Counter.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Verification](#verification)
- [Upgrading](#upgrading)
- [Uninstallation](#uninstallation)
- [Troubleshooting](#troubleshooting)

## Prerequisites

Before installing, ensure you have:

### Required

1. **Claude Code 2.1.6+** - [Download and install](https://code.claude.com). Older versions don't send `context_window`; session/week limits need a recent 2.1.x release and a Pro/Max subscription
2. **jq** - JSON processor (install instructions below)
3. **Bash** - Comes pre-installed on macOS and most Linux distributions (bash 3.2 is enough)

### Installing jq

**macOS (Homebrew)**:
```bash
brew install jq
```

**macOS (MacPorts)**:
```bash
sudo port install jq
```

**Linux (Ubuntu/Debian)**:
```bash
sudo apt update
sudo apt install jq
```

**Linux (Fedora/RHEL)**:
```bash
sudo dnf install jq
```

**Linux (Arch)**:
```bash
sudo pacman -S jq
```

Verify jq is installed:
```bash
jq --version
# Should output: jq-1.6 or similar
```

## Installation

### Method 1: Direct Download (Recommended)

1. **Download the script**:
   ```bash
   curl -o ~/.claude/statusline-with-tokens.sh \
     https://raw.githubusercontent.com/lukaskraic/claude-status-line/main/statusline-with-tokens.sh
   ```

2. **Make it executable**:
   ```bash
   chmod +x ~/.claude/statusline-with-tokens.sh
   ```

3. **Update Claude Code settings**:

   Edit `~/.claude/settings.json` and add/update the `statusLine` section:

   ```json
   {
     "statusLine": {
       "type": "command",
       "command": "~/.claude/statusline-with-tokens.sh"
     }
   }
   ```

   **Note**: If your `settings.json` already has other settings, just add the `statusLine` section without removing existing content.

4. **Restart Claude Code** or start a new conversation to see the changes

### Method 2: Git Clone

1. **Clone the repository**:
   ```bash
   cd ~/Downloads
   git clone https://github.com/lukaskraic/claude-status-line.git
   ```

2. **Copy the script**:
   ```bash
   cp claude-status-line/statusline-with-tokens.sh ~/.claude/
   chmod +x ~/.claude/statusline-with-tokens.sh
   ```

3. **Update Claude Code settings** (same as Method 1, step 3)

4. **Restart Claude Code**

## Verification

### 1. Check Script Exists

```bash
ls -l ~/.claude/statusline-with-tokens.sh
```

Should show:
```
-rwxr-xr-x  1 username  staff  XXXX Nov 29 HH:MM /Users/username/.claude/statusline-with-tokens.sh
```

The `x` permissions indicate the script is executable.

### 2. Test Script Manually

```bash
echo '{"workspace":{"current_dir":"'"$PWD"'"},"model":{"display_name":"Test Model"},"context_window":{"context_window_size":200000,"total_input_tokens":45000},"rate_limits":{"five_hour":{"used_percentage":14,"resets_at":'$(( $(date +%s) + 7500 ))'},"seven_day":{"used_percentage":9}}}' \
  | ~/.claude/statusline-with-tokens.sh
```

Expected output (branch only inside a git repo):
```
~/current/directory (branch) [Test Model] ✓ 45k/167k (27%) · Session 14% (reset 2h05m) · Week 9%
```

### 3. Verify in Claude Code

Start a new conversation, send a message, and check the status line:

```
~/your/directory (branch) [Model] ✓ XXk/YYYk (ZZ%) · Session S% (reset 1h23m) · Week W%
```

Tokens appear after the first response. `Session`/`Week` appear only on Pro/Max subscriptions.

## Upgrading

To upgrade to the latest version:

1. **Backup your current script** (optional):
   ```bash
   cp ~/.claude/statusline-with-tokens.sh ~/.claude/statusline-with-tokens.sh.backup
   ```

2. **Download the latest version**:
   ```bash
   curl -o ~/.claude/statusline-with-tokens.sh \
     https://raw.githubusercontent.com/lukaskraic/claude-status-line/main/statusline-with-tokens.sh
   chmod +x ~/.claude/statusline-with-tokens.sh
   ```

3. **Restart Claude Code** to apply changes

4. **Verify** the new version works as expected

## Uninstallation

To remove the custom status line and return to Claude Code defaults:

### Option 1: Remove Script and Configuration

1. **Edit `~/.claude/settings.json`** and remove the `statusLine` section:
   ```json
   {
     "statusLine": {
       "type": "command",
       "command": "~/.claude/statusline-with-tokens.sh"
     }
   }
   ```

2. **Remove the script** (optional):
   ```bash
   rm ~/.claude/statusline-with-tokens.sh
   ```

3. **Remove leftovers from versions ≤ 1.4.0** (optional):
   ```bash
   rm -f ~/.claude/.token-cache-* ~/.claude/statusline-debug.json
   ```

4. **Restart Claude Code**

### Option 2: Replace with Custom Command

If you want a different status line instead:

1. **Edit `~/.claude/settings.json`** and update the command:
   ```json
   {
     "statusLine": {
       "type": "command",
       "command": "your-custom-command-here"
     }
   }
   ```

2. **Restart Claude Code**

## Troubleshooting

### Installation Issues

#### "curl: command not found"

Install curl:
```bash
# macOS
brew install curl

# Linux
sudo apt install curl  # Ubuntu/Debian
sudo dnf install curl  # Fedora/RHEL
```

#### "Permission denied" when running script

Make the script executable:
```bash
chmod +x ~/.claude/statusline-with-tokens.sh
```

#### "~/.claude directory does not exist"

Claude Code should create this automatically. If it doesn't exist:
```bash
mkdir -p ~/.claude
```

#### "jq: command not found"

Install jq following the [Prerequisites](#prerequisites) section.

### Configuration Issues

#### Settings.json syntax error

Make sure your JSON is valid. Use a JSON validator or:
```bash
jq . ~/.claude/settings.json
```

If this shows an error, fix the JSON syntax (missing commas, brackets, etc.).

#### Changes not taking effect

1. Make sure you saved `settings.json`
2. Completely restart Claude Code (not just close the window)
3. Start a new conversation

### Runtime Issues

#### Status line shows nothing

Check the script output manually:
```bash
echo '{}' | ~/.claude/statusline-with-tokens.sh
```

If this produces an error, the script may be corrupted. Re-download it.

#### Token counter missing

The token part is hidden until Claude Code sends `context_window` data:
- Brand new conversations show it after the first response
- Claude Code older than 2.1.6 never sends it - update Claude Code

If it persists, check `jq` is installed (`which jq`) and the script is executable.

#### Session/Week limits missing

`rate_limits` is only sent for Pro/Max subscriptions, and only after the first API response in a session. API-key users won't see it.

#### Upgrading from ≤ 1.4.0

Old versions left per-session cache files behind. Safe to delete:
```bash
rm -f ~/.claude/.token-cache-* ~/.claude/statusline-debug.json
```

### Getting Help

If you encounter issues not covered here:

1. Check [TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) for more detailed solutions
2. Review [ARCHITECTURE.md](docs/ARCHITECTURE.md) for technical details
3. [Open an issue](https://github.com/lukaskraic/claude-status-line/issues) on GitHub

## Advanced Configuration

### Custom Installation Location

If you want to install the script elsewhere:

1. **Copy script to your preferred location**:
   ```bash
   cp statusline-with-tokens.sh /your/custom/path/
   chmod +x /your/custom/path/statusline-with-tokens.sh
   ```

2. **Update settings.json** with the full path:
   ```json
   {
     "statusLine": {
       "type": "command",
       "command": "/your/custom/path/statusline-with-tokens.sh"
     }
   }
   ```

### Customizing Display

Variables at the top of the script:
- `AUTOCOMPACT_BUFFER` / `AUTOCOMPACT_BUFFER_MANUAL` - auto-compact buffer
- `RATE_LIMIT_WARN_PCT` - when session/week limits get a `⚠`

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for details.

## Support

- **Documentation**: See [README.md](README.md)
- **Issues**: Report bugs at [GitHub Issues](https://github.com/lukaskraic/claude-status-line/issues)
- **Updates**: Check [CHANGELOG.md](CHANGELOG.md) for version history
