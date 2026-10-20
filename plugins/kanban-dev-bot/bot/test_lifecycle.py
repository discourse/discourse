import copy
import unittest
from unittest.mock import Mock

import requests

from controller import Run, Runtime
import test_controller as support
from test_controller import RESULT
from volume_cleanup import volume_plan


class LifecycleTests(unittest.TestCase):
    setUp = support.ControllerTests.setUp
    tearDown = support.ControllerTests.tearDown
    build = support.ControllerTests.build
    complete = support.ControllerTests.complete
    saved_completed_run = support.ControllerTests.saved_completed_run

    def action(self, action, identity="action-1"):
        self.board.card["run"].update(requested_action=action, action_id=identity)

    def test_restart_waits_for_late_create_and_final_cleanup(self):
        self.controller.poll()
        future, run, event = self.executor.tasks[0]
        resources = set()
        self.runtime.cleanup = lambda current: resources.discard(current.run_id)
        self.action("restart")
        self.controller.poll()
        self.assertTrue(event.is_set())
        self.assertEqual("stopping", self.store.all()[0].phase)
        self.assertEqual("IN PROGRESS", self.board.card["column"])
        resources.add(run.run_id)
        self.controller.poll()
        self.assertEqual({run.run_id}, resources)
        self.assertEqual(1, len(self.executor.tasks))
        future.set_result(copy.deepcopy(RESULT))
        self.controller.poll()
        self.assertEqual(set(), resources)
        self.assertEqual("TODO", self.board.card["column"])
        self.assertFalse(any(command[0] == "review" for command in self.board.commands))
        self.board.card["discussion"] = [{"raw": "Latest reply"}]
        self.controller.poll()
        self.assertEqual(2, len(self.executor.tasks))
        self.assertNotEqual(run.run_id, self.executor.tasks[-1][1].run_id)
        self.assertEqual([{"raw": "Latest reply"}], self.executor.tasks[-1][1].card["discussion"])

    def test_stop_ack_waits_for_cleanup_and_recovers_lost_response(self):
        self.controller.poll()
        self.complete()
        self.action("cancel")
        transition = self.board.transition
        acknowledgements = []
        def lost_ack(command, run, message=""):
            if command == "stopped":
                acknowledgements.append(run.action_id)
                if len(acknowledgements) == 1:
                    transition(command, run, message)
                    raise requests.ConnectionError("Acknowledged but response lost")
                return copy.deepcopy(self.board.card)
            return transition(command, run, message)
        self.board.transition = lost_ack
        self.runtime.cleanup_error = True
        self.controller.poll()
        self.assertEqual([], acknowledgements)
        self.runtime.cleanup_error = False
        with self.assertRaises(requests.ConnectionError):
            self.controller.poll()
        self.assertEqual("stopping", self.store.all()[0].phase)
        self.controller = self.build()
        self.controller.poll()
        self.assertEqual("cancelled", self.store.all()[0].phase)
        self.assertEqual(["action-1", "action-1"], acknowledgements)
        self.assertEqual("BACKLOG", self.board.card["column"])

    def test_deleted_intent_without_local_record_cleans_and_acknowledges(self):
        self.board.deleted = True
        operation = {"run_id": "missing", "requested_action": "cancel", "action_id": "delete-1", "version": "1"}
        snapshot = self.board.snapshot()
        snapshot["operations"] = [{"card_id": 3, "run": operation}]
        self.board.snapshot = lambda: snapshot
        self.board.transition = Mock(return_value={"deleted": True})
        self.controller.poll()
        run = self.store.all()[0]
        self.assertEqual("cancelled", run.phase)
        self.assertEqual("missing", run.run_id)
        self.assertEqual("stopped", self.board.transition.call_args.args[0])
        self.assertTrue(self.runtime.cleaned)
        self.assertEqual([], self.executor.tasks)

    def test_deleted_legacy_operations_do_not_create_recovery_records(self):
        self.board.deleted = True
        snapshot = self.board.snapshot()
        snapshot["operations"] = [
            {"card_id": index, "run": {"run_id": status, "status": status}}
            for index, status in enumerate(["running", "review", "failed", "done"], start=10)
        ]
        self.board.snapshot = lambda: snapshot
        self.board.transition = Mock()
        self.controller.poll()
        self.controller.poll()
        self.assertEqual([], self.store.all())
        self.assertEqual([], self.executor.tasks)
        self.assertEqual([], self.runtime.cleaned)
        self.board.transition.assert_not_called()
        self.assertTrue(self.controller.status()["ok"])

    def test_deleted_legacy_recovery_record_retires_after_cleanup(self):
        run = Run.create(self.board.card, 1, "legacy")
        run.phase = "needs_attention"
        run.claim_pending = False
        self.controller.save(run)
        self.board.deleted = True
        snapshot = self.board.snapshot()
        snapshot["operations"] = [{"card_id": run.card_id, "run": {"run_id": run.run_id, "status": "review"}}]
        self.board.snapshot = lambda: snapshot
        self.board.transition = Mock()
        self.runtime.cleanup_error = True
        self.controller.poll()
        self.assertEqual("stopping", self.store.all()[0].phase)
        self.runtime.cleanup_error = False
        self.controller = self.build()
        self.controller.poll()
        self.assertEqual("cancelled", self.store.all()[0].phase)
        self.assertTrue(self.controller.status()["ok"])
        self.assertTrue(self.runtime.cleaned)
        self.board.transition.assert_not_called()
        self.assertEqual([], self.executor.tasks)

    def test_deleted_legacy_snapshot_preserves_local_acceptance(self):
        self.board.deleted = True
        for field in ["accepted_at", "accepted_commit"]:
            with self.subTest(field=field):
                run = Run.create(self.board.card, 1, field)
                run.phase = "needs_attention"
                run.claim_pending = False
                setattr(run, field, "now" if field == "accepted_at" else RESULT["commit"])
                self.controller.save(run)
                snapshot = self.board.snapshot()
                snapshot["operations"] = [{"card_id": run.card_id, "run": {"run_id": run.run_id, "status": "review"}}]
                self.board.snapshot = lambda: snapshot
                self.board.transition = Mock()
                self.controller.poll()
                self.assertEqual("needs_attention", self.controller.runs[field].phase)
                self.board.transition.assert_not_called()
        self.assertEqual([], self.runtime.cleaned)
        self.assertEqual([], self.executor.tasks)

    def test_deleted_done_operation_does_not_report_phase(self):
        run = self.saved_completed_run()
        run.phase = "done"
        self.controller.save(run)
        self.board.deleted = True
        snapshot = self.board.snapshot()
        snapshot["operations"] = [{"card_id": run.card_id, "run": {"run_id": run.run_id, "status": "done"}}]
        self.board.snapshot = lambda: snapshot
        self.board.transition = Mock()
        self.controller.poll()
        self.assertEqual("done", self.store.all()[0].phase)
        self.board.transition.assert_not_called()

    def test_deleted_accepted_operations_preserve_recovery_without_reporting_phase(self):
        run = self.saved_completed_run()
        run.phase = "integration_failed"
        run.accepted_at = "now"
        run.accepted_commit = RESULT["commit"]
        self.controller.save(run)
        self.executor.tasks.clear()
        self.runtime.cleaned.clear()
        self.board.deleted = True
        snapshot = self.board.snapshot()
        snapshot["operations"] = [
            {"card_id": card_id, "run": {"run_id": identity, "status": "done",
             "accepted_at": "now", "accepted_commit": RESULT["commit"]}}
            for card_id, identity in [(run.card_id, run.run_id), (4, "lost")]
        ]
        self.board.snapshot = lambda: snapshot
        self.board.transition = Mock()
        self.controller.poll()
        self.controller = self.build()
        self.controller.poll()
        recovered = {item.run_id: item for item in self.store.all()}
        self.assertEqual("integration_failed", recovered[run.run_id].phase)
        self.assertEqual(run.workspace_volume, recovered[run.run_id].workspace_volume)
        self.assertEqual("needs_attention", recovered["lost"].phase)
        self.assertEqual(RESULT["commit"], recovered["lost"].accepted_commit)
        self.assertEqual([], self.executor.tasks)
        self.assertEqual([], self.runtime.cleaned)
        self.board.transition.assert_not_called()
        self.assertTrue(all(ref.retained for refs in volume_plan(list(recovered.values()), {}, set()).values() for ref in refs))

    def test_deleted_cleanup_intents_recover_lost_acknowledgements(self):
        self.board.deleted = True
        for action in ["cancel", "restart"]:
            with self.subTest(action=action):
                operation = {"run_id": action, "requested_action": action,
                             "action_id": action + "-1", "version": "1"}
                snapshot = self.board.snapshot()
                snapshot["operations"] = [{"card_id": 3, "run": operation}]
                self.board.snapshot = lambda: snapshot
                def lost_ack(command, run, message=""):
                    self.assertEqual("stopped", command)
                    operation.update(requested_action=None, status="cancelled")
                    raise requests.ConnectionError("Acknowledged but response lost")
                self.board.transition = Mock(side_effect=lost_ack)
                with self.assertRaisesRegex(requests.ConnectionError, "Acknowledged but response lost"):
                    self.controller.poll()
                self.assertEqual("stopping", self.controller.runs[action].phase)
                self.controller = self.build()
                self.board.transition = Mock(return_value={"deleted": True})
                self.controller.poll()
                self.assertEqual("cancelled", self.controller.runs[action].phase)
                self.assertEqual("stopped", self.board.transition.call_args.args[0])
                self.assertEqual(action + "-1", self.board.transition.call_args.args[1].action_id)
        self.assertTrue(self.runtime.cleaned)
        self.assertEqual([], self.executor.tasks)

    def test_acceptance_survives_crash_before_controller_observes_it(self):
        self.controller.poll()
        self.complete()
        self.board.move("DONE")
        self.controller = self.build()
        self.controller.poll()
        run = self.store.all()[0]
        self.assertEqual("integrating", run.phase)
        self.assertEqual(RESULT["commit"], run.accepted_commit)
        self.assertEqual(RESULT["commit"], self.executor.tasks[-1][1].commit)

    def test_acceptance_after_lost_review_response_does_not_consume_coding_result_as_merge(self):
        self.controller.poll()
        self.board.fail_after_review = True
        self.executor.tasks[0][0].set_result(copy.deepcopy(RESULT))
        with self.assertRaises(requests.ConnectionError):
            self.controller.poll()
        self.board.move("DONE")
        self.controller.poll()
        run = self.store.all()[0]
        self.assertEqual("integrating", run.phase)
        self.assertEqual("", run.integrated_commit)
        self.assertEqual(2, len(self.executor.tasks))
        self.assertEqual("integrating", self.executor.tasks[-1][1].phase)

    def test_review_backfill_preserves_card_and_discussion(self):
        self.controller.poll()
        self.complete()
        del self.board.card["run"]["commit"]
        version = self.board.card["version"]
        self.controller.poll()
        self.assertEqual(version, self.board.card["version"])
        self.assertEqual(RESULT["commit"], self.board.card["run"]["commit"])
        self.assertEqual("sync_review", self.board.commands[-1][0])
        self.assertEqual("", self.board.commands[-1][2])

    def test_missing_accepted_local_record_needs_attention_without_coding(self):
        self.board.card.update(column="DONE", run={"run_id": "lost", "accepted_at": "now", "accepted_commit": "a" * 40})
        self.controller.poll()
        self.assertEqual("needs_attention", self.store.all()[0].phase)
        self.assertEqual([], self.executor.tasks)
        self.assertFalse(self.controller.status()["ok"])

    def test_retry_reuses_failed_acceptance_identity(self):
        self.controller.poll()
        self.complete()
        self.board.move("DONE")
        self.controller.poll()
        original = self.executor.tasks[-1][1]
        self.executor.tasks[-1][0].set_exception(RuntimeError("conflict"))
        self.controller.poll()
        self.action("retry")
        self.controller.poll()
        retried = self.executor.tasks[-1][1]
        self.assertEqual(original.run_id, retried.run_id)
        self.assertEqual(original.integration_volume, retried.integration_volume)
        self.assertEqual("integrating", retried.phase)
        self.assertEqual(1, len(self.store.all()))
        count = len(self.executor.tasks)
        self.controller.poll()
        self.assertEqual(count, len(self.executor.tasks))

    def test_reconcile_failure_does_not_block_pending_publish(self):
        run = self.saved_completed_run()
        run.phase = "publishing"
        self.controller.save(run)
        self.runtime.reconcile = Mock(side_effect=RuntimeError("main unavailable"))
        self.controller.poll()
        self.assertEqual("publishing", self.executor.tasks[-1][1].phase)

    def test_accepted_failed_volume_survives_missing_card(self):
        self.controller.poll()
        run = self.store.all()[0]
        run.phase = "integration_failed"
        run.accepted_commit = "a" * 40
        self.assertTrue(all(ref.retained for refs in volume_plan([run], {}, set()).values() for ref in refs))


class RetiredResourceTests(unittest.TestCase):
    def test_late_arrival_after_crash_is_removed_on_next_inventory(self):
        runtime = Runtime.__new__(Runtime)
        runtime.config = Mock(board_id=1)
        runtime.client = Mock()
        runtime.http = Mock()
        runtime.ngrok = "http://ngrok"
        run = Run.create({"id": 3, "version": "1"}, 1, "old")
        run.phase = "cancelled"
        container = Mock()
        container.name = run.container_name
        container.labels = {"owner": "codex-board-bot", "board_id": "1", "card_id": "3", "run_id": "old"}
        unrelated = Mock(name="other")
        unrelated.name = "another-container"
        runtime.client.containers.list.side_effect = [[], [container, unrelated], []]
        runtime.tunnels = Mock(side_effect=[[], [{"name": run.tunnel_name}, {"name": "other"}], []])
        runtime.reap_stopped([run])
        runtime.reap_stopped([run])
        runtime.reap_stopped([run])
        container.remove.assert_called_once_with(force=True)
        unrelated.remove.assert_not_called()
        runtime.http.delete.assert_called_once_with("http://ngrok/api/tunnels/" + run.tunnel_name, timeout=15)
