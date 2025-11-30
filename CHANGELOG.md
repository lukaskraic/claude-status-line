# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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

### Technical Details
- Auto-detection correctly handles disabled MCP servers
- Excludes servers with `"disabled": true` from count
- Falls back to safe defaults if jq parsing fails or settings missing
- Maintains backward compatibility with manual override option

**Why**: Eliminates need for users to manually configure system overhead. The script now automatically adapts to your MCP setup, providing accurate token counts out of the box while still allowing manual fine-tuning when needed.

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
