# /Users/eek/Development/braid/src/gate.nim
# The Two-Key Integration Gate for Braid (Zero Green Mirage).

import std/[os, osproc, strutils, json, times]
import config

proc detectTestCommand*(dir: string): string =
  if fileExists(dir / "Cargo.toml"): return "cargo test"
  if fileExists(dir / "wscript"): return "./waf build"
  if fileExists(dir / "pyproject.toml"): return "uv run pytest"
  if fileExists(dir / "package.json"):
    if fileExists(dir / "pnpm-lock.yaml"): return "pnpm test"
    return "npm test"
  for kind, p in walkDir(dir):
    if kind == pcFile and p.endsWith(".nimble"): return "nimble test"
  return ""

proc doBraidGate*(
  branchParam: string = "",
  baseRefParam: string = "HEAD",
  strandDirParam: string = "",
  skipTests: bool = false
): tuple[output: JsonNode, exitCode: int] =
  let strandDir = if strandDirParam.len > 0: strandDirParam.normalizedPath else: getCurrentDir()
  let manifestPath = strandDir / ".braid.json"
  var manifest: JsonNode = nil

  if fileExists(manifestPath):
    try: manifest = parseJson(readFile(manifestPath))
    except CatchableError: discard

  let branch = if branchParam.len > 0: branchParam
               elif manifest != nil and manifest.hasKey("branch"): manifest["branch"].getStr()
               else:
                 let (outp, code) = execCmdEx("git -C " & quoteShell(strandDir) & " rev-parse --abbrev-ref HEAD")
                 if code == 0: outp.strip() else: "HEAD"

  let baseRef = if baseRefParam.len > 0 and baseRefParam != "HEAD": baseRefParam
                elif manifest != nil and manifest.hasKey("base_branch"): manifest["base_branch"].getStr()
                else: "HEAD"

  let cfg = loadBraidConfig(strandDir / "braid.toml")

  var res = newJObject()
  res["branch"] = %branch
  res["base_ref"] = %baseRef
  res["strand_path"] = %strandDir

  # --- KEY 1: In-Memory Mechanical Conflict Gate ---
  let t0 = getTime().toUnixFloat()
  let cmd = "git -C " & quoteShell(strandDir) & " merge-tree --write-tree " & quoteShell(baseRef) & " " & quoteShell(branch)
  let (mtOut, mtCode) = try:
    execCmdEx(cmd)
  except CatchableError as e:
    (e.msg, 1)
  let latencyMs = (getTime().toUnixFloat() - t0) * 1000.0
  res["mechanical_gate_ms"] = %latencyMs

  if mtCode != 0:
    res["status"] = %"conflict"
    res["clean"] = %false
    res["key1_mechanical"] = %"FAIL"
    var conflictLines = newJArray()
    for line in mtOut.splitLines():
      let t = line.strip()
      if t.len > 0: conflictLines.add(%t)
    res["conflicts"] = conflictLines
    return (res, 1)

  let treeSha = mtOut.strip().splitLines()[0]
  res["key1_mechanical"] = %"PASS"
  res["merge_tree_sha"] = %treeSha

  # --- KEY 2: Live Compiler & Test Suite Gate (Anti-Green Mirage) ---
  if not skipTests:
    let testCmd = if cfg.testCommand.len > 0: cfg.testCommand else: detectTestCommand(strandDir)
    if testCmd.len > 0:
      res["test_command"] = %testCmd
      let tTest0 = getTime().toUnixFloat()
      let (tOut, tCode) = try:
        execCmdEx(testCmd, workingDir = strandDir)
      except CatchableError as e:
        (e.msg, 1)
      let testDurationMs = (getTime().toUnixFloat() - tTest0) * 1000.0
      res["test_duration_ms"] = %testDurationMs

      if tCode != 0:
        res["status"] = %"semantic_failure"
        res["clean"] = %false
        res["key2_semantic"] = %"FAIL"
        res["compiler_output"] = %tOut.strip()
        return (res, 2)
      res["key2_semantic"] = %"PASS"
    else:
      res["key2_semantic"] = %"SKIPPED (no test runner detected)"
  else:
    res["key2_semantic"] = %"SKIPPED (requested)"

  # Both Keys Passed!
  res["status"] = %"green"
  res["clean"] = %true

  # Update .braid.json if present
  if manifest != nil:
    manifest["status"] = %"READY_FOR_WEAVE"
    manifest["merge_tree_sha"] = %treeSha
    manifest["verified_at"] = %now().utc().format("yyyy-MM-dd'T'HH:mm:ss'Z'")
    writeFile(manifestPath, pretty(manifest))

  return (res, 0)
