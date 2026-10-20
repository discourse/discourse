"""Reclaim recorded run volumes after their last recoverable reference expires."""
import dataclasses
import logging

import docker

LOG = logging.getLogger("codex-board-bot")
OWNER = "codex-board-bot"
PROTECTED_PHASES = {"running", "review", "stopping", "needs_attention", "integrating", "deploying", "publishing", "confirming"}


@dataclasses.dataclass(frozen=True)
class VolumeReference:
    card_id: int
    run_id: str
    kind: str
    retained: bool


def volume_plan(runs, cards, jobs):
    references = {}
    for run in runs:
        card = cards.get(run.card_id)
        current = bool(card and (card.get("run") or {}).get("run_id") == run.run_id)
        confirmed = (run.phase == "done" and bool(run.integrated_commit)
                     and run.published_commit == run.integrated_commit and bool(run.pull_request_url))
        accepted_recovery = (run.accepted_at or run.accepted_commit) and not confirmed
        retained = (accepted_recovery or run.run_id in jobs or run.cleanup_pending or run.phase in PROTECTED_PHASES
                    or ((current or run.accepted_commit) and run.phase == "integration_failed")
                    or (current and run.phase == "failed" and card["column"] not in {"DONE", "ARCHIVED"})
                    or run.phase not in PROTECTED_PHASES | {"done", "cancelled", "failed", "integration_failed"})
        for attribute, kind in (("workspace_volume", "workspace"), ("codex_volume", "session"),
                                ("integration_volume", "integration")):
            name = getattr(run, attribute)
            if name:
                references.setdefault(name, []).append(VolumeReference(run.card_id, run.run_id, kind, retained))
    return references


def collect_volumes(client, board_id, runs, cards, jobs, dry_run=False):
    plan = volume_plan(runs, cards, jobs)
    result = {"removed": [], "candidates": [], "retained": [], "errors": []}
    try:
        volumes = client.volumes.list(filters={"label": [f"owner={OWNER}", f"board_id={board_id}"]})
        containers = client.containers.list(all=True)
        attached = {mount["Name"] for container in containers
                    for mount in container.attrs.get("Mounts", []) if mount.get("Type") == "volume" and mount.get("Name")}
    except docker.errors.DockerException as error:
        result["errors"].append(f"Volume inventory failed: {error}")
        LOG.warning("%s", result["errors"][-1])
        return result
    for volume in volumes:
        refs = plan.get(volume.name)
        if not refs:
            continue
        labels = volume.attrs.get("Labels") or {}
        owned = (labels.get("owner") == OWNER and labels.get("board_id") == str(board_id)
                 and {str(ref.card_id) for ref in refs} == {labels.get("card_id")}
                 and ("run_id" not in labels or labels["run_id"] in {ref.run_id for ref in refs})
                 and ("role" not in labels or (labels["role"] == "integrator"
                      and all(ref.kind == "integration" for ref in refs))))
        if not owned or volume.name in attached or any(ref.retained for ref in refs):
            result["retained"].append(volume.name)
            continue
        result["candidates"].append(volume.name)
        if dry_run:
            continue
        try:
            volume.remove(force=False)
        except docker.errors.NotFound:
            pass
        except docker.errors.DockerException as error:
            result["errors"].append(f"Volume {volume.name} cleanup will retry: {error}")
            LOG.warning("%s", result["errors"][-1])
            continue
        result["removed"].append(volume.name)
        LOG.info("Removed obsolete run volume %s", volume.name)
    return result
