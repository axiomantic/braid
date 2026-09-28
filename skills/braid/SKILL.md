---
name: braid
description: "Sub-Second APFS Copy-on-Write workspaces (Strands), polyglot build-cache normalizers (.envrc), Two-Key integration gate verification, and fast-forward trunk weaving. Use when spinning up isolated branch workspaces for complex tasks or parallel agents, preventing dirty commits or git submodule corruption, checking merge-tree and semantic test gates before merging, and fast-forwarding verified code back into canonical trunk. Triggers: 'braid', 'strand', 'spin up strand', 'isolated workspace', 'APFS clone', 'two-key gate', 'braid gate', 'braid weave', 'weave branch'."
---

# Braid: Sub-Second APFS Workspaces & Two-Key Gate Verification

> **Zero-Cost Workspace Virtualization for Autonomous AI Agents**  
> *Braid provides instantaneous APFS copy-on-write workspaces (Strands), polyglot build-cache normalization, and mechanical + semantic verification gates for parallel AI coding agents.*

---

## 1. Core Primitives

- **Strands (`braid new <task_id>`)**:
  Isolated branch workspaces living outside the canonical repo to prevent recursive indexing and IDE thrashing. Uses native APFS CoW cloning (`rift` / `clonefile`) for repositories with submodules (~9s with 0 extra blocks) and `git worktree` for monolithic repos (~280ms).
- **Universal CoW Dependency Vendoring**:
  Clones pre-built dependency caches (`deps`, `nimbledeps`, `vendor`, `node_modules`, `.zig-cache`) in <80ms without physical disk duplication.
- **Polyglot Build Cache Layer (`.envrc`)**:
  Normalizes build caching across strands for C/C++ (`CCACHE_BASEDIR`, `CCACHE_NOHASHDIR`), Rust (`CARGO_TARGET_DIR`), Nim (`NIMCACHE`), and Python `uv` (`UV_LINK_MODE=clone`).
- **The Two-Key Gate (`braid gate`)**:
  Enforces zero "Green Mirage" by requiring both Key 1 (in-memory mechanical `git merge-tree` exit 0) and Key 2 (live compiler & test suite exit 0) before any code touches the canonical trunk.
- **Trunk Weaving (`braid weave`)**:
  Fast-forward merges verified strands into the canonical trunk and automatically prunes the strand worktree.

---

## 2. CLI Reference & Lifecycle

| Command | Description | Example |
| :--- | :--- | :--- |
| `braid new <task_id>` | Creates an isolated strand workspace outside canonical root. | `braid new task-101 --branch feat/api` |
| `braid gate [--json]` | Evaluates Two-Key Gate (mechanical merge-tree + live test suite). | `braid gate --json` |
| `braid weave` | Fast-forwards verified strand into trunk and prunes workspace. | `braid weave` |
| `braid list` | Displays active strands, branch mappings, and manifests. | `braid list` |
| `braid sync` | Re-synchronizes diverged canonical trunk changes into active strand. | `braid sync` |
| `braid prune [--max-age <hours>]` | Garbage collects stale, merged, or abandoned strands. | `braid prune` |
| `braid guide <install\|check\|uninstall>` | Manages the Braid Coordination Guide in `AGENTS.md`. | `braid guide install` |

---

## 3. Standard Operating Procedure for Agents

### Step 1: Provision Isolated Strand
When assigned complex multi-file work:
```bash
braid new <task_id> --branch strand/<task_id> --worktree
```
Move to the returned `strand_path` and perform all edits, compilations, and tests there.

### Step 2: Verify Two-Key Gate
Before signaling completion to the orchestrator:
```bash
braid gate --json
```
- **Exit 0**: Both Key 1 and Key 2 passed. Report pass to orchestrator.
- **Exit 1**: Key 1 failed (conflicts with canonical trunk). Run `braid sync` inside strand to resolve conflicts.
- **Exit 2**: Key 2 failed (compiler or test failure). Fix code inside strand.

### Step 3: Trunk Weaving
Once Two-Key gate passes:
```bash
braid weave
```
Trunk is updated via fast-forward merge and strand is cleaned up.
