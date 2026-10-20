import base64
import copy
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

import requests

from controller import Controller
from review_artifacts import artifact, collect_bundle, render_review, validate_bundle
import test_controller
from test_controller import RESULT


class HandoffFixtures(unittest.TestCase):
    setUp = test_controller.ControllerTests.setUp
    tearDown = test_controller.ControllerTests.tearDown
    build = test_controller.ControllerTests.build


class BundleTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.repo = Path(self.directory.name)
        self.git("init", "-q")
        self.git("config", "user.email", "review@example.test")
        self.git("config", "user.name", "Review")
        (self.repo / "initial.txt").write_text("initial\n")
        self.base = self.commit()

    def tearDown(self):
        self.directory.cleanup()

    def git(self, *arguments):
        return subprocess.check_output(["git", "-C", str(self.repo), *arguments],
                                       stderr=subprocess.DEVNULL).decode().strip()

    def commit(self):
        self.git("add", "--all")
        self.git("commit", "-qm", "Change")
        return self.git("rev-parse", "HEAD")

    def test_collects_committed_markdown_binary_and_code_diff_without_worktree_changes(self):
        (self.repo / "guide.md").write_text("# Guide\n\nComplete instructions.\n")
        (self.repo / "diagram.png").write_bytes(b"\x89PNG\r\n\x1a\nbinary")
        (self.repo / "feature.py").write_text("print('ready')\n")
        head = self.commit()
        (self.repo / "guide.md").write_text("uncommitted malicious edit")
        bundle = validate_bundle(collect_bundle(self.repo, self.base, head))
        self.assertEqual(["review.diff", "diagram.png", "guide.md"],
                         [item["path"] for item in bundle["files"]])
        diff = base64.b64decode(bundle["files"][0]["content_base64"])
        self.assertIn(b"feature.py", diff)
        self.assertIn(b"Complete instructions", diff)
        self.assertNotIn(b"uncommitted", diff)

    def test_omits_secret_paths_content_and_symlinks_from_diff_and_attachments(self):
        (self.repo / ".env").write_text("public-looking but private")
        (self.repo / "token.txt").write_text("ghp_" + "a" * 36)
        (self.repo / "link.md").symlink_to("/etc/passwd")
        (self.repo / "safe.md").write_text("# Safe")
        bundle = collect_bundle(self.repo, self.base, self.commit())
        self.assertEqual(["review.diff", "safe.md"], [item["path"] for item in bundle["files"]])
        self.assertEqual(3, len(bundle["omitted"]))
        diff = base64.b64decode(bundle["files"][0]["content_base64"])
        for filename in (b".env", b"token.txt", b"link.md"):
            self.assertNotIn(filename, diff)

    def test_oversized_files_are_reported_and_total_count_is_bounded(self):
        for index in range(26):
            (self.repo / f"guide{index}.md").write_text("# Small")
        (self.repo / "large.md").write_text("x" * 1025)
        with patch("review_artifacts.MAX_FILE_BYTES", 1024):
            bundle = collect_bundle(self.repo, self.base, self.commit())
        self.assertEqual(24, len(bundle["files"]))
        self.assertEqual(4, len(bundle["omitted"]))
        self.assertTrue(any("large.md" in item for item in bundle["omitted"]))

    def test_generated_diff_names_are_preserved_without_colliding_with_review_patch(self):
        for filename in ("review.diff", "review-1.diff"):
            (self.repo / filename).write_text("Generated original " + filename)
        bundle = validate_bundle(collect_bundle(self.repo, self.base, self.commit()))
        self.assertEqual("review-2.diff", bundle["files"][0]["path"])
        self.assertEqual("diff", bundle["files"][0]["kind"])
        originals = {item["path"]: base64.b64decode(item["content_base64"]).decode()
                     for item in bundle["files"][1:]}
        self.assertEqual({filename: "Generated original " + filename
                          for filename in ("review.diff", "review-1.diff")}, originals)

    def test_zero_change_has_downloadable_diff_and_rejects_mutable_refs(self):
        bundle = validate_bundle(collect_bundle(self.repo, self.base, self.base))
        self.assertTrue(bundle["no_changes"])
        self.assertEqual("diff", bundle["files"][0]["kind"])
        with self.assertRaises(ValueError):
            collect_bundle(self.repo, "HEAD", self.base)

    def test_renders_markdown_and_all_uploads_before_truncated_preview_with_explicit_tests(self):
        from types import SimpleNamespace
        bundle = copy.deepcopy(RESULT["review_bundle"])
        bundle["files"] += [artifact("README.md", b"# Guide\n[Details](doc/details.md)\n"),
                            artifact("doc/details.md", b"# Details\n\n\x60\x60\x60python\n" + b"x" * 12000)]
        uploads = [{"path": item["path"], "short_url": "upload://file" + str(index) + ".md"}
                   for index, item in enumerate(bundle["files"])]
        run = SimpleNamespace(review_bundle=bundle, summary="Built guide", tests=[],
                              commit=bundle["head"], preview_url="https://preview.test")
        message = render_review(run, uploads)
        self.assertIn("# Guide", message)
        self.assertIn("[Details](upload://file2.md)", message)
        self.assertIn("[Full diff](upload://file0.md)", message)
        self.assertIn("No test results were reported.", message)
        self.assertIn("Markdown preview truncated", message)
        self.assertLess(message.index("[doc/details.md]"), message.index("# Guide"))
        self.assertEqual(2, message.count("\u0060\u0060\u0060"))
        self.assertLess(len(message), 20000)


