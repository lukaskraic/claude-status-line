# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.6.0] - 2026-09-21

### Fixed
- **Autocompact buffer was wrong and in the wrong place.** The constant was 45k;
  measured on Claude Code 2.1.278 it is **33k**, fixed, on a 200k and a 1M window
  alike. More importantly the buffer belongs in the denominator, not the
  numerator: auto-compact fires at `context_window_size - buffer`, so usage is now
  measured against that effective window instead of being inflated by 45k.
- Percentage is capped at 100% instead of the token count being capped at the
  window size, so the display degrades sensibly when usage briefly exceeds the
  effective window before auto-compact runs.
- Empty fields no longer shift every value after them. The single `jq` pass joins
  on `\u001f`; it previously used `@tsv`, and tab is IFS whitespace, so bash
  collapsed empty fields.
- `git` is no longer invoked when `cwd` is empty or not a directory — a malformed
  payload used to report the branch of whatever directory the script ran in.
- `jq`'s `//` treats `false` as absent, so `autoCompactEnabled: false` was silently
  ignored. Replaced with an explicit null test.

### Changed
- **Denominator is now the effective window.** On a 1M window the status line reads
  `750k/967k (78%)` where `/context` reads `750k/1m (75%)`. Both are correct; this
  one answers "how close am I to auto-compact".
- Token source priority is now `total_input_tokens` → sum of `current_usage` →
  `used_percentage × context_window_size`. The first two are exact;
  `used_percentage` is rounded to whole percent, which is 10k of granularity on a
  1M window.
- When the payload carries no `context_window` at all (Claude Code older than
  2.1.6), the token segment is omitted rather than estimated.
- Status line is now derived entirely from the payload — no state, no disk writes.

### Added
- Auto-compact buffer honours your configuration, first match wins:
  `AUTOCOMPACT_BUFFER_MANUAL` → `CLAUDE_CODE_AUTO_COMPACT_WINDOW` →
  `autoCompactWindow` → `autoCompactEnabled: false` → the 33k default.
  Window values accept `500000`, `500k` and `1m`.
- Rate limit segment: ` · 5h NN% 7d NN%`, appended once either account window
  crosses `RATE_LIMIT_WARN_PCT` (default 80). Set it to 101 to disable.

### Removed
- **MCP-based system overhead estimation** (`detect_mcp_servers`,
  `SYSTEM_OVERHEAD_MANUAL`, ~50 lines). It guessed 24k-104k from a server count;
  on a real config it returned 34k where `/context` reported 643 tokens of MCP
  tools. The payload reports exact counts, so there is nothing left to estimate.
- **Per-session cache** (`~/.claude/.token-cache-{session_id}`). The API always
  provides data; the cache only ever served stale numbers. Existing files are not
  cleaned up automatically — `rm -f ~/.claude/.token-cache-*`.
- **Debug dump** to `~/.claude/statusline-debug.json`, which was marked temporary
  and ran on every single status line refresh.
- **Transcript parsing fallback**, superseded by `context_window` since 2.1.6.

### Technical Details
- Script is 145 lines, down from 210, and passes `shellcheck -S warning` clean
- 25-case test suite covering the math, buffer overrides, degraded input and git
- Targets bash 3.2 (macOS system bash): no `${var,,}`, no `mapfile`
- Verified against `/context` on 2.1.278 across 200k and 1M windows

**Why**: the status line overstated usage by a flat 45k. On a 1M window that is
~5 percentage points; on a 200k window, 75% real usage displayed as 98%.

## [1.5.0] - 2026-02-20

### Changed
- **Token source rewrite**: Now uses official `context_window` API (Claude Code 2.1.6+)
- Priority chain: `used_percentage` > `current_usage` > transcript parsing > cache
- Removed fragile transcript directory scanning (~30 lines removed)
- Kept single-file transcript parsing as legacy fallback for pre-2.0.70

### Fixed
- Removed dead code reading `.context.usage.total` (field never existed in API)
- Token display no longer depends on transcript file format stability

