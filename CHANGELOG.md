# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
