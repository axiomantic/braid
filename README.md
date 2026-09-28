# Vine

**Sub-Second APFS Copy-on-Write Workspaces & Zero-Mirage Git Weaving for Autonomous AI Agents**

Vine provides zero-drag workspace virtualization, polyglot build-cache normalization, and mechanical + semantic verification gates for parallel AI coding agents.

## Core Concepts

- **Strands**: Instantaneous APFS copy-on-write workspace clones (`vine new <task_id>`). Uses `anomalyco/rift` for submoduled repositories (in ~9s with 0 extra blocks) and `git worktree` for monolithic repos (in ~280ms).
- **Universal CoW Vendoring**: Clones dependency caches (`deps`, `node_modules`, `vendor`) in <80ms without physical disk duplication.
- **Polyglot Build Cache Layer**: Auto-activates non-destructive `.envrc` normalizing `ccache`, `sccache`, `uv` clone mode, and `nimcache`.
- **The Two-Key Gate**: Ensures zero "Green Mirage" by requiring both Key 1 (in-memory mechanical `git merge-tree` exit 0) and Key 2 (live compiler & test suite exit 0).
- **Weaving**: Fast-forwards verified strands back into the canonical trunk (`vine weave`).

## Installation

```bash
# Install globally via npm:
npm install -g @axiomantic/vine

# Or run directly without installation via npx:
npx @axiomantic/vine --help
```

## Quickstart

```bash
# Spin up an isolated strand for a task
vine new T-1049 --repo ~/Development/PebbleOS --branch feat/display-driver

# Verify mechanical and semantic correctness inside the strand
vine gate

# Weave clean strand into canonical branch
vine weave
```

## Pairing with Rhizo & Garden for Multi-Agent Orchestration

Vine provides sub-second APFS CoW workspaces and the Two-Key integration gate for parallel tasks. When orchestrating teams of multiple AI assistants operating simultaneously across strands, pair Vine with [**Rhizo**](https://github.com/axiomantic/rhizo) and [**Garden**](https://github.com/axiomantic/garden):

- **Distributed Mutexes & Fencing**: Use `rhizo lock file:<path> --fencing` to prevent concurrent collisions on non-mergeable schema files or migrations.
- **Synchronized Task Queues**: Agents claim work via `rhizo claim queue:<project>:tasks --lease 1800` and report status back over the Redis bus.
- **Full Ceremony Conduct**: Use `garden` to direct persona deliberations, tmux worker fleets, and master plans.
- **Zero Dirty Commits**: Rhizo, Vine, and Garden enforce complete decoupling of agent identity from directory paths.

## Repository Guide Integration

Install the Vine guide into any repository's `AGENTS.md`:

```bash
# Defaults to AGENTS.md in the current working directory:
vine guide install

# Or specify a custom target path:
vine guide install /path/to/AGENTS.md
```
