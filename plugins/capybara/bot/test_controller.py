import argparse
import concurrent.futures
import copy
import tempfile
import time
import unittest
from unittest.mock import Mock, patch

import requests
import docker

from controller import Board, Conflict, Controller, Run, Runtime, Store, prompt_for


class BoardDouble:
    def __init__(self):
        self.card = {"id": 3, "title": "Initial title", "notes": "Initial notes", "discussion": [],
                     "column": "TODO", "column_id": 1, "version": "1", "run": None}
        self.commands = []
        self.serial = 1
        self.archived = False
        self.deleted = False
        self.claim_edit = None
        self.fail_after_claim = False
        self.fail_after_review = False

    def snapshot(self):
        return {"board_id": 1, "archived": self.archived,
                "columns": {"BACKLOG": 5, "TODO": 1, "IN PROGRESS": 2, "REVIEW": 3, "DONE": 4, "ARCHIVED": 6},
                "cards": [] if self.deleted else [copy.deepcopy(self.card)]}

    def move(self, column):
        self.serial += 1
        self.card.update(column=column, version=str(self.serial))

    def transition(self, command, run, message=""):
        if self.card["version"] != run.claimed_version:
            raise Conflict()
        self.commands.append((command, run.run_id, message))
        if command == "claim":
            if self.claim_edit:
                self.card.update(self.claim_edit)
            self.move("IN PROGRESS")
            self.card["run"] = {"run_id": run.run_id, "status": "running"}
            if self.fail_after_claim:
                self.fail_after_claim = False
                raise requests.ConnectionError("Claim accepted but response lost")
        elif command == "review":
            self.move("REVIEW")
            if self.fail_after_review:
                self.fail_after_review = False
                raise requests.ConnectionError("Review accepted but response lost")
        elif command == "archive":
            self.move("ARCHIVED")
            self.card["run"] = {"run_id": run.run_id, "status": "done"}
        elif command in ("failed", "done"):
            self.move(self.card["column"])
        return copy.deepcopy(self.card)


class RuntimeDouble:
    def __init__(self):
        self.cleaned = []
        self.live = True
        self.cleanup_error = False

    def collect_volumes(self, runs, cards, jobs):
        return {}

    def reconcile(self):
        pass

    def integrate(self, run, event):
        raise AssertionError("Manual executor runs no threads")

    def publish(self, run, event):
        raise AssertionError("Manual executor runs no threads")

    def deploy(self, run, event):
        raise AssertionError("Manual executor runs no threads")

    def execute(self, run, event):
        raise AssertionError("Manual executor runs no threads")

    def cleanup(self, run):
        self.cleaned.append((run.container_name, run.tunnel_name))
        if self.cleanup_error:
            raise RuntimeError("Docker unavailable")

    def exists(self, run):
        return self.live


class Executor:
    def __init__(self):
        self.tasks = []

    def submit(self, function, run, event):
        future = concurrent.futures.Future()
        self.tasks.append((future, run, event))
        return future


RESULT = {"preview_url": "https://preview.ngrok.dev", "commit": "a" * 40,
          "base_commit": "b" * 40, "summary": "Implemented requested feature", "tests": ["Focused spec passes"]}


class ControllerTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.board = BoardDouble()
        self.runtime = RuntimeDouble()
        self.store = Store(self.directory.name + "/state.sqlite3")
        self.executor = Executor()
        self.controller = self.build()

    def tearDown(self):
        self.store.connection.close()
        self.directory.cleanup()

    def build(self):
        return Controller(self.board, self.runtime, self.store, executor=self.executor)

    def complete(self):
        self.executor.tasks[-1][0].set_result(copy.deepcopy(RESULT))
        self.controller.poll()

    def test_volume_cleanup_requires_successful_board_snapshot(self):
        self.runtime.collect_volumes = Mock()
        with patch.object(self.board, "snapshot", side_effect=requests.ConnectionError("unavailable")):
            with self.assertRaises(requests.ConnectionError):
                self.controller.poll()
        self.runtime.collect_volumes.assert_not_called()

    def test_volume_cleanup_sees_integration_phase_and_live_job(self):
        self.controller.poll()
        self.complete()
        run = next(iter(self.controller.runs.values()))
        self.board.move("DONE")
        self.runtime.collect_volumes = Mock(return_value={})
        self.controller.poll()
        runs, cards, jobs = self.runtime.collect_volumes.call_args.args
        self.assertEqual("integrating", runs[0].phase)
        self.assertIn(run.run_id, jobs)
        self.assertEqual("DONE", cards[run.card_id]["column"])

    def test_claim_uses_latest_locked_card_contents(self):
        self.board.claim_edit = {"title": "Latest title", "notes": "Latest requirement",
                                 "discussion": [{"author": "PM", "raw": "New acceptance criteria"}]}
        self.controller.poll()
        prompt = prompt_for(self.executor.tasks[0][1].card)
        self.assertIn("Latest title", prompt)
        self.assertIn("Latest requirement", prompt)
        self.assertIn("New acceptance criteria", prompt)
        self.assertEqual("IN PROGRESS", self.board.card["column"])

    def test_success_publishes_exact_impersonation_links(self):
        self.controller.poll()
        self.complete()
        self.assertEqual("REVIEW", self.board.card["column"])
        message = self.board.commands[-1][2]
        self.assertIn("https://preview.ngrok.dev/session/admin-account/become", message)
        self.assertIn("https://preview.ngrok.dev/session/user-account/become", message)
        self.assertIn("Focused spec passes", message)
        self.assertEqual([], self.runtime.cleaned)

    def test_stale_future_never_moves_card_to_review(self):
        self.controller.poll()
        old = self.executor.tasks[0]
        self.board.move("TODO")
        old[0].set_result(copy.deepcopy(RESULT))
        self.controller.poll()
        self.assertTrue(old[2].is_set())
        self.assertFalse(any(command[0] == "review" for command in self.board.commands))
        self.assertEqual("IN PROGRESS", self.board.card["column"])
        self.assertEqual(2, len(self.executor.tasks))
        self.assertNotEqual(old[1].run_id, self.executor.tasks[-1][1].run_id)

    def test_done_removes_only_run_resources_and_preserves_volumes(self):
        self.controller.poll()
        run = self.executor.tasks[0][1]
        self.complete()
        self.board.move("DONE")
        self.controller.poll()
        self.assertEqual([(run.container_name, run.tunnel_name)], self.runtime.cleaned)
        self.assertEqual("integrating", self.store.all()[0].phase)
        self.assertEqual(run.workspace_volume, self.store.all()[0].workspace_volume)
        self.assertFalse(any(command[0] == "done" for command in self.board.commands))
        self.executor.tasks[-1][0].set_result({"commit": "c" * 40})
        self.controller.poll()
        self.assertEqual("deploying", self.store.all()[0].phase)
        self.executor.tasks[-1][0].set_result({"commit": "c" * 40})
        self.controller.poll()
        self.assertEqual("publishing", self.store.all()[0].phase)
        self.executor.tasks[-1][0].set_result({"commit": "c" * 40, "pull_request_url": "https://github.com/discourse/discourse/pull/123"})
        self.controller.poll()
        self.assertEqual("done", self.store.all()[0].phase)
        self.assertEqual("archive", self.board.commands[-1][0])
        self.assertEqual("ARCHIVED", self.board.card["column"])
        self.assertIn("c" * 40, self.board.commands[-1][2])

    def test_done_acknowledgement_waits_for_successful_cleanup(self):
        self.controller.poll()
        self.complete()
        self.runtime.cleanup_error = True
        self.board.move("DONE")
        self.controller.poll()
        self.assertFalse(any(command[0] == "done" for command in self.board.commands))
        self.assertTrue(self.store.all()[0].cleanup_pending)
        self.runtime.cleanup_error = False
        self.controller.poll()
        self.assertEqual("integrating", self.store.all()[0].phase)
        self.assertFalse(self.store.all()[0].cleanup_pending)
        self.assertEqual(2, len(self.executor.tasks))

    def test_retry_uses_fresh_workspace_and_reads_new_card(self):
        self.controller.poll()
        previous = self.executor.tasks[-1][1]
        self.complete()
        self.board.card.update(notes="Revised acceptance criteria")
        self.board.move("TODO")
        self.controller.poll()
        successor = self.executor.tasks[-1][1]
        self.assertNotEqual(previous.run_id, successor.run_id)
        self.assertNotEqual(previous.workspace_volume, successor.workspace_volume)
        self.assertEqual(previous.codex_volume, successor.codex_volume)
        self.assertEqual("Revised acceptance criteria", successor.card["notes"])

    def test_restart_recovers_owned_running_generation(self):
        self.controller.poll()
        previous = self.executor.tasks[-1][1]
        self.executor = Executor()
        self.controller = self.build()
        self.controller.poll()
        recovered = self.executor.tasks[0][1]
        self.assertEqual(previous.run_id, recovered.run_id)
        self.assertEqual(previous.card, recovered.card)
        self.assertEqual([(previous.container_name, previous.tunnel_name)], self.runtime.cleaned)

    def test_restart_does_not_hijack_manually_moved_in_progress_card(self):
        self.board.move("IN PROGRESS")
        self.controller.poll()
        self.assertEqual([], self.executor.tasks)
        self.assertEqual([], self.store.all())

    def test_restart_keeps_live_review_preview(self):
        self.controller.poll()
        self.complete()
        self.executor = Executor()
        self.controller = self.build()
        self.controller.poll()
        self.assertEqual([], self.executor.tasks)
        self.assertEqual([], self.runtime.cleaned)
        self.assertEqual("review", self.store.all()[0].phase)

    def test_failed_job_waits_for_explicit_todo_retry(self):
        self.controller.poll()
        self.executor.tasks[-1][0].set_exception(RuntimeError("Meaningful spec failed"))
        self.controller.poll()
        self.controller.poll()
        self.assertEqual("IN PROGRESS", self.board.card["column"])
        self.assertEqual(1, len(self.executor.tasks))
        self.assertEqual("failed", self.store.all()[0].phase)
        self.assertIn("Meaningful spec failed", self.board.commands[-1][2])
        self.board.move("TODO")
        self.controller.poll()
        self.assertEqual(2, len(self.executor.tasks))

    def test_response_lost_after_claim_recovers_same_generation(self):
        self.board.fail_after_claim = True
        with self.assertRaises(requests.ConnectionError):
            self.controller.poll()
        identity = self.store.all()[0].run_id
        self.controller.poll()
        self.assertEqual(identity, self.executor.tasks[0][1].run_id)
        self.assertEqual(1, len(self.board.commands))

    def test_response_lost_after_review_keeps_preview(self):
        self.controller.poll()
        self.board.fail_after_review = True
        self.executor.tasks[0][0].set_result(copy.deepcopy(RESULT))
        with self.assertRaises(requests.ConnectionError):
            self.controller.poll()
        self.controller.poll()
        self.assertEqual("review", self.store.all()[0].phase)
        self.assertEqual([], self.runtime.cleaned)
        self.assertEqual("REVIEW", self.board.card["column"])

    def test_missing_review_preview_reports_retry_on_card(self):
        self.controller.poll()
        self.complete()
        self.runtime.live = False
        self.executor = Executor()
        self.controller = self.build()
        self.controller.poll()
        self.assertEqual("failed", self.store.all()[0].phase)
        self.assertEqual("review_failed", self.board.commands[-1][0])
        self.assertIn("TODO", self.board.commands[-1][2])

    def test_review_card_edit_keeps_instance(self):
        self.controller.poll()
        self.complete()
        self.board.card["notes"] = "PM added feedback"
        self.board.move("REVIEW")
        self.controller.poll()
        self.assertEqual("review", self.store.all()[0].phase)
        self.assertEqual([], self.runtime.cleaned)

    def test_archived_board_cancels_and_cleans(self):
        self.controller.poll()
        self.board.archived = True
        self.controller.poll()
        self.assertTrue(self.executor.tasks[0][2].is_set())
        self.assertEqual("cancelled", self.store.all()[0].phase)
        self.assertEqual(1, len(self.runtime.cleaned))

    def test_missing_card_cancels_and_cleans(self):
        self.controller.poll()
        self.board.deleted = True
        self.controller.poll()
        self.assertEqual("cancelled", self.store.all()[0].phase)
        self.assertEqual(1, len(self.runtime.cleaned))

    def test_deleted_review_card_retries_cleanup_after_restart(self):
        self.controller.poll()
        self.complete()
        previous = self.store.all()[0]
        self.board.deleted = True
        self.runtime.cleanup_error = True
        self.controller.poll()
        self.assertEqual("cancelled", self.store.all()[0].phase)
        self.assertTrue(self.store.all()[0].cleanup_pending)
        self.runtime.cleanup_error = False
        self.executor = Executor()
        self.controller = self.build()
        self.controller.poll()
        self.assertFalse(self.store.all()[0].cleanup_pending)
        self.assertEqual((previous.container_name, previous.tunnel_name), self.runtime.cleaned[-1])
        self.assertEqual([], self.executor.tasks)
        self.assertEqual(["claim", "review"], [command[0] for command in self.board.commands])

    def test_deleted_running_card_cleans_late_worker_completion(self):
        self.controller.poll()
        future, previous, event = self.executor.tasks[0]
        self.board.deleted = True
        self.controller.poll()
        self.assertTrue(event.is_set())
        future.set_result(copy.deepcopy(RESULT))
        self.controller.poll()
        self.assertEqual("cancelled", self.store.all()[0].phase)
        self.assertFalse(self.store.all()[0].cleanup_pending)
        self.assertEqual(2, self.runtime.cleaned.count((previous.container_name, previous.tunnel_name)))
        self.assertEqual(["claim"], [command[0] for command in self.board.commands])

    def test_deleted_accepted_card_finishes_integration_deploy_and_publication(self):
        self.controller.poll()
        self.complete()
        self.board.move("DONE")
        self.controller.poll()
        self.board.deleted = True
        self.controller.poll()
        self.assertFalse(self.executor.tasks[-1][2].is_set())
        self.executor.tasks[-1][0].set_result({"commit": "c" * 40})
        self.controller.poll()
        self.assertEqual("deploying", self.store.all()[0].phase)
        self.executor.tasks[-1][0].set_result({"commit": "c" * 40})
        self.controller.poll()
        self.assertEqual("publishing", self.store.all()[0].phase)
        self.executor.tasks[-1][0].set_result({"commit": "c" * 40, "pull_request_url": "https://github.com/discourse/discourse/pull/123"})
        self.controller.poll()
        self.assertEqual("done", self.store.all()[0].phase)
        self.assertEqual("c" * 40, self.store.all()[0].published_commit)
        self.assertEqual(["claim", "review"], [command[0] for command in self.board.commands])

    def test_transient_snapshot_error_preserves_instance(self):
        self.controller.poll()
        self.complete()
        self.board.snapshot = Mock(side_effect=requests.ConnectionError("Board unavailable"))
        with self.assertRaises(requests.ConnectionError):
            self.controller.poll()
        self.assertEqual("review", self.store.all()[0].phase)
        self.assertEqual([], self.runtime.cleaned)

    def test_cleanup_failure_blocks_successor_until_retry(self):
        self.controller.poll()
        self.complete()
        self.runtime.cleanup_error = True
        self.board.move("TODO")
        self.controller.poll()
        self.assertEqual(1, len(self.executor.tasks))
        self.assertTrue(self.store.all()[0].cleanup_pending)
        self.runtime.cleanup_error = False
        self.controller.poll()
        self.assertEqual(2, len(self.executor.tasks))
        self.assertFalse(self.store.all()[0].cleanup_pending)

    def test_backlog_does_not_claim_or_launch(self):
        self.board.move("BACKLOG")
        self.controller.poll()
        self.assertEqual([], self.executor.tasks)
        self.assertEqual([], self.store.all())
        self.assertEqual([], self.board.commands)

    def test_legacy_done_run_is_not_integrated_on_restart(self):
        self.controller.poll()
        self.complete()
        run = self.store.all()[0]
        run.integration_version = 0
        self.store.save(run)
        self.board.move("DONE")
        self.executor = Executor()
        self.controller = self.build()
        self.controller.poll()
        self.assertEqual("done", self.store.all()[0].phase)
        self.assertEqual([], self.executor.tasks)

    def test_restart_replays_integration_with_same_identity(self):
        self.controller.poll()
        self.complete()
        self.board.move("DONE")
        self.controller.poll()
        run = self.store.all()[0]
        self.executor = Executor()
        self.controller = self.build()
        self.controller.poll()
        self.assertEqual(run.run_id, self.executor.tasks[-1][1].run_id)
        self.assertEqual("integrating", self.store.all()[0].phase)

    def test_deploy_launches_before_board_snapshot_during_outage(self):
        self.controller.poll()
        self.complete()
        self.board.move("DONE")
        self.controller.poll()
        self.executor.tasks[-1][0].set_result({"commit": "c" * 40})
        self.board.snapshot = Mock(side_effect=requests.ConnectionError("Board restarting"))
        with self.assertRaises(requests.ConnectionError):
            self.controller.poll()
        self.assertEqual("deploying", self.store.all()[0].phase)
        self.assertEqual("c" * 40, self.executor.tasks[-1][1].integrated_commit)

    def test_integration_failure_is_visible_and_never_acknowledges_done(self):
        self.controller.poll()
        self.complete()
        self.board.move("DONE")
        self.controller.poll()
        self.executor.tasks[-1][0].set_exception(RuntimeError("Conflicts remain"))
        self.controller.poll()
        self.assertEqual("integration_failed", self.store.all()[0].phase)
        self.assertEqual("integration_failed", self.board.commands[-1][0])
        self.assertFalse(self.controller.status()["ok"])
        self.assertFalse(any(command[0] == "done" for command in self.board.commands))
        self.assertIn("Conflicts remain", self.board.commands[-1][2])
        self.board.move("TODO")
        self.controller.poll()
        self.assertEqual("running", self.store.all()[-1].phase)

    def test_todo_waits_until_accepted_integration_completes(self):
        self.controller.poll()
        self.complete()
        self.board.move("DONE")
        self.controller.poll()
        self.board.move("TODO")
        self.controller.poll()
        self.assertEqual(2, len(self.executor.tasks))
        self.assertEqual("TODO", self.board.card["column"])


    def test_wrong_owner_done_never_integrates(self):
        self.controller.poll()
        self.complete()
        self.board.move("DONE")
        self.board.card["run"]["run_id"] = "another-run"
        self.controller.poll()
        self.assertNotEqual("integrating", self.store.all()[0].phase)
        self.assertEqual(1, len(self.executor.tasks))

    def test_archived_done_never_integrates(self):
        self.controller.poll()
        self.complete()
        self.board.move("DONE")
        self.board.archived = True
        self.controller.poll()
        self.assertNotEqual("integrating", self.store.all()[0].phase)
        self.assertEqual(1, len(self.executor.tasks))

    def test_deployment_failure_retries_after_restart_without_reintegrating(self):
        self.controller.poll()
        self.complete()
        self.board.move("DONE")
        self.controller.poll()
        self.executor.tasks[-1][0].set_result({"commit": "c" * 40})
        self.controller.poll()
        self.executor.tasks[-1][0].set_exception(RuntimeError("Server not ready"))
        self.controller.poll()
        run = self.store.all()[0]
        self.assertEqual("deploying", run.phase)
        self.assertEqual("c" * 40, run.integrated_commit)
        self.assertGreater(run.retry_after, 0)
        self.assertFalse(self.controller.status()["ok"])
        self.assertIn("retry automatically", self.board.commands[-1][2])
        self.assertFalse(any(command[0] == "done" for command in self.board.commands))
        self.executor = Executor()
        self.controller = self.build()
        with patch("controller.time.time", return_value=run.retry_after + 1):
            self.controller.poll()
        self.assertEqual(1, len(self.executor.tasks))
        self.assertEqual("deploying", self.executor.tasks[0][1].phase)
        self.executor.tasks[0][0].set_result({"commit": "c" * 40})
        self.controller.poll()
        self.assertEqual("publishing", self.store.all()[0].phase)

    def test_publication_failure_retries_after_restart_without_merge_or_deploy(self):
        self.controller.poll()
        self.complete()
        self.board.move("DONE")
        self.controller.poll()
        for _ in range(2):
            self.executor.tasks[-1][0].set_result({"commit": "c" * 40})
            self.controller.poll()
        self.assertEqual("publishing", self.store.all()[0].phase)
        self.executor.tasks[-1][0].set_exception(RuntimeError("GitHub unavailable"))
        self.controller.poll()
        run = self.store.all()[0]
        self.assertEqual("publishing", run.phase)
        self.assertFalse(self.controller.status()["ok"])
        self.assertFalse(any(c[0] == "done" for c in self.board.commands))
        self.executor = Executor()
        self.controller = self.build()
        with patch("controller.time.time", return_value=run.retry_after + 1):
            self.controller.poll()
        self.assertEqual(1, len(self.executor.tasks))
        self.assertEqual("publishing", self.executor.tasks[-1][1].phase)
        self.executor.tasks[-1][0].set_result({"commit": "c" * 40, "pull_request_url": "https://github.com/discourse/discourse/pull/123"})
        self.controller.poll()
        self.assertEqual("done", self.store.all()[0].phase)
        self.assertIn("pull/123", self.board.commands[-1][2])

    def test_accepted_push_waits_for_confirmation_without_failure_report(self):
        self.controller.poll()
        self.complete()
        self.board.move("DONE")
        self.controller.poll()
        for _ in range(2):
            self.executor.tasks[-1][0].set_result({"commit": "c" * 40})
            self.controller.poll()
        before = len(self.board.commands)
        self.executor.tasks[-1][0].set_result({"status": "confirming", "commit": "c" * 40,
                                               "pull_request_url": "https://github.com/discourse/discourse/pull/123",
                                               "diagnostic": {"reason": "metadata_lag"}, "log_path": "/data/publication/run.jsonl"})
        self.controller.poll()
        run = self.store.all()[0]
        self.assertEqual("confirming", run.phase)
        self.assertEqual("", run.error)
        self.assertTrue(self.controller.status()["ok"])
        self.assertEqual("metadata_lag", self.controller.status()["runs"][0]["confirmation_diagnostic"]["reason"])
        self.assertIn("Pushed", self.board.commands[-1][2])
        self.assertFalse(any(command[0] == "integration_failed" for command in self.board.commands[before:]))
        self.executor = Executor()
        self.controller = self.build()
        with patch("controller.time.time", return_value=run.retry_after + 1):
            self.controller.poll()
        self.assertEqual("confirming", self.executor.tasks[-1][1].phase)
        self.executor.tasks[-1][0].set_exception(RuntimeError("Docker unavailable"))
        self.controller.poll()
        retry = self.store.all()[0]
        self.assertEqual("confirming", retry.phase)
        self.assertEqual("", retry.error)
        self.assertFalse(any(command[0] == "integration_failed" for command in self.board.commands[before:]))
        with patch("controller.time.time", return_value=retry.retry_after + 1):
            self.controller.poll()
        self.executor.tasks[-1][0].set_result({"status": "confirmed", "commit": "c" * 40,
                                               "pull_request_url": "https://github.com/discourse/discourse/pull/123"})
        self.controller.poll()
        self.assertEqual("done", self.store.all()[0].phase)


    def saved_completed_run(self, published=True):
        self.controller.poll()
        self.complete()
        self.board.move("DONE")
        run = self.controller.runs[self.executor.tasks[0][1].run_id]
        run.phase = "done"
        run.integrated_commit = "c" * 40
        run.published_commit = run.integrated_commit if published else ""
        run.pull_request_url = "https://github.com/discourse/discourse/pull/123" if published else ""
        run.report_pending = True
        self.controller.save(run)
        self.controller.jobs.clear()
        return run

    def test_confirmed_published_run_moves_to_archive_even_if_previously_reported_done(self):
        run = self.saved_completed_run()
        self.board.card["run"]["status"] = "done"
        self.controller.poll()
        self.assertEqual("ARCHIVED", self.board.card["column"])
        self.assertEqual("archive", self.board.commands[-1][0])
        self.assertFalse(self.store.all()[0].report_pending)
        count = len(self.board.commands)
        self.controller.poll()
        self.assertEqual(count, len(self.board.commands))

    def test_unpublished_legacy_done_is_not_archived(self):
        run = self.saved_completed_run(published=False)
        run.publication_required = False
        self.controller.save(run)
        self.controller.poll()
        self.assertEqual("DONE", self.board.card["column"])
        self.assertEqual("done", self.board.commands[-1][0])

    def test_mismatched_published_commit_does_not_archive(self):
        run = self.saved_completed_run()
        run.published_commit = "d" * 40
        self.controller.save(run)
        self.controller.poll()
        self.assertEqual("DONE", self.board.card["column"])
        self.assertFalse(any(c[0] == "archive" for c in self.board.commands))

    def test_confirming_run_with_accepted_commit_stays_done(self):
        run = self.saved_completed_run()
        run.phase = "confirming"
        run.retry_after = time.time() + 3600
        run.report_pending = False
        self.controller.save(run)
        self.controller.poll()
        self.assertEqual("DONE", self.board.card["column"])
        self.assertFalse(any(c[0] == "archive" for c in self.board.commands))

    def test_archive_response_loss_recovers_after_restart_without_duplicate_report(self):
        run = self.saved_completed_run()
        transition = self.board.transition
        def lose_archive_response(command, generation, message=""):
            card = transition(command, generation, message)
            if command == "archive":
                raise requests.ConnectionError("Response lost after archive committed")
            return card
        self.board.transition = lose_archive_response
        with self.assertRaises(requests.ConnectionError):
            self.controller.poll()
        count = len(self.board.commands)
        self.board.transition = transition
        self.controller = self.build()
        self.controller.poll()
        self.assertEqual("ARCHIVED", self.board.card["column"])
        self.assertEqual(count, len(self.board.commands))
        self.assertFalse(self.store.all()[0].report_pending)

    def test_archive_cleanup_failure_keeps_done_until_cleanup_retry(self):
        run = self.saved_completed_run()
        run.cleanup_pending = True
        self.runtime.cleanup_error = True
        self.controller.save(run)
        self.controller.poll()
        self.assertEqual("DONE", self.board.card["column"])
        self.runtime.cleanup_error = False
        self.controller.poll()
        self.assertEqual("ARCHIVED", self.board.card["column"])

    def test_archive_does_not_clobber_new_generation_or_manual_todo(self):
        run = self.saved_completed_run()
        self.board.card["run"]["run_id"] = "another-generation"
        self.controller.poll()
        self.assertEqual("DONE", self.board.card["column"])
        self.board.move("TODO")
        self.controller.poll()
        self.assertEqual("IN PROGRESS", self.board.card["column"])
        self.assertFalse(any(c[0] == "archive" for c in self.board.commands))

    def test_deleted_completed_card_is_not_archived(self):
        self.saved_completed_run()
        self.board.deleted = True
        self.controller.poll()
        self.assertFalse(any(c[0] == "archive" for c in self.board.commands))

    def test_archived_card_never_launches_coding(self):
        self.board.move("ARCHIVED")
        self.controller.poll()
        self.assertEqual([], self.executor.tasks)



