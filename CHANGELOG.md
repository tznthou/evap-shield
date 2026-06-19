# Changelog

[中文](CHANGELOG_ZH.md)

All notable changes to evap-shield are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). This project groups changes by date rather than semantic version — it's a script toolkit, not a registry-published package.

## [Unreleased]

### Changed

- README (EN/ZH): documented the version-agnostic patcher — the 1-byte structural patch (previously described as a 2-byte literal), the 45-test patcher suite, and the 2.1.181 Bun 1.4 note.

## 2026-06-19

### Changed

- Bumped the tested badge to **2.1.183**. After Claude Code updated 2.1.181 → 2.1.183 (2.1.182 was skipped), a three-way binary diff confirms the upstream parser is byte-for-byte identical to 2.1.181 once identifiers are normalized — this time the minifier didn't even reshuffle names (still `l/n/a`) — so VH1 remains unpatched upstream. None of 2.1.183's sixteen changelog entries touch tool-call parsing. The version-agnostic patcher re-applied with no script change (`!l`→`!0`, one byte).

## 2026-06-18

### Added

- VH1 bug investigation writeup (`docs/vh1-investigation.md`), including a 2.1.181 re-check that confirms the bug remains unpatched upstream.

### Changed

- The VH1 patcher is now **version-agnostic**: a structural anchor on the parser's invariant replaces the hardcoded minified variable pattern, so it survives bundler/minifier reshuffles across Claude Code versions — verified across the 2.1.181 Bun 1.4 identifier rename.

## 2026-06-17

### Added

- Patcher failure-path regression suite (`test-patch-vh1.sh`) and installer merge-safety suite (`test-install.sh`).

### Changed

- Reframed the hook's scope in the docs: the patch is the root fix; the hook closes the MCP-tool gap that Claude Code's built-in validation leaves open.

### Fixed

- The hook handles malformed input and a missing `jq` gracefully (fail-open) instead of crashing.
- Restore is now atomic via `rename()`, with hardened patch-state handling.

### Security

- Restore verifies the backup's SHA-256 before replacing the binary.

## 2026-06-16

### Added

- Initial release: a PreToolUse hook (`evap-shield.sh`) and a binary patch (`patch-vh1.sh`) for the Claude Code VH1 streaming parser bug, with a one-command installer (`install.sh`).

### Fixed

- Prevent a macOS brick when patching: the patched Mach-O is ad-hoc re-signed and launch-checked on an isolated temporary inode, so patching never overwrites the running binary's inode (which AMFI would SIGKILL on relaunch).
