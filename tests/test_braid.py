# /Users/eek/Development/braid/tests/test_braid.py
# Automated end-to-end tests for Braid CLI.

import subprocess
import tempfile
import json
import os
import shutil
import time
from pathlib import Path

BRAID_BIN = Path(__file__).parent.parent / "bin" / "braid"

def run_braid(*args, cwd=None):
    cmd = [str(BRAID_BIN)] + list(args)
    proc = subprocess.run(cmd, capture_output=True, text=True, cwd=cwd)
    return proc.returncode, proc.stdout, proc.stderr

def test_braid_version():
    code, out, err = run_braid("--version")
    assert code == 0
    assert "braid 0.1.0" in out

def test_braid_guide_lifecycle():
    with tempfile.TemporaryDirectory() as tmpdir:
        target = Path(tmpdir) / "AGENTS.md"

        # 1. Check missing
        code, out, err = run_braid("guide", "check", str(target))
        assert code == 0
        assert "[MISSING]" in out

        # 2. Install into new file
        code, out, err = run_braid("guide", "install", str(target))
        assert code == 0
        assert "Created" in out
        assert target.exists()

        content = target.read_text()
        assert "<!-- BEGIN BRAID GUIDE [v1.0] -->" in content
        assert "<!-- END BRAID GUIDE -->" in content
        assert "Braid Workspace & Strand Coordination Guide" in content

        # 3. Check installed
        code, out, err = run_braid("guide", "check", str(target))
        assert code == 0
        assert "[INSTALLED]" in out

        # 4. Uninstall
        code, out, err = run_braid("guide", "uninstall", str(target))
        assert code == 0
        assert "Successfully uninstalled" in out
        assert "BEGIN BRAID GUIDE" not in target.read_text()

def test_braid_config():
    with tempfile.TemporaryDirectory() as tmpdir:
        # Default config
        code, out, err = run_braid("config", "show", cwd=tmpdir)
        assert code == 0
        data = json.loads(out)
        assert data["primary_branch"] == "main"
        assert data["venv_policy"] == "prompt"

        # Init config
        code, out, err = run_braid("config", "init", cwd=tmpdir)
        assert code == 0
        toml_path = Path(tmpdir) / "braid.toml"
        assert toml_path.exists()
        assert "primary_branch" in toml_path.read_text()

def test_braid_strand_lifecycle_and_gate():
    with tempfile.TemporaryDirectory(prefix="braid_repo_") as repo_dir:
        # Initialize test git repo
        subprocess.run(["git", "init", "-q", repo_dir], check=True)
        subprocess.run(["git", "-C", repo_dir, "config", "user.email", "agent@braid.mesh"], check=True)
        subprocess.run(["git", "-C", repo_dir, "config", "user.name", "Braid Agent"], check=True)

        readme = os.path.join(repo_dir, "README.md")
        with open(readme, "w") as f:
            f.write("# Braid Repo\n")
        subprocess.run(["git", "-C", repo_dir, "add", "README.md"], check=True)
        subprocess.run(["git", "-C", repo_dir, "commit", "-q", "-m", "Initial commit"], check=True)

        # Create mock vendor dir
        os.makedirs(os.path.join(repo_dir, "deps", "pkg"), exist_ok=True)
        with open(os.path.join(repo_dir, "deps", "pkg", "lib.txt"), "w") as f:
            f.write("vendored library\n")

        # 1. Create Strand
        task_id = f"task-{int(time.time() * 1000)}"
        code, out, err = run_braid("new", task_id, "--repo", repo_dir, "--branch", f"strand/{task_id}", "--worktree")
        assert code == 0, f"Error: {err}\nOut: {out}"
        data = json.loads(out)
        assert data["status"] == "created"
        strand_path = data["strand_path"]
        assert os.path.isdir(strand_path)

        # Check manifest
        manifest_file = os.path.join(strand_path, ".braid.json")
        assert os.path.isfile(manifest_file)
        with open(manifest_file) as f:
            m = json.load(f)
        assert m["task_id"] == task_id
        assert m["status"] == "IN_PROGRESS"

        # Check vendored dependencies copied
        assert os.path.isfile(os.path.join(strand_path, "deps", "pkg", "lib.txt"))

        try:
            # 2. Commit a feature in strand
            feat_file = os.path.join(strand_path, "feature.txt")
            with open(feat_file, "w") as f:
                f.write("Braid feature line\n")
            subprocess.run(["git", "-C", strand_path, "add", "feature.txt"], check=True)
            subprocess.run(["git", "-C", strand_path, "commit", "-q", "-m", "feat: add feature"], check=True)

            # 3. Two-Key Gate
            g_code, g_out, g_err = run_braid("gate", "--dir", strand_path, "--base", "main", "--json")
            assert g_code == 0, f"Gate failed: {g_err}\nOut: {g_out}"
            g_data = json.loads(g_out)
            assert g_data["clean"] is True
            assert g_data["key1_mechanical"] == "PASS"

            # 4. Manifest should now be READY_FOR_WEAVE
            with open(manifest_file) as f:
                m_updated = json.load(f)
            assert m_updated["status"] == "READY_FOR_WEAVE"

            # 5. List strands
            l_code, l_out, l_err = run_braid("list", "--repo", repo_dir)
            assert l_code == 0
            l_data = json.loads(l_out)
            assert l_data["count"] >= 1

        finally:
            # Clean up worktree
            subprocess.run(["git", "-C", repo_dir, "worktree", "remove", "--force", strand_path], capture_output=True)
            subprocess.run(["git", "-C", repo_dir, "worktree", "prune"], capture_output=True)
            shutil.rmtree(os.path.dirname(strand_path), ignore_errors=True)
