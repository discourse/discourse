import json
import os
from pathlib import Path
import threading
import time

import docker
import requests

from auth import configure_board_auth, load_board_credentials


class DockerBoard:
    name = "capybara-board"
    owner = "capybara-control-board"

    def __init__(self, config, client):
        self.config, self.client = config, client
        self.lock = threading.Lock()
        self.host = os.environ.get("BOARD_HOST", "joffrey.ngrok.dev")
        self.port = int(os.environ.get("BOARD_PORT", "3410"))
        self.bootstrap = os.environ.get("BOARD_BOOTSTRAP_HOST_PATH", "")
        self.credentials = load_board_credentials()
        self.ngrok = requests.Session()
        self.ngrok.headers["Host"] = "localhost:4040"
        self.ngrok_api = config.ngrok_api.rstrip("/")
        self.target = Path(os.environ.get("DATA_DIR", "/data")) / "board-target.json"

    def container(self):
        try:
            container = self.client.containers.get(self.name)
        except docker.errors.NotFound:
            return None
        if container.labels.get("owner") != self.owner:
            raise RuntimeError("Refusing unrelated control-board container")
        return container

    def create(self, commit):
        if not self.bootstrap:
            raise RuntimeError("BOARD_BOOTSTRAP_HOST_PATH is required for the Docker board")
        volumes = {self.config.seed: {"bind": "/seed", "mode": "ro"},
                   self.bootstrap: {"bind": "/bootstrap", "mode": "ro"}}
        for suffix, target in (("workspace", "/workspace"), ("postgres", "/shared/postgres_data"),
                               ("redis", "/shared/redis_data"), ("uploads", "/workspace/discourse/public/uploads")):
            name = f"capybara-board-{suffix}"
            try:
                volume = self.client.volumes.get(name)
                if volume.attrs.get("Labels", {}).get("owner") != self.owner:
                    raise RuntimeError(f"Refusing unrelated board volume {name}")
            except docker.errors.NotFound:
                self.client.volumes.create(name, labels={"owner": self.owner})
            volumes[name] = {"bind": target, "mode": "rw"}
        return self.client.containers.create(
            self.config.worker_image, name=self.name, detach=True, init=True,
            entrypoint=["bash", "/opt/bot/board.sh"], restart_policy={"Name": "unless-stopped"},
            labels={"owner": self.owner, "commit": commit}, volumes=volumes,
            mem_limit="6g", nano_cpus=4_000_000_000, pids_limit=2048,
            ports={"3000/tcp": ("127.0.0.1", self.port)},
            environment={"BOARD_COMMIT": commit, "PGUSER": "discourse",
                         "DISCOURSE_DEV_ALLOW_ANON_TO_IMPERSONATE": "1",
                         "DISCOURSE_DEV_ALLOW_HTTPS": "1", "DISCOURSE_SKIP_CSS_WATCHER": "1",
                         "RAILS_DEVELOPMENT_HOSTS": self.host + ",.ngrok.dev",
                         "DISCOURSE_HOSTNAME": "localhost", "UNICORN_PORT": "3000",
                         "UNICORN_BIND_ALL": "true", "UNICORN_WORKERS": "2"})

    def point_tunnel(self):
        response = self.ngrok.get(f"{self.ngrok_api}/api/tunnels", timeout=15)
        response.raise_for_status()
        tunnel = next((x for x in response.json()["tunnels"] if x["public_url"] == f"https://{self.host}"), None)
        address = f"http://127.0.0.1:{self.port}"
        if tunnel and tunnel["config"]["addr"] in (address, address.replace("127.0.0.1", "localhost")):
            if not self.credentials or self.tunnel_auth_matches():
                return
        if tunnel:
            from urllib.parse import quote
            response = self.ngrok.delete(f"{self.ngrok_api}/api/tunnels/{quote(tunnel['name'], safe='')}", timeout=15)
            response.raise_for_status()
        payload = {"name": "command_line", "proto": "http", "addr": address,
                   "hostname": self.host, "schemes": ["https"]}
        if self.credentials:
            payload["basic_auth"] = [self.credentials.ngrok_value()]
        response = self.ngrok.post(f"{self.ngrok_api}/api/tunnels", timeout=30, json=payload)
        response.raise_for_status()

    def tunnel_auth_matches(self):
        url = f"https://{self.host}/session/csrf.json"
        with requests.Session() as session:
            session.trust_env = False
            session.headers["ngrok-skip-browser-warning"] = "1"
            response = session.get(url, timeout=15, allow_redirects=False)
            if response.status_code != 401 or not response.headers.get("WWW-Authenticate", "").lower().startswith("basic "):
                return False
            configure_board_auth(session, url, self.credentials)
            response = session.get(url, timeout=15, allow_redirects=False)
            return response.status_code != 401

    def wait(self, container, event):
        deadline = time.monotonic() + 1800
        while time.monotonic() < deadline:
            if event.wait(2):
                raise RuntimeError("Deployment interrupted; restart will recover it")
            container.reload()
            if container.status != "running":
                raise RuntimeError("Docker board exited; inspect its container logs")
            result = container.exec_run(["cat", "/workspace/board-ready"])
            if result.exit_code == 0 and result.output.decode().strip() == container.labels["commit"]:
                self.point_tunnel()
                try:
                    with requests.Session() as session:
                        configure_board_auth(session, f"https://{self.host}", self.credentials)
                        session.headers["ngrok-skip-browser-warning"] = "1"
                        response = session.get(f"https://{self.host}/session/joffreyjaffeux/become", timeout=30)
                        response.raise_for_status()
                        if "Frontend build error" in response.text or "<script" not in response.text:
                            raise RuntimeError("Docker board frontend is unavailable")
                        response = session.get(f"https://{self.host}/session/current.json", timeout=30)
                        response.raise_for_status()
                        if response.json()["current_user"]["admin"] is not True:
                            raise RuntimeError("Administrator login failed after deployment")
                except (requests.RequestException, ValueError, KeyError):
                    if time.monotonic() + 5 >= deadline:
                        raise
                    if event.wait(5):
                        raise RuntimeError("Deployment interrupted")
                    continue
                return
        raise TimeoutError("Docker board deployment exceeded 30 minutes")

    def deploy(self, commit, event):
        with self.lock:
            self.target.parent.mkdir(parents=True, exist_ok=True)
            temporary = self.target.with_suffix(".tmp")
            temporary.write_text(json.dumps({"commit": commit}))
            temporary.replace(self.target)
            current = self.container()
            if current and current.labels.get("commit") != commit:
                current.remove(force=True)
                current = None
            if current is None:
                current = self.create(commit)
            current.reload()
            if current.status != "running":
                current.start()
            self.wait(current, event)

    def reconcile(self):
        if not self.lock.acquire(blocking=False):
            return
        try:
            current = self.container()
            if current is None and self.target.exists():
                current = self.create(json.loads(self.target.read_text())["commit"])
            if current is not None:
                if not self.target.exists():
                    self.target.parent.mkdir(parents=True, exist_ok=True)
                    temporary = self.target.with_suffix(".tmp")
                    temporary.write_text(json.dumps({"commit": current.labels["commit"]}))
                    temporary.replace(self.target)
                current.reload()
                if current.status != "running":
                    current.start()
                ready = current.exec_run(["cat", "/workspace/board-ready"])
                if ready.exit_code == 0 and ready.output.decode().strip() == current.labels["commit"]:
                    self.point_tunnel()
        finally:
            self.lock.release()
