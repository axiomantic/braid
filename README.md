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
# Install globally via npm:
npm install -g @axiomantic/braid

# Or run directly without installation via npx:
npx @axiomantic/braid --help
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

## Pairing with Locutus / Locu for Multi-Agent Orchestration

Braid provides sub-second APFS CoW workspaces and the Two-Key integration gate for parallel tasks. When orchestrating teams of multiple AI assistants operating simultaneously across strands, pair Braid with [**Locutus**](https://github.com/axiomantic/locutus) (CLI alias: `locu`):

- **Distributed Mutexes & Fencing**: Use `locu lock file:<path> --fencing` to prevent concurrent collisions on non-mergeable schema files or migrations.
- **Synchronized Task Queues**: Agents claim work via `locu claim queue:<project>:tasks --lease 1800` and report status back over the Redis bus.
- **Zero Dirty Commits**: Both Locutus and Braid enforce complete decoupling of agent identity from directory paths.

## Repository Guide Integration

Install the Braid guide into any repository's `AGENTS.md`:

```bash
braid guide install AGENTS.md
```
