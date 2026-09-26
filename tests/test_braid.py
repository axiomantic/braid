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

def test_braid_guide_unbalanced_markers_fail_safe():
    """Negative control: Unbalanced/corrupted guide markers must fail safe and protect content."""
    with tempfile.TemporaryDirectory() as tmpdir:
        target = Path(tmpdir) / "AGENTS.md"
        corrupted_content = "# Agent Guide\n<!-- BEGIN BRAID GUIDE [v1.0] -->\nOnly opening marker without closing marker\n"
        target.write_text(corrupted_content)

        # 1. Check must detect MALFORMED and exit code 1
        code, out, err = run_braid("guide", "check", str(target))
        assert code == 1
        assert "[MALFORMED]" in err

        # 2. Install must fail safe and NOT overwrite file
        code, out, err = run_braid("guide", "install", str(target))
        assert code == 1
        assert "Malformed markers" in err
        assert target.read_text() == corrupted_content

        # 3. Uninstall must fail safe and NOT mutate file
        code, out, err = run_braid("guide", "uninstall", str(target))
        assert code == 1
        assert "Malformed markers" in err
        assert target.read_text() == corrupted_content

def test_braid_config():
    with tempfile.TemporaryDirectory() as tmpdir:
        # Default config
        code, out, err = run_braid("config", "show", cwd=tmpdir)
        assert code == 0
        data = json.loads(out)
        assert data["primary_branch"] == "main"
        assert data["venv_policy"] == "prompt"
        assert "deps" in data["vendor_dirs"]

        # Init config
        code, out, err = run_braid("config", "init", cwd=tmpdir)
        assert code == 0
        toml_path = Path(tmpdir) / "braid.toml"
        assert toml_path.exists()
        assert "primary_branch" in toml_path.read_text()

def test_braid_custom_config_parsing():
    """Verify custom braid.toml overrides all configuration fields accurately."""
    with tempfile.TemporaryDirectory() as tmpdir:
        toml_path = Path(tmpdir) / "braid.toml"
        toml_path.write_text("""[project]
primary_branch = "develop"

[strand]
venv_policy = "recreate"
vendor_dirs = ["deps", "third_party", "node_modules"]

[verification]
test_command = "pytest tests/ -v"
""")
        code, out, err = run_braid("config", "show", cwd=tmpdir)
        assert code == 0, f"Error: {err}\nOut: {out}"
        data = json.loads(out)
        assert data["primary_branch"] == "develop"
        assert data["venv_policy"] == "recreate"
        assert data["vendor_dirs"] == ["deps", "third_party", "node_modules"]
        assert data["test_command"] == "pytest tests/ -v"
        assert Path(data["active_config"]).resolve() == toml_path.resolve()

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

            # 6. Weave strand into canonical repository
            w_code, w_out, w_err = run_braid("weave", "--dir", strand_path, "--base", "main")
            assert w_code == 0, f"Weave failed: {w_err}\nOut: {w_out}"
            w_data = json.loads(w_out)
            assert w_data["status"] == "woven"

            # Verify canonical repo received the commit
            assert os.path.isfile(os.path.join(repo_dir, "feature.txt"))
            with open(os.path.join(repo_dir, "feature.txt")) as f:
                assert "Braid feature line" in f.read()

            # Verify strand was pruned
            assert not os.path.exists(strand_path)

        finally:
            if os.path.exists(strand_path):
                subprocess.run(["git", "-C", repo_dir, "worktree", "remove", "--force", strand_path], capture_output=True)
                subprocess.run(["git", "-C", repo_dir, "worktree", "prune"], capture_output=True)
                shutil.rmtree(os.path.dirname(strand_path), ignore_errors=True)

