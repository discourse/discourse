import copy
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import Mock, patch

from publisher import ForkPublisher
from worker.publish import git, push_ref, validate_pr, validate_target, publish, github, sanitize
import io
import urllib.error

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
            run.return_value = Mock(returncode=1, stdout="", stderr="remote denied github_pat_secret123 https://user:password@github.com/x Basic abc123")
            with self.assertRaisesRegex(RuntimeError, "Restricted Git operation failed") as error:
                git(["ls-remote", "https://github.com/discourse/capybara-bot.git"], "/tmp", {"GIT_ASKPASS": "/askpass"})
            self.assertNotIn("github_pat_secret123", str(error.exception))
            self.assertNotIn("password", str(error.exception))
            self.assertNotIn("abc123", str(error.exception))
            self.assertIn("remote denied", str(error.exception))
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


class ConfirmationTests(unittest.TestCase):
    def test_accepted_push_survives_stale_pr_and_retry_is_read_only(self):
        commit = "b" * 40
        current = "a" * 40
        stale = copy.deepcopy(PR)
        fresh = copy.deepcopy(PR)
        fresh["head"]["sha"] = commit
        calls = []

        def api(path, token):
            return {"object": {"sha": current}} if "/git/ref/" in path else stale

        def command(args, cwd, env):
            nonlocal current
            calls.append(args[0])
            if args[0] == "ls-remote":
                return current + " refs/heads/capybara"
            if args[0] == "push":
                current = commit
            return ""

        with tempfile.TemporaryDirectory() as directory, patch("worker.publish.github", side_effect=api), patch("worker.publish.git", side_effect=command):
            first = publish(TARGET, commit, "a" * 40, "/token", destination=directory)
            self.assertEqual("confirming", first["status"])
            self.assertEqual("metadata_lag", first["diagnostic"]["reason"])
            self.assertEqual("a" * 40, first["diagnostic"]["observed_sha"])
            self.assertEqual(commit, json.loads(Path(directory, "accepted.json").read_text())["commit"])
            self.assertEqual(1, calls.count("push"))
            stale["head"]["sha"] = commit
            calls.clear()
            second = publish(TARGET, commit, "a" * 40, "/token", destination=directory, confirm_only=True)
            self.assertEqual("confirmed", second["status"])
            self.assertEqual([], calls)
            current = "a" * 40
            rewound = publish(TARGET, commit, "a" * 40, "/token", destination=directory, confirm_only=True)
            self.assertEqual("branch_changed", rewound["diagnostic"]["reason"])
            self.assertEqual([], calls)

    def test_closed_pr_after_acceptance_is_not_confirmed_or_republished(self):
        closed = copy.deepcopy(PR)
        closed["state"] = "closed"
        with patch("worker.publish.github", side_effect=[{"object": {"sha": "b" * 40}}, closed]), patch("worker.publish.git") as command, tempfile.TemporaryDirectory() as directory:
            result = publish(TARGET, "b" * 40, "a" * 40, "/token", destination=directory, confirm_only=True)
            self.assertEqual("confirming", result["status"])
            self.assertIn("closed", result["diagnostic"]["mismatches"])
            command.assert_not_called()

    def test_http_error_keeps_safe_diagnostics(self):
        headers = {"X-GitHub-Request-Id": "REQ-123", "Retry-After": "30", "X-RateLimit-Reset": "12345"}
        error = urllib.error.HTTPError("https://api.github.com/x", 503, "Unavailable", headers,
                                      io.BytesIO(b'{"message":"temporarily unavailable github_pat_abc123"}'))
        with tempfile.TemporaryDirectory() as directory:
            token = Path(directory, "token")
            token.write_text("github_pat_abc123")
            with patch("worker.publish.urllib.request.urlopen", side_effect=error):
                with self.assertRaises(RuntimeError) as raised:
                    github("repos/test", token)
            detail = raised.exception.details
            self.assertEqual("503", detail["status"])
            self.assertEqual("REQ-123", detail["request_id"])
            self.assertEqual("30", detail["retry_after"])
            self.assertNotIn("github_pat_abc123", str(raised.exception))

    def test_previous_receipt_is_recovered_before_container_removal(self):
        with tempfile.TemporaryDirectory() as directory, patch.dict(os.environ, {
                "DATA_DIR": directory, "PUBLISHER_TARGET": directory + "/target",
                "GITHUB_FORK_TOKEN": directory + "/token"}):
            Path(directory, "target").write_text(json.dumps(TARGET))
            Path(directory, "token").write_text("fixture-token")
            runtime, client = Mock(), Mock()
            result = {"commit": "b" * 40, "pull_request_url": "https://github.com/discourse/discourse/pull/123",
                      "status": "confirming", "diagnostic": {"reason": "metadata_lag"}}
            runtime.read.side_effect = lambda container, path: json.dumps(result)
            publisher = ForkPublisher(Mock(board_id=1, worker_image="worker", seed="/source"), client, runtime)
            publisher.save({"target": TARGET, "head": "a" * 40, "pending": "b" * 40})
            run = Mock(integrated_commit="b" * 40, card_id=2, run_id="run", container_name="card-run", phase="publishing")
            client.containers.get.return_value.labels = {"owner": "codex-board-bot", "board_id": "1", "card_id": "2", "run_id": "run", "role": "publisher"}
            returned = publisher.push(run, Mock())
            self.assertEqual("confirming", returned["status"])
            self.assertIn("--confirm-only", runtime.exec.call_args.args[1])
            self.assertEqual("b" * 40, json.loads(publisher.journal_path.read_text())["accepted"])
            self.assertIn("metadata_lag", Path(returned["log_path"]).read_text())
            client.containers.create.return_value.remove.assert_called_once_with(force=True)

    def test_nonzero_helper_retains_specific_error_after_container_removal(self):
        with tempfile.TemporaryDirectory() as directory, patch.dict(os.environ, {
                "DATA_DIR": directory, "PUBLISHER_TARGET": directory + "/target",
                "GITHUB_FORK_TOKEN": directory + "/token"}):
            Path(directory, "target").write_text(json.dumps(TARGET))
            Path(directory, "token").write_text("fixture-token")
            runtime, client = Mock(), Mock()
            runtime.exec.side_effect = RuntimeError("Worker command exited 1")
            def read(container, path):
                if path.endswith("accepted.json"):
                    raise FileNotFoundError()
                return json.dumps({"status": "failed", "diagnostic": {"status": "503", "request_id": "REQ-456"}})
            runtime.read.side_effect = read
            client.containers.get.side_effect = __import__("docker").errors.NotFound("missing")
            publisher = ForkPublisher(Mock(board_id=1, worker_image="worker", seed="/source"), client, runtime)
            publisher.save({"target": TARGET, "head": "a" * 40, "pending": ""})
            run = Mock(integrated_commit="b" * 40, card_id=2, run_id="run", container_name="card-run", phase="publishing")
            with self.assertRaisesRegex(RuntimeError, "REQ-456"):
                publisher.push(run, Mock())
            log = Path(directory, "publication/run.jsonl").read_text()
            self.assertIn("503", log)
            self.assertIn("REQ-456", log)
            self.assertNotIn("fixture-token", log)
            client.containers.create.return_value.remove.assert_called_once_with(force=True)

    def test_fatal_helper_output_is_saved_and_redacted(self):
        with tempfile.TemporaryDirectory() as directory, patch.dict(os.environ, {
                "DATA_DIR": directory, "PUBLISHER_TARGET": directory + "/target",
                "GITHUB_FORK_TOKEN": directory + "/token"}):
            Path(directory, "target").write_text(json.dumps(TARGET))
            Path(directory, "token").write_text("nonstandard-fixture-secret")
            runtime, client = Mock(), Mock()
            runtime.exec.side_effect = RuntimeError("Worker command exited 1")
            def read(container, path):
                if path.endswith("process.log"):
                    return "SyntaxError fixture nonstandard-fixture-secret Basic abc123"
                raise FileNotFoundError()
            runtime.read.side_effect = read
            client.containers.get.side_effect = __import__("docker").errors.NotFound("missing")
            publisher = ForkPublisher(Mock(board_id=1, worker_image="worker", seed="/source"), client, runtime)
            publisher.save({"target": TARGET, "head": "a" * 40, "pending": ""})
            run = Mock(integrated_commit="b" * 40, card_id=2, run_id="run", container_name="card-run", phase="publishing")
            with self.assertRaisesRegex(RuntimeError, "SyntaxError"):
                publisher.push(run, Mock())
            log = Path(directory, "publication/run.jsonl").read_text()
            self.assertNotIn("nonstandard-fixture-secret", log)
            self.assertNotIn("abc123", log)
            self.assertIn("SyntaxError", log)
            client.containers.create.return_value.remove.assert_called_once_with(force=True)

    def test_cleanup_failure_after_acceptance_retains_confirm_only_retry(self):
        with tempfile.TemporaryDirectory() as directory, patch.dict(os.environ, {
                "DATA_DIR": directory, "PUBLISHER_TARGET": directory + "/target",
                "GITHUB_FORK_TOKEN": directory + "/token"}):
            Path(directory, "target").write_text(json.dumps(TARGET))
            Path(directory, "token").write_text("fixture-token")
            runtime, client = Mock(), Mock()
            result = {"commit": "b" * 40, "pull_request_url": "https://github.com/discourse/discourse/pull/123", "status": "confirmed"}
            runtime.read.side_effect = lambda container, path: json.dumps(result)
            client.containers.get.side_effect = __import__("docker").errors.NotFound("missing")
            container = client.containers.create.return_value
            container.remove.side_effect = RuntimeError("Docker cleanup unavailable")
            publisher = ForkPublisher(Mock(board_id=1, worker_image="worker", seed="/source"), client, runtime)
            publisher.save({"target": TARGET, "head": "a" * 40, "pending": ""})
            run = Mock(integrated_commit="b" * 40, card_id=2, run_id="run", container_name="card-run", phase="publishing")
            first = publisher.push(run, Mock())
            self.assertEqual("confirming", first["status"])
            self.assertIn("cleanup unavailable", first["diagnostic"]["message"])
            self.assertEqual("b" * 40, json.loads(publisher.journal_path.read_text())["accepted"])
            container.remove.side_effect = None
            second = publisher.push(run, Mock())
            self.assertEqual("confirmed", second["status"])
            self.assertIn("--confirm-only", runtime.exec.call_args.args[1])
            self.assertEqual("", json.loads(publisher.journal_path.read_text())["accepted"])
