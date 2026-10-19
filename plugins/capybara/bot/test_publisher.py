import copy
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import Mock, patch

from publisher import ForkPublisher
from worker.publish import git, push_ref, validate_pr, validate_target

TARGET = {"repository": "discourse/capybara-bot", "repository_id": 1426162178,
          "branch": "capybara", "base_repository": "discourse/discourse", "base_branch": "main", "pull_request": 123}
PR = {"number": 123, "state": "open", "merged": False, "merged_at": None,
      "head": {"ref": "capybara", "sha": "a" * 40,
               "repo": {"id": 1426162178, "full_name": "discourse/capybara-bot"}},
      "base": {"ref": "main", "repo": {"full_name": "discourse/discourse"}}}


class TargetTests(unittest.TestCase):
    def test_only_exact_pr_target_is_allowed(self):
        self.assertEqual("a" * 40, validate_pr(TARGET, PR))
        mutations = [lambda p: p.update(state="closed"), lambda p: p.update(merged=True),
                     lambda p: p["head"]["repo"].update(id=99),
                     lambda p: p["head"]["repo"].update(full_name="attacker/fork"),
                     lambda p: p["head"].update(ref="main"),
                     lambda p: p["base"].update(ref="capybara"),
                     lambda p: p["base"]["repo"].update(full_name="other/repo"),
                     lambda p: p.update(number=124)]
        for mutation in mutations:
            pr = copy.deepcopy(PR)
            mutation(pr)
            with self.assertRaises(ValueError):
                validate_pr(TARGET, pr)

    def test_target_cannot_choose_other_repository_or_ref(self):
        for key, value in [("repository", "discourse/discourse"), ("repository_id", 99),
                           ("branch", "main"), ("pull_request", 0)]:
            with self.assertRaises(ValueError):
                validate_target(dict(TARGET, **{key: value}))

    def test_git_credentials_never_appear_in_arguments_or_logs(self):
        with patch("worker.publish.subprocess.run") as run:
            run.return_value = Mock(returncode=1, stdout="", stderr="secret")
            with self.assertRaisesRegex(RuntimeError, "Restricted Git operation failed") as error:
                git(["ls-remote", "https://github.com/discourse/capybara-bot.git"], "/tmp", {"GIT_ASKPASS": "/askpass"})
            self.assertNotIn("secret", str(error.exception))
            args = run.call_args.args[0]
            self.assertIn("credential.helper=", args)
            self.assertIn("core.hooksPath=/dev/null", args)
            self.assertFalse(any("token" in arg for arg in args))


class RealGitTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.root = Path(self.directory.name)
        self.remote = str(self.root / "remote.git")
        self.local = str(self.root / "local")
        self.env = dict(os.environ, GIT_CONFIG_GLOBAL="/dev/null", GIT_CONFIG_NOSYSTEM="1")
        subprocess.run(["git", "init", "--bare", "-q", self.remote], check=True)
        subprocess.run(["git", "init", "-q", self.local], check=True)
        git(["config", "user.email", "test@localhost"], self.local, self.env)
        git(["config", "user.name", "Test"], self.local, self.env)
        self.a = self.commit("first")
        self.b = self.commit("second")
        self.c = self.commit("third")

    def tearDown(self):
        self.directory.cleanup()

    def commit(self, text):
        Path(self.local, "file").write_text(text)
        git(["add", "."], self.local, self.env)
        git(["commit", "-qm", text], self.local, self.env)
        return git(["rev-parse", "HEAD"], self.local, self.env)

    def head(self, branch="capybara"):
        return git(["ls-remote", self.remote, "refs/heads/" + branch], self.local, self.env).split()[0]

    def test_push_only_target_ref_and_recover_lost_response(self):
        git(["push", "-q", self.remote, self.a + ":refs/heads/unrelated"], self.local, self.env)
        push_ref(self.remote, "capybara", self.a, "", self.local, self.env)
        push_ref(self.remote, "capybara", self.b, self.a, self.local, self.env)
        push_ref(self.remote, "capybara", self.b, self.a, self.local, self.env)
        self.assertEqual(self.b, self.head())
        self.assertEqual(self.a, self.head("unrelated"))

    def test_competing_writer_is_never_overwritten(self):
        push_ref(self.remote, "capybara", self.a, "", self.local, self.env)
        git(["push", "-q", self.remote, self.c + ":refs/heads/capybara"], self.local, self.env)
        with self.assertRaisesRegex(RuntimeError, "changed outside"):
            push_ref(self.remote, "capybara", self.b, self.a, self.local, self.env)
        self.assertEqual(self.c, self.head())

    def test_writer_racing_after_head_check_is_rejected_by_git_lease(self):
        push_ref(self.remote, "capybara", self.a, "", self.local, self.env)
        original = git
        raced = False

        def racing_git(args, cwd, env):
            nonlocal raced
            result = original(args, cwd, env)
            if args[0] == "ls-remote" and not raced:
                raced = True
                original(["push", "-q", self.remote, self.c + ":refs/heads/capybara"], cwd, env)
            return result

        with patch("worker.publish.git", side_effect=racing_git):
            with self.assertRaisesRegex(RuntimeError, "Restricted Git operation failed"):
                push_ref(self.remote, "capybara", self.b, self.a, self.local, self.env)
        self.assertEqual(self.c, self.head())

    def test_readonly_seed_owned_by_host_can_be_imported(self):
        destination = str(self.root / "publication.git")
        subprocess.run(["git", "init", "--bare", "-q", destination], check=True)
        if os.geteuid() == 0:
            subprocess.run(["chown", "-R", "501:501", self.local], check=True)
        self.env["GIT_CONFIG_GLOBAL"] = str(self.root / "safe.config")
        git(["config", "--global", "--add", "safe.directory", self.local], destination, self.env)
        git(["config", "--global", "--add", "safe.directory", self.local + "/.git"], destination, self.env)
        git(["fetch", "--no-tags", self.local, self.c], destination, self.env)
        self.assertEqual(self.c, git(["rev-parse", "FETCH_HEAD"], destination, self.env))

    def test_rebased_history_can_replace_only_known_head(self):
        push_ref(self.remote, "capybara", self.c, "", self.local, self.env)
        push_ref(self.remote, "capybara", self.a, self.c, self.local, self.env)
        self.assertEqual(self.a, self.head())


