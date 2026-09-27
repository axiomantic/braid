# /Users/eek/Development/braid/src/braid.nim
# Braid — Sub-Second APFS CoW Workspaces & Zero-Mirage Git Weaving Engine.

import std/[os, strutils, json]
import strand, gate, weave, guide, config

const Version = "0.1.0"

proc printHelp() =
  echo "Braid v" & Version & " — Sub-Second APFS CoW Workspaces & Zero-Mirage Git Weaving"
  echo ""
  echo "Usage:"
  echo "  braid new <task_id> [--repo <path>] [--branch <name>] [--base <ref>] [--rift] [--worktree]"
  echo "  braid list [--repo <path>] [--all]"
  echo "  braid gate [branch] [--base <ref>] [--dir <path>] [--skip-tests] [--json]"
  echo "  braid sync [--dir <path>] [--base <ref>] [--rebase]"
  echo "  braid weave [branch] [--base <ref>] [--dir <path>] [--force]"
  echo "  braid prune [--repo <path>] [--max-age <hours>] [--apply]"
  echo "  braid guide <install|uninstall|check> [path]"
  echo "  braid config <init|show> [path]"
  echo ""
  echo "Global Options:"
  echo "  --version, -v    Print version"
  echo "  --help, -h       Print help"

proc main() =
  let args = commandLineParams()
  if args.len == 0 or args[0] in ["--help", "-h", "help"]:
    printHelp()
    quit(0)

  if args[0] in ["--version", "-v", "version"]:
    echo "braid " & Version
    quit(0)

  let cmd = args[0].toLowerAscii
  case cmd
  of "new", "create", "strand":
    if args.len < 2:
      stderr.writeLine("Usage: braid new <task_id> [--repo <path>] [--branch <name>] [--base <ref>] [--rift] [--worktree]")
      quit(1)
    let taskId = args[1]
    var repoDir = ""
    var branch = ""
    var baseRef = "HEAD"
    var forceRift = false
    var forceWorktree = false
    var i = 2
    while i < args.len:
      let a = args[i]
      if a == "--repo" and i + 1 < args.len:
        repoDir = args[i+1]; inc i
      elif a.startsWith("--repo="): repoDir = a[7..^1]
      elif a == "--branch" and i + 1 < args.len:
        branch = args[i+1]; inc i
      elif a.startsWith("--branch="): branch = a[9..^1]
      elif a == "--base" and i + 1 < args.len:
        baseRef = args[i+1]; inc i
      elif a.startsWith("--base="): baseRef = a[7..^1]
      elif a == "--rift": forceRift = true
      elif a == "--worktree": forceWorktree = true
      inc i
    let (res, code) = doStrandNew(taskId, repoDir, branch, baseRef, forceRift, forceWorktree)
    if code != 0:
      stderr.writeLine(pretty(res))
      quit(code)
    echo pretty(res)

  of "list", "ls":
    var repoDir = ""
    var includeAll = false
    var i = 1
    while i < args.len:
      let a = args[i]
      if a in ["--all", "-a"]: includeAll = true
      elif a == "--repo" and i + 1 < args.len:
        repoDir = args[i+1]; inc i
      inc i
    let res = doStrandList(repoDir, includeAll)
    echo pretty(res)

  of "gate", "check":
    var branch = ""
    var baseRef = "HEAD"
    var strandDir = ""
    var skipTests = false
    var jsonOut = false
    var i = 1
    while i < args.len:
      let a = args[i]
      if a == "--base" and i + 1 < args.len:
        baseRef = args[i+1]; inc i
      elif a.startsWith("--base="): baseRef = a[7..^1]
      elif a == "--dir" and i + 1 < args.len:
        strandDir = args[i+1]; inc i
      elif a.startsWith("--dir="): strandDir = a[6..^1]
      elif a == "--skip-tests": skipTests = true
      elif a == "--json": jsonOut = true
      elif not a.startsWith("-") and branch.len == 0:
        branch = a
      inc i
    let (res, code) = doBraidGate(branch, baseRef, strandDir, skipTests)
    if jsonOut:
      echo pretty(res)
    else:
      if code == 0:
        echo "[GREEN] Two-Key Gate Passed!"
        echo "  Mechanical: Clean (tree: " & res{"merge_tree_sha"}.getStr("") & " in " & $res{"mechanical_gate_ms"}.getFloat() & " ms)"
        if res.hasKey("test_command"):
          echo "  Semantic  : 100% Green (" & res{"test_command"}.getStr() & " in " & $res{"test_duration_ms"}.getFloat() & " ms)"
      elif code == 1:
        stderr.writeLine("[CONFLICT] Key 1 Mechanical Gate Failed:")
        for c in res{"conflicts"}: stderr.writeLine("  " & c.getStr())
      elif code == 2:
        stderr.writeLine("[FAILURE] Key 2 Semantic Compiler Gate Failed:")
        stderr.writeLine(res{"compiler_output"}.getStr())
    quit(code)

  of "sync", "rebase":
    var strandDir = ""
    var baseRef = ""
    var useRebase = (cmd == "rebase")
    var i = 1
    while i < args.len:
      let a = args[i]
      if a == "--dir" and i + 1 < args.len:
        strandDir = args[i+1]; inc i
      elif a.startsWith("--dir="): strandDir = a[6..^1]
      elif a == "--base" and i + 1 < args.len:
        baseRef = args[i+1]; inc i
      elif a.startsWith("--base="): baseRef = a[7..^1]
      elif a == "--rebase": useRebase = true
      elif not a.startsWith("-") and strandDir.len == 0:
        strandDir = a
      inc i
    let (res, code) = doStrandSync(strandDir, baseRef, useRebase)
    if code != 0:
      stderr.writeLine(pretty(res))
      quit(code)
    echo pretty(res)

  of "weave", "join", "merge":
    var branch = ""
    var baseRef = ""
    var strandDir = ""
    var force = false
    var i = 1
    while i < args.len:
      let a = args[i]
      if a == "--base" and i + 1 < args.len:
        baseRef = args[i+1]; inc i
      elif a == "--dir" and i + 1 < args.len:
        strandDir = args[i+1]; inc i
      elif a == "--force": force = true
      elif not a.startsWith("-") and branch.len == 0:
        branch = a
      inc i
    let (res, code) = doBraidWeave(branch, baseRef, strandDir, force)
    if code != 0:
      stderr.writeLine(pretty(res))
      quit(code)
    echo pretty(res)

  of "prune", "sweep":
    var repoDir = ""
    var maxAge = 24.0
    var dryRun = true
    var i = 1
    while i < args.len:
      let a = args[i]
      if a == "--apply": dryRun = false
      elif a == "--repo" and i + 1 < args.len:
        repoDir = args[i+1]; inc i
      elif a == "--max-age" and i + 1 < args.len:
        try: maxAge = parseFloat(args[i+1])
        except ValueError: discard
        inc i
      inc i
    let res = doStrandPrune(repoDir, maxAge, dryRun)
    echo pretty(res)

  of "guide":
    if args.len < 2:
      stderr.writeLine("Usage: braid guide <install|uninstall|check> [path]")
      quit(1)
    let action = args[1].toLowerAscii
    let target = if args.len > 2: args[2] else: "AGENTS.md"
    case action
    of "install", "i", "add":
      let (ok, msg) = installGuide(target)
      if ok: echo msg else: (stderr.writeLine(msg); quit(1))
    of "uninstall", "u", "remove", "rm":
      let (ok, msg) = uninstallGuide(target)
      if ok: echo msg else: (stderr.writeLine(msg); quit(1))
    of "check", "status":
      let st = checkGuide(target)
      case st
      of gsInstalled: echo "[INSTALLED] Braid Guide is installed in: " & target
      of gsNotFound: echo "[NOT FOUND] Braid Guide not found in: " & target
      of gsMalformed: (stderr.writeLine("[MALFORMED] Unbalanced markers in: " & target); quit(1))
      of gsFileMissing: echo "[MISSING] Target file does not exist: " & target
    else:
      stderr.writeLine("Unknown guide action: " & action)
      quit(1)

  of "config":
    let sub = if args.len > 1: args[1] else: "show"
    if sub == "init":
      let target = getCurrentDir() / "braid.toml"
      if fileExists(target):
        echo "braid.toml already exists at: " & target
      else:
        writeFile(target, """# braid.toml — Braid Project Configuration
[project]
primary_branch = "main"

[strand]
# Policy when encountering a non-relocatable .venv ("prompt", "recreate", "skip")
venv_policy = "prompt"

# Vendored directories for the APFS CoW fast-path
vendor_dirs = ["deps", "nimbledeps", "vendor", "node_modules", ".zig-cache"]

[verification]
# Command executed inside the strand during the Two-Key Gate
# test_command = "cargo test"
""")
        echo "Initialized: " & target
    else:
      let cfg = loadBraidConfig()
      var j = newJObject()
      j["primary_branch"] = %cfg.primaryBranch
      j["venv_policy"] = %cfg.venvPolicy
      var vdirs = newJArray()
      for d in cfg.vendorDirs: vdirs.add(%d)
      j["vendor_dirs"] = vdirs
      j["test_command"] = %cfg.testCommand
      if cfg.activeConfigFile.len > 0:
        j["active_config"] = %cfg.activeConfigFile
      echo pretty(j)

  else:
    stderr.writeLine("Unknown command: " & cmd)
    quit(1)

when isMainModule:
  main()
