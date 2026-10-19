import json
import os
from pathlib import Path

import docker

from worker.publish import validate_target, sanitize, diagnostic


class ForkPublisher:
    def __init__(self, config, client, runtime):
        self.config, self.client, self.runtime = config, client, runtime
        self.target_path = Path(os.environ.get("PUBLISHER_TARGET", "/run/publisher-target.json"))
        self.token_path = Path(os.environ.get("GITHUB_FORK_TOKEN", "/run/secrets/github-fork-token"))
        self.journal_path = Path(os.environ.get("DATA_DIR", "/data")) / "fork-publication.json"

    def save(self, state):
        temporary = self.journal_path.with_suffix(".tmp")
        with temporary.open("w") as output:
            output.write(json.dumps(state))
            output.flush()
            os.fsync(output.fileno())
        temporary.chmod(0o600)
        temporary.replace(self.journal_path)

    def push(self, run, event):
        try:
            return self._push(run, event)
        except Exception as error:
            state = json.loads(self.journal_path.read_text()) if self.journal_path.exists() else {}
            if state.get("accepted") != run.integrated_commit and run.phase != "confirming":
                raise
            detail = diagnostic("publisher_runtime", exception=type(error).__name__, message=error)
            try:
                token = self.token_path.read_text().strip()
            except OSError:
                token = ""
            if token:
                detail = {key: value.replace(token, "[REDACTED]") for key, value in detail.items()}
            log_path = self.journal_path.parent / "publication" / (run.run_id + ".jsonl")
            log_path.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
            with log_path.open("a") as output:
                output.write(json.dumps({"status": "confirming", "diagnostic": detail}) + "\n")
                output.flush()
                os.fsync(output.fileno())
            log_path.chmod(0o600)
            target = state["target"]
            return {"status": "confirming", "commit": run.integrated_commit,
                    "pull_request_url": f"https://github.com/{target['base_repository']}/pull/{target['pull_request']}",
                    "diagnostic": detail, "log_path": str(log_path)}

    def _push(self, run, event):
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
        expected_url = f"https://github.com/{target['base_repository']}/pull/{target['pull_request']}"
        labels = {"owner": "codex-board-bot", "board_id": str(self.config.board_id),
                  "card_id": str(run.card_id), "run_id": run.run_id, "role": "publisher"}
        log_path = self.journal_path.parent / "publication" / (run.run_id + ".jsonl")
        log_path.parent.mkdir(mode=0o700, parents=True, exist_ok=True)

        def capture(container):
            try:
                receipt = json.loads(self.runtime.read(container, "/publish/accepted.json"))
            except Exception:
                receipt = {}
            if isinstance(receipt, dict) and receipt.get("commit") == run.integrated_commit and receipt.get("pull_request_url") == expected_url:
                state["accepted"] = run.integrated_commit
                self.save(state)
            try:
                result = json.loads(self.runtime.read(container, "/publish/result.json"))
            except Exception:
                result = {}
            result = result if isinstance(result, dict) else {}
            try:
                output = self.runtime.read(container, "/publish/process.log")[-12000:]
            except Exception:
                output = ""
            if output:
                if not result:
                    result["status"] = "unknown"
                result.setdefault("diagnostic", {})["process_output"] = output
            return result

        def record(result):
            token = self.token_path.read_text().strip()

            def safe(value):
                if isinstance(value, dict):
                    return {key: safe(item) for key, item in value.items()}
                return sanitize(str(value).replace(token, "[REDACTED]")) if token else sanitize(value)

            attempt = len(log_path.read_text().splitlines()) + 1 if log_path.exists() else 1
            entry = {**diagnostic("publication_attempt"), "attempt": attempt,
                     "commit": run.integrated_commit, "expected_sha": state["head"],
                     "status": result.get("status", "unknown"), "diagnostic": safe(result.get("diagnostic", {}))}
            with log_path.open("a") as log:
                log.write(json.dumps(entry) + "\n")
                log.flush()
                os.fsync(log.fileno())
            log_path.chmod(0o600)
            result["diagnostic"] = entry["diagnostic"]
            result["log_path"] = str(log_path)
            return result

        name = run.container_name + "-publisher"
        try:
            previous = self.client.containers.get(name)
        except docker.errors.NotFound:
            previous = None
        if previous:
            if any(previous.labels.get(key) != value for key, value in labels.items()):
                raise RuntimeError("Refusing unrelated publisher container")
            recovered = capture(previous)
            if recovered:
                record(recovered)
            previous.remove(force=True)
        container = self.client.containers.create(
            self.config.worker_image, name=name, labels=labels, detach=True, init=True,
            entrypoint=["bash", "-lc"], command=["sleep infinity"], user="0:0",
            mem_limit="2g", nano_cpus=1_000_000_000, pids_limit=128,
            volumes={self.config.seed: {"bind": "/seed", "mode": "ro"}})
        confirmed = False
        try:
            container.start()
            self.runtime.put(container, "/run/github-token", self.token_path.read_bytes())
            self.runtime.put(container, "/run/publisher-target.json", json.dumps(target).encode())
            args = ["python3", "/opt/bot/publish.py", "--commit", run.integrated_commit,
                    "--expected", state["head"]]
            confirming = state.get("accepted") == run.integrated_commit or run.phase == "confirming"
            if confirming:
                args.append("--confirm-only")
            failure = None
            try:
                self.runtime.exec(container, ["bash", "-lc",
                                              'mkdir -p /publish; "$@" > /publish/process.log 2>&1',
                                              "publisher", *args], event, 300)
            except Exception as error:
                failure = error
            result = capture(container)
            if not result:
                result = {"status": "confirming" if state.get("accepted") == run.integrated_commit else "unknown",
                          "diagnostic": diagnostic("publisher_execution", exception=type(failure).__name__, message=failure)}
            record(result)
            if result.get("status") in {"failed", "unknown"}:
                if state.get("accepted") == run.integrated_commit or confirming:
                    result.update(status="confirming", commit=run.integrated_commit,
                                  pull_request_url=f"https://github.com/{target['base_repository']}/pull/{target['pull_request']}")
                else:
                    raise RuntimeError("Publication not confirmed; retrying. " + sanitize(result.get("diagnostic")))
            if result.get("status") == "confirming":
                result.update(commit=run.integrated_commit,
                              pull_request_url=f"https://github.com/{target['base_repository']}/pull/{target['pull_request']}")
                state["accepted"] = run.integrated_commit
                self.save(state)
                return result
            expected_url = f"https://github.com/{target['base_repository']}/pull/{target['pull_request']}"
            if (result.get("status") != "confirmed" or result.get("commit") != run.integrated_commit
                    or result.get("pull_request_url") != expected_url):
                raise RuntimeError("Publisher returned an unexpected PR or commit")
            confirmed = True
            return result
        finally:
            try:
                container.exec_run(["rm", "-f", "/run/github-token"])
            finally:
                container.remove(force=True)
            if confirmed:
                state.update(head=run.integrated_commit, pending="", accepted="")
                self.save(state)
