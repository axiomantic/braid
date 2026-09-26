# Braid

**Sub-Second APFS Copy-on-Write Workspaces & Zero-Mirage Git Weaving for Autonomous AI Agents**

Braid provides zero-drag workspace virtualization, polyglot build-cache normalization, and mechanical + semantic verification gates for parallel AI coding agents.

## Core Concepts

- **Strands**: Instantaneous APFS copy-on-write workspace clones (`braid new <task_id>`). Uses `anomalyco/rift` for submoduled repositories (in ~9s with 0 extra blocks) and `git worktree` for monolithic repos (in ~280ms).
- **Universal CoW Vendoring**: Clones dependency caches (`deps`, `node_modules`, `vendor`) in <80ms without physical disk duplication.
- **Polyglot Build Cache Layer**: Auto-activates non-destructive `.envrc` normalizing `ccache`, `sccache`, `uv` clone mode, and `nimcache`.
- **The Two-Key Gate**: Ensures zero "Green Mirage" by requiring both Key 1 (in-memory mechanical `git merge-tree` exit 0) and Key 2 (live compiler & test suite exit 0).
- **Weaving**: Fast-forwards verified strands back into the canonical trunk (`braid weave`).

## Installation

```bash
nim c -d:release --out:bin/braid src/braid.nim
cp bin/braid ~/.local/bin/braid
```

## Quickstart

```bash
# Spin up an isolated strand for a task
braid new T-1049 --repo ~/Development/PebbleOS --branch feat/display-driver

# Verify mechanical and semantic correctness inside the strand
braid gate

# Weave clean strand into canonical branch
braid weave
```

## Repository Guide Integration

Install the Braid guide into any repository's `AGENTS.md`:

```bash
braid guide install AGENTS.md
```
