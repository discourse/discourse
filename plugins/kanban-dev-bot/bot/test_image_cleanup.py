import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest
from unittest.mock import Mock

from docker.errors import APIError, ImageNotFound
from image_cleanup import clean, snapshot


def image(number, tags=(), digests=()):
    return Mock(id="sha256:" + f"{number:064x}", attrs={"RepoTags": list(tags), "RepoDigests": list(digests)})


class CleanupTests(unittest.TestCase):
    def setUp(self):
        self.worker = image(1, ["discourse-codex-worker:local"])
        self.controller = image(2, ["discourse-board-controller:local"])
        self.old = image(3, ["discourse-codex-worker:old"])
        self.client = Mock()
        self.client.images.list.return_value = [self.worker, self.controller, self.old]
        self.client.containers.list.return_value = []

    def clean(self, *images):
        return clean(self.client, [item.id for item in images])

    def test_snapshot_only_exact_repositories_and_deduplicates(self):
        foreign = image(4, ["someone/discourse-codex-worker:old"])
        dangling = image(5)
        digest = image(6, digests=["discourse-board-controller@sha256:abc"])
        self.client.images.list.return_value += [foreign, dangling, digest, self.old]
        self.assertEqual(snapshot(self.client), sorted([self.worker.id, self.controller.id, self.old.id, digest.id]))

    def test_unused_local_tags_are_protected_for_future_cards(self):
        result = self.clean(self.worker, self.controller)
        self.assertEqual(set(result["kept"]), {self.worker.id, self.controller.id})
        self.client.images.remove.assert_not_called()

    def test_running_and_stopped_containers_are_protected(self):
        for state in ("running", "exited"):
            with self.subTest(state=state):
                self.client.containers.list.return_value = [Mock(attrs={"Image": self.old.id, "State": {"Status": state}})]
                self.assertEqual(self.clean(self.old)["kept"], [self.old.id])
                self.client.containers.list.assert_called_with(all=True)
        self.client.images.remove.assert_not_called()

    def test_foreign_tag_or_digest_protects_mixed_image(self):
        for field, value in (("RepoTags", "other:keep"), ("RepoDigests", "registry.example/team/image@sha256:abc")):
            with self.subTest(field=field):
                self.old.attrs[field] = [value]
                self.assertEqual(self.clean(self.old)["kept"], [self.old.id])
                self.old.attrs[field] = []
        self.client.images.remove.assert_not_called()

    def test_only_snapshot_ids_removed_nonforced_without_parent_pruning(self):
        self.assertEqual(self.clean(self.old)["removed"], [self.old.id])
        self.client.images.remove.assert_called_once_with(self.old.id, force=False, noprune=True)

    def test_repeat_after_removal_is_successful(self):
        self.clean(self.old)
        self.client.images.list.return_value.remove(self.old)
        self.assertEqual(self.clean(self.old)["missing"], [self.old.id])
        self.client.images.remove.assert_called_once()

    def test_disappearance_during_remove_is_successful(self):
        self.client.images.remove.side_effect = ImageNotFound("gone")
        self.assertEqual(self.clean(self.old)["missing"], [self.old.id])

    def test_conflict_is_warning_without_force_retry(self):
        self.client.images.remove.side_effect = APIError("multiple tags", response=Mock(status_code=409))
        self.assertEqual(len(self.clean(self.old)["warnings"]), 1)
        self.client.images.remove.assert_called_once_with(self.old.id, force=False, noprune=True)

    def test_missing_required_tag_fails_closed(self):
        self.controller.attrs["RepoTags"] = []
        self.assertIn("Required image tags missing", self.clean(self.old)["warnings"][0])
        self.client.images.remove.assert_not_called()

    def test_inventory_error_stops_all_deletion(self):
        self.client.containers.list.side_effect = RuntimeError("daemon unavailable")
        self.assertIn("inventory unavailable", self.clean(self.old)["warnings"][0])
        self.client.images.remove.assert_not_called()

    def test_reinventories_before_every_delete(self):
        second = image(4)
        self.client.images.list.return_value.append(second)
        self.client.containers.list.side_effect = [[], [Mock(attrs={"Image": second.id})]]
        result = self.clean(self.old, second)
        self.assertEqual(result["removed"], [self.old.id])
        self.assertEqual(result["kept"], [second.id])
        self.assertEqual(self.client.images.list.call_count, 2)

    def test_malformed_snapshot_rejected_before_inventory(self):
        for values in ({}, ["latest"], [None]):
            with self.subTest(values=values), self.assertRaises(ValueError):
                clean(self.client, values)
        self.client.images.list.assert_not_called()


class BuildLifecycleTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.bot = self.root / "bot"
        self.bot.mkdir()
        shutil.copy(Path(__file__).with_name("manage.sh"), self.bot / "manage.sh")
        self.log = self.root / "events"
        docker = self.root / "docker"
        docker.write_text("""#!/bin/bash
shift 2
if [[ "$1" == image ]]; then
  [[ "${FAIL_STAGE:-}" != bootstrap ]]
elif [[ "$1" == run && "$*" == *image_cleanup.py* ]]; then
  if [[ "$*" == *' snapshot '* ]]; then stage=snapshot; else stage=clean; fi
  echo "$stage" >> "$EVENTS"
  [[ "${FAIL_STAGE:-}" != "$stage" ]]
elif [[ "$1" == run ]]; then
  echo context >> "$EVENTS"
  [[ "${FAIL_STAGE:-}" != context ]]
elif [[ "$1" == build ]]; then
  echo worker >> "$EVENTS"
  [[ "${FAIL_STAGE:-}" != worker ]]
elif [[ "$1" == compose ]]; then
  echo controller >> "$EVENTS"
  [[ "${FAIL_STAGE:-}" != controller ]]
else exit 99
fi
""")
        docker.chmod(0o755)
        lock = self.root / "shlock"
        lock.write_text("""#!/bin/bash
if [[ "${FAIL_STAGE:-}" == lock ]]; then exit 1; fi
while [[ $# -gt 0 ]]; do
  if [[ "$1" == -f ]]; then shift; touch "$1"; fi
  shift
done
""")
        lock.chmod(0o755)
        self.env = {**os.environ, "PATH": f"{self.root}:{os.environ['PATH']}", "EVENTS": str(self.log)}

    def tearDown(self):
        self.temp.cleanup()

    def run_build(self, failure=""):
        result = subprocess.run(["bash", str(self.bot / "manage.sh"), "build"], env={**self.env, "FAIL_STAGE": failure}, capture_output=True, text=True)
        events = self.log.read_text().splitlines() if self.log.exists() else []
        self.assertFalse((self.bot / ".build/build.lock").exists())
        return result, events

    def test_success_cleans_only_after_both_builds(self):
        result, events = self.run_build()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(events, ["snapshot", "context", "worker", "controller", "clean"])

    def test_build_failures_never_clean_and_release_lock(self):
        for failure in ("context", "worker", "controller"):
            with self.subTest(failure=failure):
                self.log.unlink(missing_ok=True)
                result, events = self.run_build(failure)
                self.assertNotEqual(result.returncode, 0)
                self.assertNotIn("clean", events)

    def test_cleanup_warning_does_not_fail_build(self):
        result, events = self.run_build("clean")
        self.assertEqual(result.returncode, 0)
        self.assertIn("Warning: bot build succeeded", result.stderr)
        self.assertEqual(events[-1], "clean")

    def test_snapshot_failure_builds_but_skips_cleanup(self):
        result, events = self.run_build("snapshot")
        self.assertEqual(result.returncode, 0)
        self.assertEqual(events, ["snapshot", "context", "worker", "controller"])
        self.assertIn("snapshot failed", result.stderr)

    def test_first_build_does_not_require_existing_controller(self):
        result, events = self.run_build("bootstrap")
        self.assertEqual(result.returncode, 0)
        self.assertEqual(events, ["context", "worker", "controller"])
        self.assertIn("first build", result.stderr)

    def test_concurrent_build_rejected_before_docker(self):
        result, events = self.run_build("lock")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(events, [])


if __name__ == "__main__":
    unittest.main()
