import importlib.util
import json
import os
import pwd
import shutil
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location("integrate", Path(__file__).parent / "worker/integrate.py")
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
Integrator = module.Integrator


class GitIntegrationTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.root.chmod(0o755)
        self.upstream, self.source, self.card = [self.root / name for name in ("upstream", "source", "card")]
        self.upstream.mkdir()
        self.git(self.upstream, "init", "-b", "main")
        self.identity(self.upstream)
        (self.upstream / "feature.txt").write_text("base\n")
        (self.upstream / "README.txt").write_text("upstream\n")
        self.commit(self.upstream, "Upstream baseline")
        self.git(self.root, "clone", str(self.upstream), str(self.source))
        self.identity(self.source)
        self.git(self.source, "switch", "-c", "capybara")
        (self.source / "plugin.txt").write_text("capybara plugin\n")
        self.commit(self.source, "Add capybara plugin")
        self.base = self.head(self.source)
        self.git(self.root, "clone", str(self.source), str(self.card))
        self.identity(self.card)
        (self.card / "card.txt").write_text("accepted card\n")
        self.commit(self.card, "Implement card")
        self.card_commit = self.head(self.card)
        self.work = self.root / "integration"

    def tearDown(self):
        self.temp.cleanup()

    @staticmethod
    def git(path, *args):
        return subprocess.check_output(["git", "-c", f"safe.directory={path}", "-C", str(path), *args], stderr=subprocess.STDOUT, text=True).strip()

    def identity(self, path):
        self.git(path, "config", "user.email", "test@example.invalid")
        self.git(path, "config", "user.name", "Test User")

    def commit(self, path, message):
        self.git(path, "add", "-A")
        self.git(path, "commit", "-m", message)

    def head(self, path):
        return self.git(path, "rev-parse", "HEAD")

    def integrator(self, **kwargs):
        return Integrator(self.source, self.card, self.work, "12345678-test-run", self.card_commit,
                          self.base, upstream=str(self.upstream), validator=lambda *_: None, **kwargs)

    def test_accepted_card_and_local_plugin_rebase_onto_latest_official_branch(self):
        (self.upstream / "README.txt").write_text("new upstream\n")
        self.commit(self.upstream, "Latest upstream change")
        upstream = self.head(self.upstream)
        old = self.head(self.source)
        result = self.integrator().run()
        self.assertEqual("capybara", self.git(self.source, "branch", "--show-current"))
        self.assertEqual(result["commit"], self.head(self.source))
        self.assertEqual("new upstream\n", (self.source / "README.txt").read_text())
        self.assertEqual("accepted card\n", (self.source / "card.txt").read_text())
        self.assertEqual("capybara plugin\n", (self.source / "plugin.txt").read_text())
        self.assertEqual(upstream, self.git(self.source, "merge-base", upstream, "HEAD"))
        self.assertEqual(old, self.git(self.source, "rev-parse", "refs/capybara-bot/backups/12345678-test-run"))
        self.assertEqual("", self.git(self.source, "status", "--porcelain"))
        self.assertIn("Capybara-Run: 12345678-test-run", self.git(self.source, "log", "-1", "--format=%B"))

    def test_restart_after_publish_does_not_duplicate_card_commit(self):
        first = self.integrator().run()
        (self.work / "result.json").unlink()
        second = self.integrator().run()
        self.assertEqual(first["commit"], second["commit"])
        self.assertTrue(second["recovered"])
        self.assertEqual(1, int(self.git(self.source, "rev-list", "--count", "HEAD", "--grep=Capybara-Run:")))

    def test_real_conflict_is_resolved_without_discarding_either_request(self):
        (self.source / "feature.txt").write_text("capybara request\n")
        self.commit(self.source, "Concurrent capybara change")
        (self.card / "feature.txt").write_text("card request\n")
        self.commit(self.card, "Card changes same line")
        self.card_commit = self.head(self.card)
        calls = []
        def resolve(operation, paths):
            calls.append((operation, paths))
            (self.work / "repo/feature.txt").write_text("capybara request and card request\n")
            self.git(self.work / "repo", "add", "feature.txt")
        self.integrator(resolver=resolve).run()
        self.assertEqual([("merge", ["feature.txt"])], calls)
        self.assertEqual("capybara request and card request\n", (self.source / "feature.txt").read_text())

    def test_upstream_rebase_conflict_resolution_survives_publication(self):
        (self.source / "feature.txt").write_text("local intent\n")
        self.commit(self.source, "Local change to feature")
        (self.upstream / "feature.txt").write_text("upstream intent\n")
        self.commit(self.upstream, "Upstream change to feature")
        calls = []
        def resolve(operation, paths):
            calls.append(operation)
            (self.work / "repo/feature.txt").write_text("local intent plus upstream intent\n")
            self.git(self.work / "repo", "add", "feature.txt")
        self.integrator(resolver=resolve).run()
        self.assertEqual(["rebase"], calls)
        self.assertEqual("local intent plus upstream intent\n", (self.source / "feature.txt").read_text())
        self.assertEqual("accepted card\n", (self.source / "card.txt").read_text())

    def test_dirty_source_is_preserved(self):
        (self.source / "README.txt").write_text("unsaved human edit\n")
        before = self.head(self.source)
        with self.assertRaisesRegex(RuntimeError, "uncommitted changes"):
            self.integrator().run()
        self.assertEqual(before, self.head(self.source))
        self.assertEqual("unsaved human edit\n", (self.source / "README.txt").read_text())

    def test_ref_written_before_reset_is_recovered(self):
        instance = self.integrator()
        def crash(result, original):
            instance.git(instance.source, "update-ref", instance.ref, result["commit"])
            raise RuntimeError("simulated crash before reset")
        instance.publish = crash
        with self.assertRaisesRegex(RuntimeError, "simulated crash"):
            instance.run()
        result = self.integrator().run()
        self.assertTrue(result["published"])
        self.assertEqual(result["commit"], self.head(self.source))

    def test_card_started_before_previous_upstream_rebase_only_adds_its_patch(self):
        (self.upstream / "README.txt").write_text("upstream ahead\n")
        self.commit(self.upstream, "New upstream")
        self.git(self.source, "fetch", str(self.upstream), "main")
        self.git(self.source, "rebase", "FETCH_HEAD")
        self.assertNotEqual(self.base, self.head(self.source))
        self.integrator().run()
        self.assertEqual(1, int(self.git(self.source, "rev-list", "--count", "HEAD", "--grep=Add capybara plugin")))
        self.assertEqual("accepted card\n", (self.source / "card.txt").read_text())

    def test_shallow_worker_card_can_be_integrated(self):
        shutil.rmtree(self.card)
        self.git(self.root, "clone", "--depth", "1", "--branch", "capybara", self.source.as_uri(), str(self.card))
        self.identity(self.card)
        self.assertEqual("true", self.git(self.card, "rev-parse", "--is-shallow-repository"))
        (self.card / "card.txt").write_text("shallow accepted card\n")
        self.commit(self.card, "Shallow worker commit")
        self.card_commit = self.head(self.card)
        self.integrator().run()
        self.assertEqual("shallow accepted card\n", (self.source / "card.txt").read_text())

    def test_competing_human_commit_between_check_and_publication_is_preserved(self):
        instance = self.integrator()
        git = instance.git
        human_head = []
        def racing_git(path, *args, **kwargs):
            if args[:2] == ("update-ref", "refs/heads/capybara"):
                (self.source / "human.txt").write_text("human commit\n")
                self.commit(self.source, "Concurrent human commit")
                human_head.append(self.head(self.source))
            return git(path, *args, **kwargs)
        instance.git = racing_git
        with self.assertRaisesRegex(RuntimeError, "update-ref failed"):
            instance.run()
        self.assertEqual(human_head[0], self.head(self.source))
        self.assertEqual("human commit\n", (self.source / "human.txt").read_text())
        self.assertFalse((self.source / "card.txt").exists())

    def test_human_worktree_edit_before_read_tree_is_preserved(self):
        (self.card / "feature.txt").write_text("card feature change\n")
        self.commit(self.card, "Change feature")
        self.card_commit = self.head(self.card)
        original = self.head(self.source)
        instance = self.integrator()
        git = instance.git
        def racing_git(path, *args, **kwargs):
            if args[0] == "read-tree":
                (self.source / "feature.txt").write_text("human unsaved edit\n")
            return git(path, *args, **kwargs)
        instance.git = racing_git
        with self.assertRaisesRegex(RuntimeError, "read-tree failed"):
            instance.run()
        self.assertEqual(original, self.head(self.source))
        self.assertEqual("human unsaved edit\n", (self.source / "feature.txt").read_text())

    def test_crash_after_atomic_branch_update_recovers_worktree(self):
        instance = self.integrator()
        git = instance.git
        def crashing_git(path, *args, **kwargs):
            result = git(path, *args, **kwargs)
            if args[:2] == ("update-ref", "refs/heads/capybara"):
                raise RuntimeError("simulated crash after branch update")
            return result
        instance.git = crashing_git
        with self.assertRaisesRegex(RuntimeError, "simulated crash after branch update"):
            instance.run()
        self.assertFalse((self.source / "card.txt").exists())
        result = self.integrator().run()
        self.assertTrue(result["published"])
        self.assertEqual("accepted card\n", (self.source / "card.txt").read_text())
        self.assertEqual("", self.git(self.source, "status", "--porcelain"))

    def test_dependency_manifest_conflicts_are_resolved_before_validation(self):
        (self.source / "package.json").write_text('{"features":["replies"]}\n')
        self.commit(self.source, "Add replies dependency")
        (self.card / "package.json").write_text('{"features":["images"]}\n')
        self.commit(self.card, "Add images dependency")
        self.card_commit = self.head(self.card)
        def resolve(operation, paths):
            self.assertEqual(["package.json"], paths)
            (self.work / "repo/package.json").write_text('{"features":["replies","images"]}\n')
            self.git(self.work / "repo", "add", "package.json")
        instance = self.integrator(resolver=resolve)
        instance.validator = lambda *_: self.assertEqual(
            ["replies", "images"], json.loads((self.work / "repo/package.json").read_text())["features"])
        instance.run()
        self.assertEqual(["replies", "images"], json.loads((self.source / "package.json").read_text())["features"])

    def test_candidate_git_commands_cannot_write_source_through_config_hooks(self):
        instance = self.integrator()
        instance.run()
        with tempfile.NamedTemporaryFile(dir="/var/tmp", delete=False) as output:
            protected = Path(output.name)
        try:
            protected.write_text("protected")
            protected.chmod(0o666)
            hook = instance.repo / "malicious-fsmonitor.sh"
            hook.write_text(f"#!/bin/sh\necho escaped > {protected}\n")
            hook.chmod(0o755)
            instance.git(instance.repo, "config", "core.fsmonitor", str(hook))
            instance.git(instance.repo, "status", "--porcelain")
            self.assertEqual("protected", protected.read_text())
        finally:
            protected.unlink()

    def test_sequential_conflicts_reuse_refreshed_authentication(self):
        instance = self.integrator()
        instance.work.mkdir()
        instance.repo.mkdir()
        initial = self.root / "original-auth.json"
        refreshed = self.root / "refreshed-auth.json"
        initial.write_text('{"token":"v1"}')
        seen = []
        def remap(value):
            if str(value) == "/run/codex-auth.json":
                return initial
            if str(value) == "/run/refreshed-auth.json":
                return refreshed
            return Path(value)
        def codex(command, **kwargs):
            self.assertEqual("gpt-6.1-sol", command[command.index("--model") + 1])
            self.assertEqual('model_reasoning_effort="medium"', command[command.index("-c") + 1])
            auth = instance.work / "codex-home/auth.json"
            seen.append(json.loads(auth.read_text())["token"])
            auth.write_text(json.dumps({"token": f"v{len(seen) + 1}"}))
        with patch.object(module, "Path", side_effect=remap), patch.object(module.subprocess, "run", side_effect=codex):
            instance.resolve_conflicts("merge", ["feature.txt"])
            instance.resolve_conflicts("rebase", ["feature.txt"])
        self.assertEqual(["v1", "v2"], seen)
        self.assertEqual("v3", json.loads(refreshed.read_text())["token"])
        self.assertTrue(initial.exists())
        self.assertFalse((instance.work / "codex-home/auth.json").exists())