class JournalTests(unittest.TestCase):
    def test_missing_journal_refuses_implicit_adoption(self):
        with tempfile.TemporaryDirectory() as directory, patch.dict(os.environ, {"DATA_DIR": directory, "PUBLISHER_TARGET": directory + "/target"}):
            Path(directory, "target").write_text(json.dumps(TARGET))
            publisher = ForkPublisher(Mock(), Mock(), Mock())
            with self.assertRaisesRegex(RuntimeError, "not been bootstrapped"):
                publisher.push(Mock(integrated_commit="a" * 40), Mock())

    def test_failed_push_retains_pending_commit_and_different_commit_is_blocked(self):
        with tempfile.TemporaryDirectory() as directory, patch.dict(os.environ, {"DATA_DIR": directory, "PUBLISHER_TARGET": directory + "/target"}):
            Path(directory, "target").write_text(json.dumps(TARGET))
            publisher = ForkPublisher(Mock(), Mock(), Mock())
            publisher.save({"target": TARGET, "head": "a" * 40, "pending": "b" * 40})
            with self.assertRaisesRegex(RuntimeError, "different commit"):
                publisher.push(Mock(integrated_commit="c" * 40), Mock())
            self.assertEqual("b" * 40, json.loads(publisher.journal_path.read_text())["pending"])
            self.assertEqual(0o600, publisher.journal_path.stat().st_mode & 0o777)

    def test_failed_push_persists_intent_and_removes_token_container(self):
        with tempfile.TemporaryDirectory() as directory, patch.dict(os.environ, {
                "DATA_DIR": directory, "PUBLISHER_TARGET": directory + "/target",
                "GITHUB_FORK_TOKEN": directory + "/token"}):
            Path(directory, "target").write_text(json.dumps(TARGET))
            Path(directory, "token").write_text("fixture-token")
            runtime = Mock()
            runtime.exec.side_effect = RuntimeError("Network unavailable")
            client = Mock()
            client.containers.get.side_effect = __import__("docker").errors.NotFound("missing")
            config = Mock(board_id=1, worker_image="worker", seed="/source")
            publisher = ForkPublisher(config, client, runtime)
            publisher.save({"target": TARGET, "head": "a" * 40, "pending": ""})
            run = Mock(integrated_commit="b" * 40, card_id=2, run_id="run", container_name="card-run")
            with self.assertRaisesRegex(RuntimeError, "Network unavailable"):
                publisher.push(run, Mock())
            self.assertEqual("b" * 40, json.loads(publisher.journal_path.read_text())["pending"])
            created = client.containers.create
            self.assertEqual({"/source": {"bind": "/seed", "mode": "ro"}}, created.call_args.kwargs["volumes"])
            self.assertEqual("publisher", created.call_args.kwargs["labels"]["role"])
            self.assertNotIn("tmpfs", created.call_args.kwargs)
            created.return_value.exec_run.assert_called_with(["rm", "-f", "/run/github-token"])
            created.return_value.remove.assert_called_with(force=True)
            self.assertFalse(any("fixture-token" in str(call) for call in runtime.exec.call_args_list))
