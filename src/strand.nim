# /Users/eek/Development/braid/src/strand.nim
# Strand (workspace) provisioning, listing, and lifecycle management for Braid.

import std/[os, osproc, strutils, json, times]
import config

type
  StrandManifest* = object
    taskId*: string
    project*: string
    strandPath*: string
    branch*: string
    baseBranch*: string
    baseCommit*: string
    status*: string
    createdAt*: string
    tool*: string

proc getRepoRoot*(path: string = getCurrentDir()): string =
  var cur = path
  while cur.len > 0 and cur != "/":
    if dirExists(cur / ".git") or fileExists(cur / ".git"):
      return cur
    let parent = cur.parentDir()
    if parent == cur: break
    cur = parent
  return path

proc hasSubmodules*(repoDir: string): bool =
  let gitmodules = repoDir / ".gitmodules"
  if not fileExists(gitmodules): return false
  let (outp, code) = execCmdEx("git -C " & quoteShell(repoDir) & " submodule status")
  return code == 0 and outp.strip().len > 0

proc isSubmodulesUninitialized*(repoDir: string): bool =
  let (outp, code) = execCmdEx("git -C " & quoteShell(repoDir) & " submodule status")
  if code != 0: return false
  for line in outp.splitLines():
    if line.strip().startsWith("-"): return true
  return false

proc getHeadCommit*(repoDir: string): string =
  let (outp, code) = execCmdEx("git -C " & quoteShell(repoDir) & " rev-parse HEAD")
  if code == 0: return outp.strip()
  return ""

proc isVenvRelocatable*(venvDir: string): bool =
  let cfg = venvDir / "pyvenv.cfg"
  if not fileExists(cfg): return false
  for line in readFile(cfg).splitLines():
    let s = line.strip().toLowerAscii
    if s.startsWith("relocatable") and s.contains("true"):
      return true
  return false

proc doStrandNew*(
  taskId: string,
  repoDirParam: string = "",
  branchParam: string = "",
  baseRef: string = "HEAD",
  forceRift: bool = false,
  forceWorktree: bool = false
): tuple[manifest: JsonNode, exitCode: int] =
  let repoDir = if repoDirParam.len > 0: repoDirParam.normalizedPath else: getRepoRoot()
  let projectName = repoDir.splitPath.tail
  let cfg = loadBraidConfig(repoDir / "braid.toml")

  let branch = if branchParam.len > 0: branchParam else: "strand/" & taskId
  let baseBranch = if baseRef == "HEAD": cfg.primaryBranch else: baseRef

  let home = getHomeDir()
  let workspacesBase = home / "Development" / "workspaces" / projectName / taskId
  let strandDir = workspacesBase / projectName

  if dirExists(strandDir):
    var errObj = newJObject()
    errObj["status"] = %"error"
    errObj["message"] = %("Strand directory already exists at: " & strandDir)
    return (errObj, 1)

  createDir(workspacesBase)

  # Check uninitialized submodules
  if hasSubmodules(repoDir) and isSubmodulesUninitialized(repoDir):
    stderr.writeLine("WARNING: Canonical repository has uninitialized submodules. Initializing first...")
    discard execCmdEx("git -C " & quoteShell(repoDir) & " submodule update --init --recursive")

  # Decision: Rift vs Git Worktree
  let useRift = if forceWorktree: false elif forceRift: true else: hasSubmodules(repoDir)
  var toolUsed = "git-worktree"

  if useRift:
    toolUsed = "rift"
    let riftCmd = "rift create --into " & quoteShell(workspacesBase) & " --name " & quoteShell(projectName)
    let (rout, rcode) = execCmdEx(riftCmd)
    if rcode != 0:
      var errObj = newJObject()
      errObj["status"] = %"error"
      errObj["message"] = %("Rift creation failed: " & rout)
      return (errObj, rcode)
    # Check out branch inside rift clone
    discard execCmdEx("git -C " & quoteShell(strandDir) & " checkout -q -b " & quoteShell(branch))
  else:
    toolUsed = "git-worktree"
    let wtCmd = "git -C " & quoteShell(repoDir) & " worktree add " & quoteShell(strandDir) & " -b " & quoteShell(branch) & " " & quoteShell(baseRef)
    let (wout, wcode) = execCmdEx(wtCmd)
    if wcode != 0:
      var errObj = newJObject()
      errObj["status"] = %"error"
      errObj["message"] = %("git worktree add failed: " & wout)
      return (errObj, wcode)

  # Stat Cache Warmup
  discard execCmdEx("git -C " & quoteShell(strandDir) & " update-index --refresh")

  # APFS CoW Vendoring Fast-Path
  for vdir in cfg.vendorDirs:
    let srcV = repoDir / vdir
    let dstV = strandDir / vdir
    if dirExists(srcV) and not dirExists(dstV):
      when defined(macosx):
        discard execCmdEx("cp -c -R " & quoteShell(srcV) & " " & quoteShell(dstV))
      else:
        discard execCmdEx("cp -a --reflink=auto " & quoteShell(srcV) & " " & quoteShell(dstV))

  # Python Virtual Environment Policy
  let parentVenv = repoDir / ".venv"
  let strandVenv = strandDir / ".venv"
  if dirExists(parentVenv) and not dirExists(strandVenv):
    if isVenvRelocatable(parentVenv):
      when defined(macosx):
        discard execCmdEx("cp -c -R " & quoteShell(parentVenv) & " " & quoteShell(strandVenv))
      else:
        discard execCmdEx("cp -a --reflink=auto " & quoteShell(parentVenv) & " " & quoteShell(strandVenv))
    elif cfg.venvPolicy == "recreate":
      discard execCmdEx("UV_VENV_RELOCATABLE=1 uv venv " & quoteShell(strandVenv))

  # Non-Destructive .envrc Setup
  let envrcPath = strandDir / ".envrc"
  var envrcLines: seq[string] = @[]
  if fileExists(repoDir / ".envrc"):
    envrcLines.add("[ -f " & quoteShell(repoDir / ".envrc") & " ] && source_env " & quoteShell(repoDir / ".envrc"))
  envrcLines.add("export PROJECT_ROOT=\"$(git rev-parse --show-toplevel 2>/dev/null || pwd)\"")
  envrcLines.add("export CACHE_ROOT=\"${XDG_CACHE_HOME:-$HOME/.cache}/dev-workspaces/$(basename \"$PROJECT_ROOT\")\"")
  envrcLines.add("mkdir -p \"$CACHE_ROOT\"")
  envrcLines.add("if command -v ccache >/dev/null 2>&1; then")
  envrcLines.add("    export CCACHE_BASEDIR=\"$(dirname \"$PROJECT_ROOT\")\"")
  envrcLines.add("    export CCACHE_NOHASHDIR=1")
  envrcLines.add("fi")
  envrcLines.add("[ -f \"$PROJECT_ROOT/Cargo.toml\" ] && export CARGO_TARGET_DIR=\"$CACHE_ROOT/cargo-target\"")
  envrcLines.add("export UV_LINK_MODE=\"clone\"")
  envrcLines.add("export NIMCACHE=\"$CACHE_ROOT/nimcache\"")
  writeFile(envrcPath, envrcLines.join("\n") & "\n")
  discard execCmdEx("direnv allow " & quoteShell(strandDir))

  # Initialize .braid.json Manifest
  let baseCommit = getHeadCommit(repoDir)
  let manifest = %*{
    "task_id": taskId,
    "project": projectName,
    "canonical_repo": repoDir,
    "strand_path": strandDir,
    "branch": branch,
    "base_branch": baseBranch,
    "base_commit": baseCommit,
    "status": "IN_PROGRESS",
    "created_at": now().utc().format("yyyy-MM-dd'T'HH:mm:ss'Z'"),
    "tool": toolUsed
  }
  writeFile(strandDir / ".braid.json", pretty(manifest))

  var res = newJObject()
  res["status"] = %"created"
  res["task_id"] = %taskId
  res["project"] = %projectName
  res["strand_path"] = %strandDir
  res["branch"] = %branch
  res["tool"] = %toolUsed
  return (res, 0)

