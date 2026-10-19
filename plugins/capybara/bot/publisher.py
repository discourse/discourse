import json
import os
from pathlib import Path

import docker

from worker.publish import validate_target


class ForkPublisher:
    def __init__(self, config, client, runtime):
        self.config, self.client, self.runtime = config, client, runtime
        self.target_path = Path(os.environ.get("PUBLISHER_TARGET", "/run/publisher-target.json"))
        self.token_path = Path(os.environ.get("GITHUB_FORK_TOKEN", "/run/secrets/github-fork-token"))
        self.journal_path = Path(os.environ.get("DATA_DIR", "/data")) / "fork-publication.json"

    def save(self, state):
        temporary = self.journal_path.with_suffix(".tmp")
        temporary.write_text(json.dumps(state))
        temporary.chmod(0o600)
        temporary.replace(self.journal_path)

    def push(self, run, event):
        target = validate_target(json.loads(self.target_path.read_text()))
        if not self.journal_path.exists():
            raise RuntimeError("Fork publication has not been bootstrapped")
        state = json.loads(self.journal_path.read_text())
        if state.get("target") != target:
            raise RuntimeError("Fork publication journal belongs to another target")
        pending = state.get("pending", "")
        if pending and pending != run.integrated_commit:
            raise RuntimeError("A different commit is awaiting publication recovery")
        state["pending"] = run.integrated_commit
        self.save(state)
        labels = {"owner": "codex-board-bot", "board_id": str(self.config.board_id),
                  "card_id": str(run.card_id), "run_id": run.run_id, "role": "publisher"}
        name = run.container_name + "-publisher"
        try:
            previous = self.client.containers.get(name)
        except docker.errors.NotFound:
            previous = None
        if previous:
            if any(previous.labels.get(key) != value for key, value in labels.items()):
                raise RuntimeError("Refusing unrelated publisher container")
            previous.remove(force=True)
        container = self.client.containers.create(
            self.config.worker_image, name=name, labels=labels, detach=True, init=True,
            entrypoint=["bash", "-lc"], command=["sleep infinity"], user="0:0",
            mem_limit="2g", nano_cpus=1_000_000_000, pids_limit=128,
            volumes={self.config.seed: {"bind": "/seed", "mode": "ro"}})
        try:
            container.start()
            self.runtime.put(container, "/run/github-token", self.token_path.read_bytes())
            self.runtime.put(container, "/run/publisher-target.json", json.dumps(target).encode())
            self.runtime.exec(container, ["python3", "/opt/bot/publish.py", "--commit", run.integrated_commit,
                                          "--expected", state["head"]], event, 300)
            result = json.loads(self.runtime.read(container, "/publish/result.json"))
            expected_url = f"https://github.com/{target['base_repository']}/pull/{target['pull_request']}"
            if result.get("commit") != run.integrated_commit or result.get("pull_request_url") != expected_url:
                raise RuntimeError("Publisher returned an unexpected PR or commit")
            state.update(head=run.integrated_commit, pending="")
            self.save(state)
            return result
        finally:
            try:
                container.exec_run(["rm", "-f", "/run/github-token"])
            finally:
                container.remove(force=True)