class HandoffRetryTests(HandoffFixtures):
    def test_upload_response_loss_retries_after_restart_without_rerunning_coding(self):
        self.controller.poll()
        self.executor.tasks[-1][0].set_result(copy.deepcopy(RESULT))
        original = self.board.review_artifacts
        attempts = []
        def upload(run):
            attempts.append(run.run_id)
            if len(attempts) == 1:
                raise requests.ConnectionError("Upload accepted but response lost")
            return original(run)
        self.board.review_artifacts = upload
        with self.assertRaises(requests.ConnectionError):
            self.controller.poll()
        saved = self.store.all()[0]
        self.assertTrue(saved.review_pending)
        self.assertTrue(saved.review_bundle)
        self.controller = self.build()
        self.controller.poll()
        self.assertEqual("review", self.store.all()[0].phase)
        self.assertFalse(self.store.all()[0].review_pending)
        self.assertEqual(1, len(self.executor.tasks))
        self.assertEqual(2, len(attempts))

    def test_review_response_loss_reconciles_same_run_without_repeating_transition(self):
        self.controller.poll()
        self.board.fail_after_review = True
        self.executor.tasks[-1][0].set_result(copy.deepcopy(RESULT))
        with self.assertRaises(requests.ConnectionError):
            self.controller.poll()
        self.controller = self.build()
        self.controller.poll()
        self.assertEqual("review", self.store.all()[0].phase)
        self.assertEqual(1, len([item for item in self.board.commands if item[0] == "review"]))
        self.assertEqual(1, len(self.executor.tasks))

    def test_pending_handoff_rejects_stale_version_without_rerunning_coding(self):
        self.controller.poll()
        self.executor.tasks[-1][0].set_result(copy.deepcopy(RESULT))
        with patch.object(self.board, "review_artifacts", side_effect=requests.ConnectionError("offline")):
            with self.assertRaises(requests.ConnectionError):
                self.controller.poll()
        self.board.move("TODO")
        self.controller = self.build()
        self.controller.poll()
        self.assertFalse(any(item[0] == "review" for item in self.board.commands))
        self.assertEqual("cancelled", next(iter(self.controller.runs.values())).phase)


if __name__ == "__main__":
    unittest.main()
