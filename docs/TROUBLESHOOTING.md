# Troubleshooting Guide

Common issues with Claude Code Status Line with Token Counter.

## Table of Contents

- [Installation Issues](#installation-issues)
- [Token Counter Issues](#token-counter-issues)
- [Display Issues](#display-issues)
- [Git Integration Issues](#git-integration-issues)
- [Leftovers From Older Versions](#leftovers-from-older-versions)
- [General Debugging](#general-debugging)
- [Getting Help](#getting-help)

## Installation Issues

### Script not found

**Symptoms**: Status line is blank, or Claude Code logs a missing command.

```bash
ls -l ~/.claude/statusline-with-tokens.sh
```

If it is not there, reinstall:

```bash
curl -o ~/.claude/statusline-with-tokens.sh \
  https://raw.githubusercontent.com/lukaskraic/claude-status-line/main/statusline-with-tokens.sh
chmod +x ~/.claude/statusline-with-tokens.sh
```

Check that `~/.claude/settings.json` points at the same path:

```bash
jq '.statusLine' ~/.claude/settings.json
```

### Permission denied

```bash
chmod +x ~/.claude/statusline-with-tokens.sh
```

### jq command not found

```bash
brew install jq        # macOS
sudo apt install jq    # Debian/Ubuntu
sudo dnf install jq    # Fedora/RHEL
```

Without `jq` the script prints the directory and ` [?]` and nothing else.

### bash too old

The script targets bash 3.2, the version macOS ships, so it avoids `${var,,}`,
associative arrays and `mapfile`. If you edit it, keep to that baseline or change
the shebang.

```bash
bash --version
```

## Token Counter Issues

### Token segment missing entirely

The script omits the token segment — deliberately — when the payload carries no
`context_window` object, rather than displaying a guess.

1. **Check your Claude Code version.** `context_window` arrives in 2.1.6:

   ```bash
   claude --version
   ```

   Upgrade if you are older than that.

2. **Check `jq` is installed and the script is executable** (see above).

3. **Confirm the script works on a synthetic payload**:

   ```bash
   echo '{"workspace":{"current_dir":"'"$PWD"'"},"model":{"display_name":"Test"},
          "context_window":{"context_window_size":200000,"total_input_tokens":100000}}' \
     | ~/.claude/statusline-with-tokens.sh
   # ~/your/dir (main) [Test] ✓ 100k/167k (60%)
   ```

   If that works but the live status line does not, the payload is the problem,
   not the script — capture it (see [General Debugging](#general-debugging)).

### Numbers don't match `/context`

**They are not supposed to match exactly.** `/context` measures usage against the
full context window; this script measures it against the effective window, which
is the full window minus the auto-compact buffer.

On a 1M window with 750k used:

| | Numerator | Denominator | Shows |
|---|---|---|---|
| `/context` | 750k | 1000k | 75% |
| this script | 750k | 967k | 78% |

The **token count** should match. If it does not, compare the "Autocompact buffer"
row in `/context` with `AUTOCOMPACT_BUFFER` at the top of the script:

```bash
grep '^AUTOCOMPACT_BUFFER=' ~/.claude/statusline-with-tokens.sh
```

Anthropic has changed this constant before — it was 45,000 before early 2026 and
is 33,000 as of 2.1.278. Edit the constant if `/context` disagrees.

### Percentage seems too high

If you have turned auto-compact off, the buffer does not apply and the script
should be using the full window. It reads that from your settings:

```bash
jq '{autoCompactEnabled, autoCompactWindow}' ~/.claude/settings.json
```

- `autoCompactEnabled: false` → no buffer, full window is the budget
- `autoCompactWindow: "500k"` → effective window is 500k regardless of the model
- both `null` → default 33k buffer

`CLAUDE_CODE_AUTO_COMPACT_WINDOW` in the environment overrides the setting.

### Percentage stuck at 100%

Usage genuinely exceeded the effective window and auto-compact has not run yet.
The script caps the display at 100% rather than showing `103%`. Run `/compact`.

### Token count not updating

Claude Code refreshes the status line on events (assistant message, `/compact`,
permission change, vim mode toggle, rate limit reset) and debounces at 300ms. It
does not tick on a timer unless you configure `refreshInterval` in
`settings.json`. Between turns, a static number is expected.

## Display Issues

### Status line not appearing

1. Verify the settings block:

   ```bash
   jq '.statusLine' ~/.claude/settings.json
   # {"type":"command","command":"~/.claude/statusline-with-tokens.sh"}
   ```

2. Restart Claude Code — `statusLine` is read at startup.

3. Check the script does not error:

   ```bash
   echo '{}' | ~/.claude/statusline-with-tokens.sh
   #  [?]
   ```

### Garbled characters

The indicators `✓`, `⚠` and `·` are UTF-8. If they render as boxes or question
marks:

```bash
locale  # LANG and LC_ALL should end in .UTF-8
```

Set a UTF-8 locale in your shell profile, or replace the glyphs in the script with
ASCII (`OK`, `!`, `!!`).

### Status line too long

Shorten it by editing the final `printf`. Dropping the directory, for example:

```bash
printf "%s [%s]%s%s" "$git_branch" "$model" "$tokens_display" "$limits_display"
```

To suppress the rate limit segment, set `RATE_LIMIT_WARN_PCT=101`.

## Git Integration Issues

### Git branch not showing

The branch is omitted when `cwd` is not a directory, is not a git repository, or
the repository has no current branch (detached HEAD).

```bash
git -C "$PWD" branch --show-current
```

An empty result with no error means detached HEAD — expected during a rebase or
bisect.

### Wrong git branch showing

The script reads `workspace.current_dir` (falling back to `cwd`) from the payload,
not your shell's directory. With `/add-dir` in play, or in a worktree, those can
differ from where you launched Claude Code.

## Leftovers From Older Versions

v1.6.0 removed the per-session cache and the debug dump. Neither is written any
more, but old files are not cleaned up automatically:

```bash
ls ~/.claude/.token-cache-* 2>/dev/null | wc -l
rm -f ~/.claude/.token-cache-*
rm -f ~/.claude/statusline-debug.json
```

The MCP-based system overhead estimation (`detect_mcp_servers`,
`SYSTEM_OVERHEAD_MANUAL`) is also gone — the payload now reports exact token
counts, so there is nothing left to estimate. If you had set
`SYSTEM_OVERHEAD_MANUAL`, drop it; the equivalent knob is now
`AUTOCOMPACT_BUFFER_MANUAL`, and it means something different.

## General Debugging

### Capture a real payload

Claude Code does not run the status line in headless (`claude -p`) mode, so the
payload can only be captured from an interactive session. Point `statusLine` at a
wrapper:

```bash
cat > ~/.claude/statusline-debug-wrapper.sh <<'EOF'
#!/bin/bash
tee ~/.claude/statusline-payload.json | ~/.claude/statusline-with-tokens.sh
EOF
chmod +x ~/.claude/statusline-debug-wrapper.sh
```

Point `settings.json` at the wrapper, restart Claude Code, then inspect:

```bash
jq '.context_window' ~/.claude/statusline-payload.json
```

Remember to point `settings.json` back afterwards.

### Replay a captured payload

```bash
cat ~/.claude/statusline-payload.json | ~/.claude/statusline-with-tokens.sh
```

### Check file integrity

```bash
head -1 ~/.claude/statusline-with-tokens.sh   # #!/bin/bash
bash -n ~/.claude/statusline-with-tokens.sh   # silent if valid
```

## Common Error Messages

### `parse error: Invalid numeric literal`

`jq` received something that is not JSON. If this appears while testing by hand,
check your quoting — `$PWD` must be inside double quotes:

```bash
echo '{"workspace":{"current_dir":"'"$PWD"'"}}' | jq .
```

In normal operation the script suppresses `jq` errors and degrades to ` [?]`.

### `syntax error near unexpected token`

The script was truncated or corrupted during download. Reinstall with `curl -o`
and verify with `bash -n`.

## Getting Help

Open an issue at
[github.com/lukaskraic/claude-status-line/issues](https://github.com/lukaskraic/claude-status-line/issues)
with:

- `claude --version`
- `bash --version` and `jq --version`
- the output of `echo '{}' | ~/.claude/statusline-with-tokens.sh`
- the `context_window` object from a captured payload
- the relevant rows from `/context`