### Technical Details
- `used_percentage` includes system overhead (cached in `cache_read_input_tokens`)
- Only autocompact buffer (45k) is added on top (not included in API metrics)
- System overhead auto-detection still used for zero-data fallback (after `/clear`)
- Capped at budget to prevent >100% display

## [1.4.0] - 2024-12-04

### Fixed
- **Major accuracy improvement**: Token counting now matches `/context` output with 99.2% accuracy
- Fixed formula to properly account for Claude Code 2.0+ autocompact buffer (constant 45k tokens)
- Removed double-counting of `input_tokens` and `output_tokens` (already included in cache metrics)
- Token counts now typically within 1-2k tokens of `/context` output

### Added
- `AUTOCOMPACT_BUFFER` constant (45k tokens) - Claude Code 2.0+ reserved space
- Prioritized `~/.claude.json` for MCP detection (most common location for Claude Code CLI)
- Updated token calculation formula: `cache_read + cache_creation + autocompact_buffer`

### Changed
- MCP configuration detection now checks `~/.claude.json` first (before `~/.claude/settings.json`)
- After `/clear`, minimum is now `system_overhead + autocompact_buffer` (was just `system_overhead`)
- Documentation updated to explain autocompact buffer and accurate formula

### Technical Details
- Old formula: `cache_read + cache_creation + input + output + system_overhead` (double-counted tokens)
- New formula: `cache_read + cache_creation + 45000` (accurate)
- Autocompact buffer persists even after `/clear` command
- Reference: [GitHub Issue #10266](https://github.com/anthropics/claude-code/issues/10266)
- Discovered that Claude Code status line API doesn't provide token counts (must parse transcript)

**Why**: Previous implementation had 50-60k token discrepancy due to double-counting and missing the autocompact buffer. New implementation achieves 99.2% accuracy by using the correct formula and accounting for the constant 45k reservation that Claude Code 2.0+ always maintains.

## [1.3.0] - 2024-12-03

### Added
- **Multi-location MCP configuration detection** with fallback mechanism
- Support for Claude Desktop global config: `~/Library/Application Support/Claude/claude_desktop_config.json`
- Automatic fallback from project-specific to global MCP configuration
- Dynamic MCP server count detection (updates automatically when MCP servers are disabled/enabled)

### Changed
- `detect_mcp_servers()` now tries multiple configuration locations:
  1. `~/.claude/settings.json` (project-specific)
  2. `~/Library/Application Support/Claude/claude_desktop_config.json` (global)
- System overhead detection now works correctly with Claude Desktop MCP configuration
- Configuration comments updated to reflect new multi-location detection

### Fixed
- **Critical fix:** Auto-detection now works with Claude Desktop MCP configuration
- Previously, auto-detection only checked `~/.claude/settings.json`, causing it to miss global MCP servers
- Users with many MCP servers (e.g., 17) now get accurate overhead estimation (104k instead of 24k default)
- Status line percentages are now significantly more accurate for users with multiple MCP servers

### Technical Details
- MCP count detection refreshes every ~300ms (status line update interval)
- No caching between calls - changes to MCP configuration are reflected immediately
- Minimal performance impact: ~10-15ms per status line update
- Supports disabling/enabling MCP servers during runtime without restart

## [1.2.0] - 2024-11-30

### Added
- **Automatic system overhead detection** based on MCP server configuration
- `detect_mcp_servers()` function that reads `~/.claude/settings.json`
- Smart overhead estimation based on enabled MCP server count:
  - 0 servers: 24k tokens (base overhead)
  - 1-2 servers: 34k tokens
  - 3-4 servers: 54k tokens
  - 5-6 servers: 74k tokens
  - 7+ servers: 104k tokens
- Graceful fallbacks for missing or malformed settings files
- Manual override option via `SYSTEM_OVERHEAD_MANUAL` for fine-tuning

### Changed
- System overhead is now auto-detected by default (previously hardcoded to 30k)
- Updated configuration comments to explain auto-detection and manual override
- README documentation updated with auto-detection details and calibration guide
- Customization section updated to reference new detection mechanism

### Fixed
- After `/clear` command, status line now shows system overhead as minimum instead of 0k
- This matches `/context` behavior which always includes system overhead
- Provides more accurate representation of actual context usage

### Technical Details
- Auto-detection correctly handles disabled MCP servers
- Excludes servers with `"disabled": true` from count
- Falls back to safe defaults if jq parsing fails or settings missing
- Maintains backward compatibility with manual override option
- When no conversation data exists (after `/clear`), displays system overhead as baseline

**Why**: Eliminates need for users to manually configure system overhead. The script now automatically adapts to your MCP setup, providing accurate token counts out of the box while still allowing manual fine-tuning when needed. The `/clear` fix ensures the status line always shows a realistic minimum token count.

## [1.1.0] - 2024-11-29

### Changed
- Adjusted threshold percentages to align with Claude Code auto-compact behavior:
  - Safe: 0-74% (was 0-49%)
  - Warning: 75-89% (was 50-79%)
  - Critical: 90-100% (was 80-100%)
- Critical threshold now triggers just before auto-compact (~92%)

### Added
- Configurable `SYSTEM_OVERHEAD` variable for adjusting system component estimation
- Documentation of recommended overhead values based on MCP server setup (25k-103k)

### Fixed
- Token count calculation now includes `cache_creation_input_tokens`
- Added system overhead estimation (system prompt, tools, MCP, agents, memory)
- Status line now closely matches `/context` command output
- Previously showed ~30k-100k fewer tokens due to missing system components

### Changed
- System overhead is now user-configurable (default: 30k tokens)
- Users can adjust `SYSTEM_OVERHEAD` variable to match their `/context` output

### Why
- Previous thresholds showed warning too early (at 50%)
- New thresholds better reflect Claude Code's auto-compact behavior
- Users get critical warning when auto-compact is imminent
- Reduces alarm fatigue by showing warning only when approaching actual limit
- Token counting now matches Claude Code's internal calculation

**BREAKING CHANGE**: Threshold percentages changed. Warning threshold moved from 50% to 75% to better reflect actual auto-compact behavior.

## [1.0.0] - 2024-11-29

### Added
- Initial release of Claude Code status line with token counter
- Per-window token tracking using session-based cache isolation
- Visual indicators for token usage:
  - ✓ Safe (<50% usage)
  - ⚠ Warning (50-80% usage)
  - ⚠⚠ Critical (>80% usage)
- Intelligent 3-tier fallback system:
  - Primary: JSON data from Claude Code
  - Secondary: Transcript file parsing
  - Tertiary: Session cache file
- Git branch integration (shows current branch when in repository)
- Model name display (shows which Claude model is active)
- Compact human-readable format (e.g., "45k/200k" instead of "45000/200000")
- Home directory expansion (shows ~ instead of /Users/username)
- Session persistence through cache files
- Comprehensive documentation:
  - README with quick start
  - INSTALL guide with detailed instructions
  - ARCHITECTURE technical documentation
  - TROUBLESHOOTING guide
  - Example configurations

### Fixed
- Multi-window shared counter issue (each window now has independent tracking)
- Token count persistence across transcript parsing failures

### Technical Details
- Uses `session_id` from Claude Code JSON input for per-window isolation
- Cache files stored as `~/.claude/.token-cache-{session_id}`
- Requires `jq` for JSON parsing
- Bash script with POSIX compliance
- Zero external dependencies beyond jq

## [Unreleased]

### Planned Features
- Color customization options
- Configurable threshold percentages
- Additional display modes (minimal, verbose)
- Token usage history tracking
- Estimated context remaining time

---

For upgrade instructions, see [INSTALL.md](INSTALL.md#upgrading).

For detailed technical changes, see the [commit history](https://github.com/lukaskraic/claude-status-line/commits/main).