class ConflictSandboxTests(unittest.TestCase):
    @unittest.skipUnless(os.geteuid() == 0, "requires the root builder used by the integrator")
    def test_agent_can_write_workspace_but_cannot_write_source_or_use_sudo(self):
        try:
            pwd.getpwnam("discourse")
        except KeyError:
            self.skipTest("requires the worker image discourse account")
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            root.chmod(0o777)
            allowed = root / "workspace"
            allowed.mkdir(mode=0o777)
            allowed.chmod(0o777)
            protected = root / "source.txt"
            protected.write_text("protected")
            protected.chmod(0o666)
            script = f"""import pathlib, subprocess
pathlib.Path({str(allowed / 'allowed.txt')!r}).write_text('allowed')
p = pathlib.Path({str(protected)!r})
r = subprocess.run(['sudo', '-n', 'id', '-u'], capture_output=True)
assert r.returncode != 0, 'sudo escaped no_new_privs'
try:
    p.write_text('escaped')
    raise AssertionError('source writable')
except PermissionError:
    pass
"""
            subprocess.run(["python3", "-c", script], check=True,
                           preexec_fn=module.sandbox_child([str(allowed)], "discourse"))
            self.assertEqual("protected", protected.read_text())
            self.assertEqual("allowed", (allowed / "allowed.txt").read_text())


if __name__ == "__main__":
    unittest.main()