class ResourceTests(unittest.TestCase):
    def test_cleanup_refuses_unowned_container(self):
        runtime = Runtime.__new__(Runtime)
        runtime.config = argparse.Namespace(board_id=1)
        runtime.client = Mock()
        runtime.ngrok = "http://agent"
        runtime.http = Mock()
        runtime.tunnel = Mock(return_value=None)
        unrelated = Mock(labels={"owner": "somebody-else"})
        runtime.client.containers.get.return_value = unrelated
        run = Run.create({"id": 3, "version": "1"}, 1)
        with self.assertRaisesRegex(RuntimeError, "Refusing unrelated container"):
            runtime.cleanup(run)
        unrelated.remove.assert_not_called()
        runtime.client.volumes.remove.assert_not_called()

    def test_cleanup_deleted_resources_is_idempotent(self):
        runtime = Runtime.__new__(Runtime)
        runtime.config = argparse.Namespace(board_id=1)
        runtime.client = Mock()
        runtime.client.containers.get.side_effect = docker.errors.NotFound("gone")
        runtime.tunnel = Mock(return_value=None)
        run = Run.create({"id": 3, "version": "1"}, 1)
        runtime.cleanup(run)
        runtime.cleanup(run)
        runtime.client.volumes.remove.assert_not_called()

    def test_frontend_error_prevents_ready_preview(self):
        event = Mock()
        event.is_set.return_value = False
        event.wait.return_value = False
        with patch("controller.requests.Session") as factory, patch("controller.time.monotonic", side_effect=[0, 0, 2]):
            response = factory.return_value.__enter__.return_value.get.return_value
            response.text = "<html><h1>Frontend build error</h1></html>"
            with self.assertRaisesRegex(RuntimeError, "Preview frontend is unavailable"):
                Runtime.health("https://preview.ngrok.dev", event, timeout=1)

    def test_refreshed_auth_is_saved_outside_preview_with_private_mode(self):
        runtime = Runtime.__new__(Runtime)
        runtime.read = Mock(return_value='{"auth_mode":"chatgpt","tokens":{"access_token":"test-value"}}')
        container = Mock()
        container.exec_run.return_value.exit_code = 0
        with tempfile.TemporaryDirectory() as directory, patch.dict("os.environ", {"DATA_DIR": directory}):
            runtime.capture_auth(container)
            from pathlib import Path
            path = Path(directory) / "codex-auth.json"
            self.assertEqual(0o600, path.stat().st_mode & 0o777)
            self.assertIn('"auth_mode":"chatgpt"', path.read_text())

    def test_incomplete_snapshot_rejected_before_reconciliation(self):
        board = Board("https://example.test/codex-board-bot")
        board.request = Mock(return_value={"cards": [], "archived": False, "board_id": 1})
        with self.assertRaisesRegex(ValueError, "Missing board column"):
            board.snapshot()


if __name__ == "__main__":
    unittest.main()
