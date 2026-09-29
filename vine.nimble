# Package
version       = "0.1.4"
author        = "Axiomantic"
description   = "Sub-Second APFS CoW Workspaces & Zero-Mirage Git Weaving Engine"
license       = "MIT"
srcDir        = "src"
bin           = @["vine"]
binDir        = "bin"

# Dependencies
requires "nim >= 2.0.0"

task test, "Run test suite":
  exec "nim r tests/test_vine_tripwire.nim"
