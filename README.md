# Vine

**Sub-Second APFS Copy-on-Write Workspaces & Zero-Mirage Git Weaving for Autonomous AI Agents**

Vine provides zero-drag workspace virtualization, polyglot build-cache normalization, and mechanical + semantic verification gates for parallel AI coding agents.

## Core Concepts

- **Strands**: Instantaneous APFS copy-on-write workspace clones (`vine new <task_id>`). Uses `anomalyco/rift` for submoduled repositories (in ~9s with 0 extra blocks) and `git worktree` for monolithic repos (in ~280ms).
- **Universal CoW Vendoring**: Clones dependency caches (`deps`, `node_modules`, `vendor`) in <80ms without physical disk duplication.
- **Polyglot Build Cache Layer**: Auto-activates non-destructive `.envrc` normalizing `ccache`, `sccache`, `uv` clone mode, and `nimcache`.
- **The Two-Key Gate**: Ensures zero "Green Mirage" by requiring both Key 1 (in-memory mechanical `git merge-tree` exit 0) and Key 2 (live compiler & test suite exit 0).
- **Weaving**: Fast-forwards verified strands back into the canonical trunk (`vine weave`).

## Standalone Yet Designed for the Axiomantic Triad

Vine is completely standalone and can be used on its own for sub-second APFS CoW workspace cloning, `.envrc` build-cache normalization, and Two-Key gate verification on any git repository.

However, Vine is designed from the ground up to pair seamlessly with **Rhizo** and **Garden**:
- [**Rhizo**](https://github.com/axiomantic/rhizo) (Transport & Concurrency): Inter-agent messaging bus, monotonic fencing locks, and task queues over Redis.
- **Vine** (Workspaces & Verification): Sub-second APFS Copy-on-Write strands, polyglot build-cache normalization, and the Two-Key integration gate (`git merge-tree` mechanical + compiler/test suite semantic checks).
- [**Garden**](https://github.com/axiomantic/garden) (Swarm Ceremonies): Tmux worker fleet provisioning, 3-stage empirical dialectical pump (research, architecture, audit), and master ceremonial implementation planning.

## Installation

### 1. For AI Coding Assistants (Recommended)

Install the skills globally (`-g`) across all your coding assistants (Claude Code, Antigravity, Cursor, Codex, OpenCode, etc.):

```bash
# Recommended: Install the complete multi-agent triad globally
npx skills add -g axiomantic/rhizo
npx skills add -g axiomantic/vine
npx skills add -g axiomantic/garden
```

*(Each skill automatically self-bootstraps its native CLI binary if it is not already installed on your system).*

To install only Vine:
```bash
npx skills add -g axiomantic/vine
```

### 2. Standalone CLI Installation

Install the compiled CLI tools directly onto your `$PATH`:

```bash
# Install all three tools:
npm install -g @axiomantic/rhizo @axiomantic/vine @axiomantic/garden

# Or install Vine alone:
npm install -g @axiomantic/vine
```

### 3. Repository Coordination Guide

Install the Vine strand coordination protocol directly into any project's `AGENTS.md`:
```bash
vine guide install
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

## Multi-Agent Triad Workflow

When orchestrating teams of multiple AI assistants operating simultaneously across strands, pair Vine with [**Rhizo**](https://github.com/axiomantic/rhizo) and [**Garden**](https://github.com/axiomantic/garden):

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