proc doStrandList*(repoDirParam: string = "", includeAll: bool = false): JsonNode =
  let repoDir = if repoDirParam.len > 0: repoDirParam.normalizedPath else: getRepoRoot()
  let projectName = repoDir.splitPath.tail
  let home = getHomeDir()
  let workspacesBase = home / "Development" / "workspaces"

  var strands = newJArray()

  if dirExists(workspacesBase):
    for kind, projectDir in walkDir(workspacesBase):
      if kind == pcDir:
        let curProj = projectDir.splitPath.tail
        if not includeAll and curProj != projectName: continue
        for subKind, taskDir in walkDir(projectDir):
          if subKind == pcDir:
            for itemKind, leafDir in walkDir(taskDir):
              if itemKind == pcDir:
                let manifestPath = leafDir / ".braid.json"
                if fileExists(manifestPath):
                  try:
                    let j = parseJson(readFile(manifestPath))
                    strands.add(j)
                  except CatchableError: discard

  var res = newJObject()
  res["project"] = %projectName
  res["count"] = %(strands.len)
  res["strands"] = strands
  return res

proc doStrandPrune*(repoDirParam: string = "", maxAgeHours: float = 24.0, dryRun: bool = true): JsonNode =
  let listData = doStrandList(repoDirParam, includeAll = false)
  var pruned = newJArray()
  let nowEpoch = getTime().toUnix().float

  for item in listData["strands"]:
    let path = item{"strand_path"}.getStr("")
    let status = item{"status"}.getStr("")
    let createdAt = item{"created_at"}.getStr("")
    var ageHours = 0.0

    try:
      let dt = parse(createdAt, "yyyy-MM-dd'T'HH:mm:ss'Z'", utc())
      ageHours = (nowEpoch - dt.toTime().toUnix().float) / 3600.0
    except CatchableError: discard

    let shouldPrune = (status in ["WEAVED", "MERGED", "CLOSED"]) or (ageHours >= maxAgeHours)
    if shouldPrune and dirExists(path):
      if not dryRun:
        discard execCmdEx("git worktree remove --force " & quoteShell(path))
        removeDir(path.parentDir())
      var prunedItem = newJObject()
      prunedItem["strand_path"] = %path
      prunedItem["age_hours"] = %ageHours
      prunedItem["reason"] = if status in ["WEAVED", "MERGED"]: %status else: %"expired"
      pruned.add(prunedItem)

  var res = newJObject()
  res["dry_run"] = %dryRun
  res["pruned_count"] = %(pruned.len)
  res["pruned"] = pruned
  return res
