import json
import os
from pathlib import Path
import time

status_file = Path("frontend/discourse/dist/manifest/build.json")
deadline = time.monotonic() + 300
while time.monotonic() < deadline:
    try:
        status = json.loads(status_file.read_text())
        os.kill(int(status["pid"]), 0)
        if status["status"] == "error":
            raise RuntimeError("Frontend build failed: " + str(status.get("error")))
        if status["status"] == "ok":
            break
    except (FileNotFoundError, KeyError, ProcessLookupError, json.JSONDecodeError):
        pass
    time.sleep(1)
else:
    raise TimeoutError("Frontend did not produce a successful build with a live builder")
