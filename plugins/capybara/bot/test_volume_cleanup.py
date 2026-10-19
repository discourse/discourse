import unittest
from unittest.mock import Mock

import docker

from controller import Run
from volume_cleanup import collect_volumes


class VolumeCleanupTests(unittest.TestCase):
    def setUp(self):
        self.card = {"id": 3, "version": "1", "column": "DONE", "run": {"run_id": "first"}}
        self.run = Run.create(self.card, 1, "first")
        self.run.phase = "done"
        self.client = Mock()
        self.volumes = []
        self.client.volumes.list.side_effect = lambda **kwargs: list(self.volumes)
        self.client.containers.list.return_value = []
        for attr in ("workspace_volume", "codex_volume", "integration_volume"):
            self.add_volume(getattr(self.run, attr), integration=attr == "integration_volume")

    def add_volume(self, name, integration=False):
        labels = {"owner": "codex-board-bot", "board_id": "1", "card_id": "3"}
        if integration:
            labels.update(run_id="first", role="integrator")
        volume = Mock()
        volume.name = name
        volume.attrs = {"Labels": labels}
        volume.remove.side_effect = lambda **kwargs: self.volumes.remove(volume)
        self.volumes.append(volume)
        return volume

    def collect(self, runs=None, cards=None, jobs=(), **kwargs):
        return collect_volumes(self.client, 1, [self.run] if runs is None else runs,
                               {3: self.card} if cards is None else cards, jobs, **kwargs)

    def test_done_removes_all_three_volumes_and_repeat_is_empty(self):
        volumes = list(self.volumes)
        self.assertEqual(3, len(self.collect()["removed"]))
        self.assertEqual([], self.collect()["removed"])
        for volume in volumes:
            volume.remove.assert_called_once_with(force=False)

    def test_each_active_and_integration_phase_retains_accepted_work(self):
        for phase in ("running", "review", "integrating", "deploying", "publishing", "confirming"):
            with self.subTest(phase=phase):
                self.run.phase = phase
                self.assertEqual([], self.collect(cards={})["removed"])
        self.assertEqual(3, len(self.volumes))

    def test_current_integration_failure_in_done_retains_work(self):
        self.run.phase = "integration_failed"
        self.assertEqual([], self.collect()["removed"])
        self.assertEqual(3, len(self.collect(cards={})["removed"]))

    def test_current_coding_failure_retained_until_done(self):
        self.run.phase = "failed"
        self.card["column"] = "IN PROGRESS"
        self.assertEqual([], self.collect()["removed"])
        self.card["column"] = "DONE"
        self.assertEqual(3, len(self.collect()["removed"]))

    def test_superseded_failure_releases_old_workspace_but_shared_session_is_retained(self):
        self.run.phase = "failed"
        next_run = Run.create(self.card, 1, "second")
        next_run.workspace_volume = self.run.workspace_volume
        next_run.phase = "review"
        self.card["run"]["run_id"] = "second"
        result = self.collect(runs=[self.run, next_run])
        self.assertEqual([self.run.integration_volume], result["removed"])
        self.assertEqual({self.run.codex_volume, self.run.workspace_volume}, set(result["retained"]))

    def test_cancelled_future_preserves_volumes_until_job_quiesces(self):
        self.run.phase = "cancelled"
        self.assertEqual([], self.collect(cards={}, jobs={self.run.run_id})["removed"])
        self.assertEqual(3, len(self.collect(cards={})["removed"]))

    def test_pending_container_cleanup_retains_even_terminal_work(self):
        self.run.cleanup_pending = True
        self.assertEqual([], self.collect()["removed"])

    def test_failed_historical_attempt_releases_after_superseded(self):
        self.run.phase = "failed"
        self.card["column"] = "REVIEW"
        self.card["run"]["run_id"] = "new"
        self.assertEqual(3, len(self.collect()["removed"]))

    def test_unknown_future_phase_is_conservatively_retained(self):
        self.run.phase = "new-recovery-phase"
        self.assertEqual([], self.collect()["removed"])

    def test_unknown_main_and_wrong_label_volumes_never_removed(self):
        self.add_volume("unknown-owned-volume")
        self.add_volume("capybara-board-postgres")
        self.add_volume("kanban-bot_controller-state")
        for index, labels in enumerate(({"owner": "main"}, {"board_id": "2"}, {"card_id": "4"})):
            self.volumes[index].attrs["Labels"].update(labels)
        self.assertEqual([], self.collect()["removed"])
        self.assertEqual(6, len(self.volumes))

    def test_conflicting_run_or_role_label_is_not_deleted(self):
        self.volumes[0].attrs["Labels"].update(run_id="unrelated")
        self.volumes[1].attrs["Labels"].update(role="integrator")
        self.volumes[2].attrs["Labels"].update(role="publisher")
        self.assertEqual([], self.collect()["removed"])

    def test_stopped_container_attachment_protects_volume(self):
        container = Mock()
        container.attrs = {"State": {"Status": "exited"}, "Mounts": [{"Type": "volume", "Name": self.run.workspace_volume}]}
        self.client.containers.list.return_value = [container]
        result = self.collect()
        self.assertNotIn(self.run.workspace_volume, result["removed"])
        self.client.containers.list.assert_called_once_with(all=True)

    def test_conflict_then_later_reconciliation_retries(self):
        volume = self.volumes[0]
        volume.remove.side_effect = docker.errors.APIError("still attached", response=Mock(status_code=409))
        result = self.collect()
        self.assertEqual(1, len(result["errors"]))
        self.assertNotIn(volume.name, result["removed"])
        volume.remove.side_effect = lambda **kwargs: self.volumes.remove(volume)
        self.assertEqual([volume.name], self.collect()["removed"])

    def test_inventory_network_failure_does_not_delete_anything(self):
        self.client.containers.list.side_effect = docker.errors.DockerException("offline")
        self.assertEqual(1, len(self.collect()["errors"]))
        self.assertEqual(3, len(self.volumes))

    def test_missing_volume_is_idempotent(self):
        self.volumes[0].remove.side_effect = docker.errors.NotFound("already gone")
        self.assertEqual(3, len(self.collect()["removed"]))

    def test_dry_run_reports_candidates_without_deleting(self):
        self.assertEqual(3, len(self.collect(dry_run=True)["candidates"]))
        self.assertEqual(3, len(self.volumes))


if __name__ == "__main__":
    unittest.main()