def test_braid_gate_catches_mechanical_conflict():
    """Negative control: Key 1 mechanical conflict gate must reject conflicting strands."""
    with tempfile.TemporaryDirectory(prefix="braid_conflict_") as repo_dir:
        subprocess.run(["git", "init", "-q", repo_dir], check=True)
        subprocess.run(["git", "-C", repo_dir, "config", "user.email", "agent@braid.mesh"], check=True)
        subprocess.run(["git", "-C", repo_dir, "config", "user.name", "Braid Agent"], check=True)

        readme = os.path.join(repo_dir, "README.md")
        with open(readme, "w") as f:
            f.write("Line 1: Original text\n")
        subprocess.run(["git", "-C", repo_dir, "add", "README.md"], check=True)
        subprocess.run(["git", "-C", repo_dir, "commit", "-q", "-m", "Initial commit"], check=True)

        # 1. Create Strand
        task_id = f"task-conf-{int(time.time() * 1000)}"
        code, out, err = run_braid("new", task_id, "--repo", repo_dir, "--branch", f"strand/{task_id}", "--worktree")
        assert code == 0
        strand_path = json.loads(out)["strand_path"]

        try:
            # 2. Modify line in strand
            with open(os.path.join(strand_path, "README.md"), "w") as f:
                f.write("Line 1: Strand modified text\n")
            subprocess.run(["git", "-C", strand_path, "add", "README.md"], check=True)
            subprocess.run(["git", "-C", strand_path, "commit", "-q", "-m", "feat: strand edit"], check=True)

            # 3. Modify same line in canonical main (create conflict)
            with open(readme, "w") as f:
                f.write("Line 1: Canonical trunk conflicting edit\n")
            subprocess.run(["git", "-C", repo_dir, "add", "README.md"], check=True)
            subprocess.run(["git", "-C", repo_dir, "commit", "-q", "-m", "fix: trunk edit"], check=True)

            # 4. Gate must FAIL on Key 1 (code 1)
            g_code, g_out, g_err = run_braid("gate", "--dir", strand_path, "--base", "main", "--json")
            assert g_code == 1, f"Expected conflict gate failure (code 1), got {g_code}\nOut: {g_out}"
            g_data = json.loads(g_out)
            assert g_data["clean"] is False
            assert g_data["status"] == "conflict"
            assert g_data["key1_mechanical"] == "FAIL"
            assert any("README.md" in c for c in g_data["conflicts"])

            # 5. Weave without --force must be REJECTED
            w_code, w_out, w_err = run_braid("weave", "--dir", strand_path, "--base", "main")
            assert w_code != 0
            assert "Two-Key Gate" in w_err or "weave_rejected" in w_err

        finally:
            if os.path.exists(strand_path):
                subprocess.run(["git", "-C", repo_dir, "worktree", "remove", "--force", strand_path], capture_output=True)
                subprocess.run(["git", "-C", repo_dir, "worktree", "prune"], capture_output=True)
                shutil.rmtree(os.path.dirname(strand_path), ignore_errors=True)

def test_braid_gate_catches_semantic_compiler_failure():
    """Negative control: Key 2 semantic gate must reject failing build/test commands."""
    with tempfile.TemporaryDirectory(prefix="braid_compiler_fail_") as repo_dir:
        subprocess.run(["git", "init", "-q", repo_dir], check=True)
        subprocess.run(["git", "-C", repo_dir, "config", "user.email", "agent@braid.mesh"], check=True)
        subprocess.run(["git", "-C", repo_dir, "config", "user.name", "Braid Agent"], check=True)

        readme = os.path.join(repo_dir, "README.md")
        with open(readme, "w") as f:
            f.write("# Project\n")
        subprocess.run(["git", "-C", repo_dir, "add", "README.md"], check=True)
        subprocess.run(["git", "-C", repo_dir, "commit", "-q", "-m", "Initial commit"], check=True)

        # Configure braid.toml with a failing test_command
        with open(os.path.join(repo_dir, "braid.toml"), "w") as f:
            f.write("[verification]\ntest_command = \"echo 'Simulated compiler error' && exit 1\"\n")
        subprocess.run(["git", "-C", repo_dir, "add", "braid.toml"], check=True)
        subprocess.run(["git", "-C", repo_dir, "commit", "-q", "-m", "chore: add braid.toml"], check=True)

        task_id = f"task-sem-{int(time.time() * 1000)}"
        code, out, err = run_braid("new", task_id, "--repo", repo_dir, "--branch", f"strand/{task_id}", "--worktree")
        assert code == 0
        strand_path = json.loads(out)["strand_path"]

        try:
            # Commit a change in strand
            with open(os.path.join(strand_path, "feature.txt"), "w") as f:
                f.write("Broken feature\n")
            subprocess.run(["git", "-C", strand_path, "add", "feature.txt"], check=True)
            subprocess.run(["git", "-C", strand_path, "commit", "-q", "-m", "feat: broken feature"], check=True)

            # Gate must FAIL on Key 2 (code 2)
            g_code, g_out, g_err = run_braid("gate", "--dir", strand_path, "--base", "main", "--json")
            assert g_code == 2, f"Expected semantic failure (code 2), got {g_code}\nOut: {g_out}"
            g_data = json.loads(g_out)
            assert g_data["clean"] is False
            assert g_data["status"] == "semantic_failure"
            assert g_data["key1_mechanical"] == "PASS"
            assert g_data["key2_semantic"] == "FAIL"
            assert "Simulated compiler error" in g_data["compiler_output"]

        finally:
            if os.path.exists(strand_path):
                subprocess.run(["git", "-C", repo_dir, "worktree", "remove", "--force", strand_path], capture_output=True)
                subprocess.run(["git", "-C", repo_dir, "worktree", "prune"], capture_output=True)
                shutil.rmtree(os.path.dirname(strand_path), ignore_errors=True)

