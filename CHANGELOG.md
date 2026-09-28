# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Fixed
- **Weave Directory Lock & Base Ref Passing**: Switched process working directory back to canonical repository root prior to pruning strand worktrees in `braid weave` to prevent macOS directory-in-use deletion errors. Corrected parameter pass-through to ensure effective base ref is passed to the Two-Key integration gate.

### Added
- **Tripwire Negative Control Verification Suite**: Added end-to-end sandbox tests verifying Key 1 mechanical conflict rejection, Key 2 semantic compiler failure enforcement, strand re-synchronization (`braid sync`), and worktree lifecycle pruning.

## [0.1.0] - 2026-09-26

### Added
- **Sub-Second APFS Copy-on-Write Strands**: High-performance isolated branch workspaces (`braid new <task-id>`) created via native macOS APFS CoW cloning (`clonefile` / `cp -c -R`) and git worktrees in <80ms with 0 initial disk block consumption.
- **Universal Dependency Cache Normalizer**: Zero-cost APFS cloning of pre-built dependency trees (`deps`, `nimbledeps`, `vendor`, `node_modules`, `.zig-cache`) directly from the canonical repository into newly spun strands in <80ms.
- **Two-Key Integration Gate (`braid gate`)**: Anti-green-mirage verification requiring both keys before weaving into canonical trunk:
  - **Key 1 (Mechanical)**: In-memory conflict pre-check using `git merge-tree --write-tree` in ~30ms without touching the working tree.
  - **Key 2 (Semantic)**: Automated live compilation and test suite execution inside the strand (`test_command` via `braid.toml` or heuristic detection).
- **Automated Trunk Weaving (`braid weave`)**: Atomic, fast-forward merge from strand to canonical trunk with post-merge strand cleanup and prune.
- **Polyglot Build Cache Environment Normalizer (`.envrc`)**: Automatic generation of normalized caching environment variables for C/C++ (`CCACHE_BASEDIR`, `CCACHE_NOHASHDIR`), Rust (`CARGO_TARGET_DIR`), Nim (`NIMCACHE`), and Python `uv` (`UV_LINK_MODE=clone`).
- **Python Virtual Environment (`.venv`) Relocatability Policy**: Automatic inspection of `pyvenv.cfg` for relocatability, preventing parent environment mutation and enforcing safe recreation policies.
- **Strand Lifecycle Management & Registry**:
  - `braid list`: Discovers and displays active strands, status, branch tracking, and manifest metadata across the workspace.
  - `braid prune`: Automatically detects and cleans up strands whose branches have already merged or been deleted.
  - `braid guide install|check|uninstall`: Embeds the standard Braid Coordination Guide directly into repository `AGENTS.md` files.
- **NPM Multi-Architecture Packaging**: Published as `@axiomantic/braid` on npm with cross-platform native binary wrappers for macOS, Linux, and Windows.

[Unreleased]: https://github.com/axiomantic/braid/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/axiomantic/braid/releases/tag/v0.1.0
