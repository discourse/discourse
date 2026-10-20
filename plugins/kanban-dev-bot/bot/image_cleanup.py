"""Reclaim only immutable bot image IDs captured before a managed rebuild."""
import argparse
import json
import re
import sys
from pathlib import Path

import docker
from docker.errors import APIError, ImageNotFound

REPOSITORIES = frozenset({"discourse-codex-worker", "discourse-board-controller"})
REQUIRED_TAGS = frozenset(f"{repo}:local" for repo in REPOSITORIES)
IMAGE_ID = re.compile(r"sha256:[0-9a-f]{64}\Z")


def repository(reference):
    name = reference.split("@", 1)[0]
    return name.rsplit(":", 1)[0] if ":" in name.rsplit("/", 1)[-1] else name


def references(image):
    return (image.attrs.get("RepoTags") or []) + (image.attrs.get("RepoDigests") or [])


def snapshot(client):
    return sorted({image.id for image in client.images.list(all=True)
                   if any(repository(ref) in REPOSITORIES for ref in references(image))})


def clean(client, candidates):
    if not isinstance(candidates, list) or any(not isinstance(value, str) or not IMAGE_ID.fullmatch(value) for value in candidates):
        raise ValueError("Snapshot must contain full immutable image IDs")
    report = {"removed": [], "kept": [], "missing": [], "warnings": []}
    for image_id in sorted(set(candidates)):
        try:
            images = client.images.list(all=True)
            containers = client.containers.list(all=True)
            tags = {tag: image.id for image in images for tag in image.attrs.get("RepoTags") or []}
            missing = REQUIRED_TAGS - tags.keys()
            if missing:
                raise ValueError("Required image tags missing: " + ", ".join(sorted(missing)))
            protected = {tags[tag] for tag in REQUIRED_TAGS} | {container.attrs["Image"] for container in containers}
            image = next((image for image in images if image.id == image_id), None)
            if image is None:
                report["missing"].append(image_id)
            elif image_id in protected or any(repository(ref) not in REPOSITORIES for ref in references(image)):
                report["kept"].append(image_id)
            else:
                try:
                    client.images.remove(image_id, force=False, noprune=True)
                    report["removed"].append(image_id)
                except ImageNotFound:
                    report["missing"].append(image_id)
                except APIError as error:
                    report["warnings"].append(f"{image_id}: Docker refused removal: {error}")
        except Exception as error:
            report["warnings"].append(f"{image_id}: inventory unavailable; cleanup stopped: {error}")
            break
    return report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=("snapshot", "clean"))
    parser.add_argument("snapshot_file", type=Path)
    args = parser.parse_args()
    client = docker.from_env()
    if args.action == "snapshot":
        data = snapshot(client)
        temporary = args.snapshot_file.with_suffix(".tmp")
        temporary.write_text(json.dumps(data) + "\n")
        temporary.replace(args.snapshot_file)
    else:
        report = clean(client, json.loads(args.snapshot_file.read_text()))
        print(json.dumps(report, sort_keys=True))
        return bool(report["warnings"])
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception as error:
        print(f"Image cleanup unavailable: {error}", file=sys.stderr)
        sys.exit(1)