def test_braid_strand_envrc_generation():
    """Verify Braid generates a non-destructive polyglot .envrc that chains parent .envrc."""
    with tempfile.TemporaryDirectory(prefix="braid_envrc_") as repo_dir:
        subprocess.run(["git", "init", "-q", repo_dir], check=True)
        subprocess.run(["git", "-C", repo_dir, "config", "user.email", "agent@braid.mesh"], check=True)
        subprocess.run(["git", "-C", repo_dir, "config", "user.name", "Braid Agent"], check=True)

        readme = os.path.join(repo_dir, "README.md")
        with open(readme, "w") as f:
            f.write("# Project\n")
        parent_envrc = os.path.join(repo_dir, ".envrc")
        with open(parent_envrc, "w") as f:
            f.write("export PARENT_FLAG=active\n")

        subprocess.run(["git", "-C", repo_dir, "add", "README.md"], check=True)
        subprocess.run(["git", "-C", repo_dir, "commit", "-q", "-m", "Initial commit"], check=True)

        task_id = f"task-envrc-{int(time.time() * 1000)}"
        code, out, err = run_braid("new", task_id, "--repo", repo_dir, "--branch", f"strand/{task_id}", "--worktree")
        assert code == 0
        strand_path = json.loads(out)["strand_path"]

        try:
            envrc_file = os.path.join(strand_path, ".envrc")
            assert os.path.isfile(envrc_file), ".envrc must be generated in strand root"
            content = open(envrc_file).read()
            assert "source_env" in content, "Must source parent repository .envrc"
            assert "PROJECT_ROOT=" in content
            assert "CACHE_ROOT=" in content
            assert "CCACHE_BASEDIR=" in content
            assert "CCACHE_NOHASHDIR=1" in content
            assert "CARGO_TARGET_DIR=" in content
            assert 'UV_LINK_MODE="clone"' in content
            assert "NIMCACHE=" in content
        finally:
            if os.path.exists(strand_path):
                subprocess.run(["git", "-C", repo_dir, "worktree", "remove", "--force", strand_path], capture_output=True)
                subprocess.run(["git", "-C", repo_dir, "worktree", "prune"], capture_output=True)
                shutil.rmtree(os.path.dirname(strand_path), ignore_errors=True)

def test_braid_prune():
    """Verify braid prune dry-run and apply lifecycle on completed strands."""
    with tempfile.TemporaryDirectory(prefix="braid_prune_") as repo_dir:
        subprocess.run(["git", "init", "-q", repo_dir], check=True)
        subprocess.run(["git", "-C", repo_dir, "config", "user.email", "agent@braid.mesh"], check=True)
        subprocess.run(["git", "-C", repo_dir, "config", "user.name", "Braid Agent"], check=True)

        readme = os.path.join(repo_dir, "README.md")
        with open(readme, "w") as f:
            f.write("# Prune test\n")
        subprocess.run(["git", "-C", repo_dir, "add", "README.md"], check=True)
        subprocess.run(["git", "-C", repo_dir, "commit", "-q", "-m", "Initial commit"], check=True)

        task_id = f"task-prune-{int(time.time() * 1000)}"
        code, out, err = run_braid("new", task_id, "--repo", repo_dir, "--branch", f"strand/{task_id}", "--worktree")
        assert code == 0
        strand_path = json.loads(out)["strand_path"]

        try:
            manifest_file = os.path.join(strand_path, ".braid.json")
            with open(manifest_file) as f:
                m = json.load(f)
            # Mark strand as WEAVED
            m["status"] = "WEAVED"
            with open(manifest_file, "w") as f:
                json.dump(m, f)

            # 1. Dry run prune
            p_code, p_out, p_err = run_braid("prune", "--repo", repo_dir)
            assert p_code == 0
            p_data = json.loads(p_out)
            assert p_data["dry_run"] is True
            assert p_data["pruned_count"] == 1
            assert os.path.exists(strand_path), "Dry run must NOT remove strand directory"

            # 2. Apply prune
            a_code, a_out, a_err = run_braid("prune", "--repo", repo_dir, "--apply")
            assert a_code == 0
            a_data = json.loads(a_out)
            assert a_data["dry_run"] is False
            assert a_data["pruned_count"] == 1
            assert not os.path.exists(strand_path), "Prune apply MUST remove strand directory"

            # 3. Verify git worktree cleaned up
            wt_out = subprocess.run(["git", "-C", repo_dir, "worktree", "list"], capture_output=True, text=True).stdout
            assert strand_path not in wt_out

        finally:
            if os.path.exists(strand_path):
                subprocess.run(["git", "-C", repo_dir, "worktree", "remove", "--force", strand_path], capture_output=True)
                subprocess.run(["git", "-C", repo_dir, "worktree", "prune"], capture_output=True)
                shutil.rmtree(os.path.dirname(strand_path), ignore_errors=True)

