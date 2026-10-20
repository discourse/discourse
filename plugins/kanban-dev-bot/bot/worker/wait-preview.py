import argparse
import json
import os
from pathlib import Path
import time


def check_static_build(dist=Path("frontend/discourse/dist")):
    if (dist / "manifest/build.json").exists():
        raise RuntimeError("Static preview still has a frontend watcher status file")
    try:
        manifest = json.loads((dist / "manifest/manifest.json").read_text())
    except (OSError, json.JSONDecodeError) as error:
        raise RuntimeError("Static preview has no readable frontend manifest") from error
    if not isinstance(manifest, dict):
        raise RuntimeError("Static preview frontend manifest must be an object")
    for key in ("entrypoints", "dynamicEntrypoints", "chunks", "importMap"):
        if not isinstance(manifest.get(key), dict):
            raise RuntimeError(f"Static preview frontend manifest has invalid {key}")
    if not manifest["entrypoints"].get("discourse"):
        raise RuntimeError("Static preview frontend manifest has no discourse entrypoint")
    files = list(manifest["entrypoints"].values())
    files.extend(manifest["dynamicEntrypoints"].values())
    files.extend(manifest["importMap"].values())
    for name, chunk in manifest["chunks"].items():
        if not isinstance(chunk, dict) or not isinstance(chunk.get("imports"), list):
            raise RuntimeError("Static preview frontend manifest has invalid chunk metadata")
        files.extend([name, chunk.get("file"), *chunk["imports"]])
    for name in files:
        if not isinstance(name, str) or not name:
            raise RuntimeError("Static preview frontend manifest has an invalid output path")
        path = (dist / name).resolve()
        if not path.is_relative_to(dist.resolve()) or not path.is_file():
            raise RuntimeError(f"Static preview frontend output is missing or invalid: {name}")


def wait_for_live_build(status_file=Path("frontend/discourse/dist/manifest/build.json")):
    deadline = time.monotonic() + 300
    while time.monotonic() < deadline:
        try:
            status = json.loads(status_file.read_text())
            os.kill(int(status["pid"]), 0)
            if status["status"] == "error":
                raise RuntimeError("Frontend build failed: " + str(status.get("error")))
            if status["status"] == "ok":
                return
        except (FileNotFoundError, KeyError, ProcessLookupError, json.JSONDecodeError):
            pass
        time.sleep(1)
    raise TimeoutError("Frontend did not produce a successful build with a live builder")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--static", action="store_true")
    args = parser.parse_args()
    if args.static:
        check_static_build()
    else:
        wait_for_live_build()


if __name__ == "__main__":
    main()
