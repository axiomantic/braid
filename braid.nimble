# Package
version       = "0.1.0"
author        = "Axiomantic"
description   = "Sub-Second APFS CoW Workspaces & Zero-Mirage Git Weaving Engine"
license       = "MIT"
srcDir        = "src"
bin           = @["braid"]
binDir        = "bin"

# Dependencies
requires "nim >= 2.0.0"

task test, "Run test suite":
  exec "nim r tests/test_braid_tripwire.nim"
  exec "uv run --with pytest pytest tests/test_braid.py -q"
