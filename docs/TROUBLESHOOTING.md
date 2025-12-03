# Troubleshooting Guide

Common issues and solutions for Claude Code Status Line with Token Counter.

## Table of Contents

- [Installation Issues](#installation-issues)
- [Token Counter Issues](#token-counter-issues)
- [Display Issues](#display-issues)
- [Performance Issues](#performance-issues)
- [Cache Issues](#cache-issues)
- [Git Integration Issues](#git-integration-issues)
- [General Debugging](#general-debugging)

## Installation Issues

### Script not found

**Symptoms**: Error message "command not found: statusline-with-tokens.sh"

**Solutions**:
1. Verify script exists:
   ```bash
   ls -l ~/.claude/statusline-with-tokens.sh
   ```

2. If missing, reinstall:
   ```bash
   curl -o ~/.claude/statusline-with-tokens.sh \
     https://raw.githubusercontent.com/lukaskraic/claude-status-line/main/statusline-with-tokens.sh
   chmod +x ~/.claude/statusline-with-tokens.sh
   ```

3. Check settings.json path is correct:
   ```bash
   cat ~/.claude/settings.json | jq '.statusLine'
   ```

### Permission denied

**Symptoms**: "Permission denied" when Claude Code tries to run script

**Solutions**:
1. Make script executable:
   ```bash
   chmod +x ~/.claude/statusline-with-tokens.sh
   ```

2. Verify permissions:
   ```bash
   ls -l ~/.claude/statusline-with-tokens.sh
   # Should show: -rwxr-xr-x
   ```

3. If still failing, check file ownership:
   ```bash
   ls -l ~/.claude/statusline-with-tokens.sh
   # Owner should be your username
   ```

### jq command not found

**Symptoms**: Error "jq: command not found" in Claude Code

**Solutions**:
1. Install jq:
   ```bash
   # macOS
   brew install jq

   # Linux (Ubuntu/Debian)
   sudo apt install jq

   # Linux (Fedora/RHEL)
   sudo dnf install jq
   ```

2. Verify installation:
   ```bash
   which jq
   # Should output: /usr/local/bin/jq or similar
   ```

3. Test jq:
   ```bash
   echo '{"test": "value"}' | jq .
   # Should output formatted JSON
   ```

## MCP Configuration Issues

### Auto-detection not finding MCP servers

**Symptoms**: Status line shows very low system overhead (24k) despite having many MCP servers configured

**Possible Causes**:
1. MCP servers configured in a location the script doesn't check
2. MCP configuration file has incorrect JSON syntax
3. All MCP servers are disabled

**Solutions**:
1. **Verify MCP configuration location**:

   The script checks two locations (in order):
   ```bash
   # Location 1: Project-specific (checked first)
   ls -l ~/.claude/settings.json
   cat ~/.claude/settings.json | jq '.mcpServers'

   # Location 2: Global Claude Desktop config (fallback)
   ls -l ~/Library/Application\ Support/Claude/claude_desktop_config.json
   cat ~/Library/Application\ Support/Claude/claude_desktop_config.json | jq '.mcpServers'
   ```

2. **Verify MCP server count**:
   ```bash
   # Check enabled MCP servers in Claude Desktop config
   jq '.mcpServers | to_entries | map(select(.value.disabled != true)) | length' \
     ~/Library/Application\ Support/Claude/claude_desktop_config.json
   ```

3. **Test auto-detection manually**:
   ```bash
   # Run detection function directly
   bash -c 'source ~/.claude/statusline-with-tokens.sh && detect_mcp_servers'
   # Should output: 24000, 34000, 54000, 74000, or 104000
   ```

4. **Common scenarios**:
   - **0-2 MCP servers**: 24k-34k overhead (normal for minimal setup)
   - **3-6 MCP servers**: 54k-74k overhead (moderate setup)
   - **7+ MCP servers**: 104k overhead (comprehensive setup like memory, github, playwright, etc.)

### MCP configuration in unexpected location

**Symptoms**: Auto-detection returns 24k but you have MCP servers configured elsewhere

**Solutions**:
1. **Use manual override** (temporary fix):
   ```bash
   # Edit ~/.claude/statusline-with-tokens.sh
   # Uncomment and set based on your MCP count:
   SYSTEM_OVERHEAD_MANUAL=104000  # For 7+ servers
   ```

2. **Copy MCP config to supported location**:
   ```bash
   # If your MCP servers are in ~/.config/claude/ or elsewhere,
   # add them to ~/.claude/settings.json:
   jq '.mcpServers = {...}' ~/.claude/settings.json
   ```

### Dynamic MCP detection not working

**Symptoms**: After disabling/enabling MCP servers, status line still shows old overhead

**Possible Causes**:
1. Configuration file cached by OS
2. Script not refreshing configuration

**Solutions**:
1. **Wait 1-2 seconds**: Detection refreshes every ~300ms with status line

2. **Verify configuration change**:
   ```bash
   # Add "disabled": true to an MCP server
   jq '.mcpServers.memory.disabled = true' \
     ~/Library/Application\ Support/Claude/claude_desktop_config.json

   # Check count decreased
   bash -c 'source ~/.claude/statusline-with-tokens.sh && detect_mcp_servers'
   ```

3. **Test with different MCP counts**:
   ```bash
   # Disable 10 servers temporarily
   # Before: 17 servers → 104k overhead
   # After: 7 servers → 104k overhead (still 7+)
   # After: 3 servers → 54k overhead
   ```

## Token Counter Issues

### Token counter shows 0

**Symptoms**: Status line displays "0k/200k (0%)" even during active conversation

**Possible Causes**:
1. Brand new conversation (no tokens used yet)
2. Claude Code hasn't provided token data yet
3. All 3 fallback tiers failed

**Solutions**:
1. **Wait for first response**: Token counter updates after Claude's first response

2. **Check JSON input**:
   ```bash
   # Add debug logging to script (temporary)
   # Add this after line 4 in statusline-with-tokens.sh:
   echo "$input" > /tmp/statusline-input.json

   # Then check:
   cat /tmp/statusline-input.json | jq '.context.usage.total'
   ```

3. **Check transcript file**:
   ```bash
   # Find transcript path
   cat /tmp/statusline-input.json | jq -r '.transcript_path'

   # Check last line
   tail -1 /path/to/transcript.jsonl | jq '.message.usage'
   ```

4. **Check cache file**:
   ```bash
   # Find session_id
   cat /tmp/statusline-input.json | jq -r '.session_id'

   # Check cache
   cat ~/.claude/.token-cache-{session_id}
   ```

5. **Force cache reset**:
   ```bash
   rm ~/.claude/.token-cache-*
   # Restart conversation
   ```

### Token counter not updating

**Symptoms**: Counter shows same value even after new messages

**Solutions**:
1. **Check if stuck on cache**: Cache may be preventing updates

   Delete cache files:
   ```bash
   rm ~/.claude/.token-cache-*
   ```

2. **Verify script is running**: Test manually
   ```bash
   echo '{"session_id":"test","context":{"usage":{"total":100000},"budget":{"limit":200000}}}' | ~/.claude/statusline-with-tokens.sh
   # Should output: ... ⚠ 100k/200k (50%)
   ```

3. **Check Claude Code logs**: Look for errors in Claude Code output

### Incorrect token count

**Symptoms**: Token count doesn't match expected usage

**Possible Causes**:
1. Cache is stale
2. Using token count from different window
3. Transcript parsing is pulling old data

**Solutions**:
1. **Clear cache**:
   ```bash
   rm ~/.claude/.token-cache-*
   ```

2. **Verify session isolation**:
   ```bash
   # List all cache files
   ls -la ~/.claude/.token-cache-*

   # Should see different files for different windows
   ```

3. **Force JSON-only mode** (temporary debug):
   Edit script to disable fallbacks (lines 33-66), force using only JSON input

## Display Issues

### Status line not appearing

**Symptoms**: No status line visible at all

**Solutions**:
1. **Check settings.json syntax**:
   ```bash
   jq . ~/.claude/settings.json
   # Should output valid JSON without errors
   ```

2. **Verify statusLine configuration**:
   ```bash
   cat ~/.claude/settings.json | jq '.statusLine'
   # Should show:
   # {
   #   "type": "command",
   #   "command": "~/.claude/statusline-with-tokens.sh"
   # }
   ```

3. **Test script output**:
   ```bash
   echo '{}' | ~/.claude/statusline-with-tokens.sh
   # Should produce some output
   ```

4. **Restart Claude Code**: Completely exit and relaunch

### Garbled characters

**Symptoms**: Strange symbols or broken characters in status line

**Possible Causes**:
1. Terminal doesn't support Unicode
2. Font doesn't include needed characters (✓, ⚠)

**Solutions**:
1. **Use different terminal**: Some terminals have better Unicode support

2. **Change font**: Use a Unicode-complete font like:
   - Menlo
   - Monaco
   - SF Mono
   - FiraCode Nerd Font

3. **Replace indicators** in script (lines 88-96):
   ```bash
   # Instead of ✓ ⚠ ⚠⚠, use:
   status="OK"        # Safe
   status="WARN"      # Warning
   status="CRIT"      # Critical
   ```

### Status line too long

**Symptoms**: Status line wraps to next line

**Solutions**:
1. **Shorten directory path**: Already uses ~ expansion

2. **Remove git branch**: Comment out lines 18-25

3. **Abbreviate model name**: Modify line 15:
   ```bash
   model=$(echo "$input" | jq -r '.model.display_name' | sed 's/Claude /C-/')
   # "Claude Sonnet 4.5" → "C-Sonnet 4.5"
   ```

4. **Remove percentage**: Modify line 99:
   ```bash
   tokens_display=" ${status} ${tokens_k}k/${budget_k}k"
   # Removes (XX%) part
   ```

## Performance Issues

### Status line updates slowly

**Symptoms**: Noticeable delay when updating status line

**Possible Causes**:
1. Slow git operations in large repositories
2. Transcript file is very large
3. Disk I/O bottleneck

**Solutions**:
1. **Disable git branch** (if not needed):
   Comment out lines 18-25 in script

2. **Skip transcript parsing**:
   Comment out lines 33-66 to rely only on JSON + cache

3. **Use SSD**: If on HDD, consider moving `.claude` to SSD

### High CPU usage

**Symptoms**: Script uses significant CPU

**This is unusual** - the script should be very light on CPU.

**Debug steps**:
1. **Check for infinite loops**: Review any custom modifications

2. **Monitor execution**:
   ```bash
   time echo '{}' | ~/.claude/statusline-with-tokens.sh
   # Should complete in < 100ms
   ```

3. **Check jq performance**:
   ```bash
   time echo '{"test": "value"}' | jq .
   # Should be instant
   ```

## Cache Issues

### Multiple windows show same count (pre-v1.0.0)

**Symptoms**: All Claude Code windows display identical token counts

**This was fixed in v1.0.0**

**Solutions**:
1. **Upgrade to latest version**:
   ```bash
   curl -o ~/.claude/statusline-with-tokens.sh \
     https://raw.githubusercontent.com/lukaskraic/claude-status-line/main/statusline-with-tokens.sh
   chmod +x ~/.claude/statusline-with-tokens.sh
   ```

2. **Verify session-based caching**:
   ```bash
   # Check that cache files use session_id
   grep "session_id" ~/.claude/statusline-with-tokens.sh
   # Should show line extracting session_id

   grep "CACHE_FILE" ~/.claude/statusline-with-tokens.sh
   # Should show: CACHE_FILE="$HOME/.claude/.token-cache-${session_id}"
   ```

3. **Clean old cache**:
   ```bash
   rm ~/.claude/.last-token-count  # Old shared cache
   rm ~/.claude/.token-cache-*     # Start fresh
   ```

### Cache files accumulating

**Symptoms**: Many `.token-cache-*` files in `~/.claude/`

**This is normal** - one file per session

**Cleanup**:
```bash
# Safe cleanup - remove caches older than 7 days
find ~/.claude -name '.token-cache-*' -mtime +7 -delete

# Nuclear option - remove all (will regenerate)
rm ~/.claude/.token-cache-*
```

### Cache shows wrong data

**Symptoms**: Cache contains unexpected token count

**Solutions**:
1. **Delete cache**:
   ```bash
   rm ~/.claude/.token-cache-*
   ```

2. **Verify cache update logic**:
   Check lines 77-79 in script - should only update with valid data

## Git Integration Issues

### Git branch not showing

**Symptoms**: No branch name even when in git repository

**Solutions**:
1. **Verify you're in git repo**:
   ```bash
   git status
   # Should not error
   ```

2. **Check git is installed**:
   ```bash
   which git
   # Should output: /usr/bin/git or similar
   ```

3. **Check you're on a branch**:
   ```bash
   git branch --show-current
   # Should output branch name
   ```

4. **Enable git in script**: Check lines 18-25 are not commented

### Wrong git branch showing

**Symptoms**: Branch name doesn't match current branch

**Possible Causes**:
1. Script runs in different directory
2. Git operations are cached

**Solutions**:
1. **Verify directory detection**:
   ```bash
   echo '{"workspace":{"current_dir":"'$(pwd)'"}}' | \
     ~/.claude/statusline-with-tokens.sh
   ```

2. **Force git cache refresh**: Restart Claude Code

## General Debugging

### Enable debug logging

Add to script (after line 4):

```bash
# Debug log file
DEBUG_LOG="/tmp/statusline-debug.log"

# Log input JSON
echo "=== $(date) ===" >> "$DEBUG_LOG"
echo "$input" >> "$DEBUG_LOG"

# Log extracted values
echo "tokens=$tokens budget=$budget session_id=$session_id" >> "$DEBUG_LOG"
```

Then check log:
```bash
tail -f /tmp/statusline-debug.log
```

### Test script manually

```bash
# Minimal test
echo '{}' | ~/.claude/statusline-with-tokens.sh

# Full test
echo '{"session_id":"test","workspace":{"current_dir":"'$(pwd)'"},"model":{"display_name":"Test Model"},"context":{"usage":{"total":45000},"budget":{"limit":200000}}}' | ~/.claude/statusline-with-tokens.sh

# Expected output:
# ~/current/directory [Test Model] ✓ 45k/200k (22%)
```

### Verify jq queries

```bash
# Test jq extraction
echo '{"context":{"usage":{"total":45000}}}' | \
  jq -r '.context.usage.total'
# Should output: 45000
```

### Check file integrity

```bash
# Verify script hasn't been corrupted
head -1 ~/.claude/statusline-with-tokens.sh
# Should show: #!/bin/bash

# Check for syntax errors
bash -n ~/.claude/statusline-with-tokens.sh
# Should output nothing if valid
```

## Getting Help

If none of these solutions work:

1. **Check version**:
   ```bash
   head -20 ~/.claude/statusline-with-tokens.sh | grep -i version
   ```

2. **Review documentation**:
   - [README.md](../README.md) - Overview and features
   - [INSTALL.md](../INSTALL.md) - Installation instructions
   - [ARCHITECTURE.md](ARCHITECTURE.md) - Technical details

3. **Report an issue**: [GitHub Issues](https://github.com/lukaskraic/claude-status-line/issues)

   Include:
   - Operating system and version
   - Claude Code version
   - Script version (from file)
   - Output of manual test (above)
   - Relevant error messages
   - Debug log if available

## Common Error Messages

### "syntax error near unexpected token"

**Cause**: Bash syntax error in script

**Solution**: Script may be corrupted, reinstall:
```bash
curl -o ~/.claude/statusline-with-tokens.sh \
  https://raw.githubusercontent.com/lukaskraic/claude-status-line/main/statusline-with-tokens.sh
chmod +x ~/.claude/statusline-with-tokens.sh
```

### "parse error: Invalid numeric literal"

**Cause**: jq received invalid JSON

**Solution**: Check JSON input is valid:
```bash
# Add debug logging (see above)
# Then check:
cat /tmp/statusline-input.json | jq .
```

### "No such file or directory"

**Cause**: Script trying to access non-existent file

**Solution**: Check cache directory exists:
```bash
mkdir -p ~/.claude
```

## Best Practices

1. **Keep script updated**: Check for new versions periodically
2. **Clean cache regularly**: Remove old cache files
3. **Monitor performance**: If status line slows down, investigate
4. **Report bugs**: Help improve the project by reporting issues
5. **Read changelog**: Stay informed about fixes and new features
