import datetime
import json
import os
import pathlib
import subprocess
import sys
import time


def features(*, changed, spec, prior):
    related = [run for run in prior if set(changed) & set(run["changed_files"])]
    failures = sum(run["specs"].get(spec, {}).get("failed", False) for run in prior)
    cofailures = sum(run["specs"].get(spec, {}).get("failed", False) for run in related)
    stem = pathlib.Path(spec).stem.removesuffix("_spec")
    return [
        len(changed),
        int(any(pathlib.Path(path).stem == stem for path in changed)),
        failures / max(len(prior), 1),
        cofailures / max(len(related), 1),
        len(related),
        int(spec in changed),
    ]


def predict(*, specs, changed, history):
    full = {"mode": "full", "reason": "Insufficient failure history", "specs": specs, "total_specs": len(specs)}
    supported = all((path.startswith(("app/", "lib/")) and path.endswith(".rb")) or path in specs for path in changed)
    if not supported:
        return dict(full, reason="Shared or untraceable input changed")
    if len(history) < 20:
        return full
    history = sorted(history, key=lambda run: run["created_at"])
    split = int(len(history) * 0.6)
    validation_end = int(len(history) * 0.8)
    prior, vectors, labels = [], [], []
    for run in history[:split]:
        for spec, result in run["specs"].items():
            vectors.append(features(changed=run["changed_files"], spec=spec, prior=prior))
            labels.append(int(result["failed"]))
        prior.append(run)
    if len(set(labels)) < 2:
        return full
    from sklearn.ensemble import HistGradientBoostingClassifier

    model = HistGradientBoostingClassifier(max_iter=40, max_leaf_nodes=8, min_samples_leaf=5, random_state=0)
    model.fit(vectors, labels)
    validation_failures = []
    for run in history[split:validation_end]:
        names = list(run["specs"])
        scores = model.predict_proba([features(changed=run["changed_files"], spec=spec, prior=prior) for spec in names])[:, 1]
        validation_failures.extend(float(score) for spec, score in zip(names, scores) if run["specs"][spec]["failed"])
    if not validation_failures:
        return full
    threshold = min(validation_failures)
    missed_changes = 0
    failing_changes = 0
    missed_failures = 0
    for run in history[validation_end:]:
        names = list(run["specs"])
        scores = model.predict_proba([features(changed=run["changed_files"], spec=spec, prior=prior) for spec in names])[:, 1]
        failures = {spec for spec in names if run["specs"][spec]["failed"]}
        selected = {spec for spec, score in zip(names, scores) if score >= threshold or spec in run["changed_files"]}
        failing_changes += bool(failures)
        missed_changes += bool(failures) and not bool(failures & selected)
        missed_failures += len(failures - selected)
    evaluation = {"failing_changes": failing_changes, "missed_changes": missed_changes, "missed_failures": missed_failures, "threshold": threshold}
    if failing_changes < 5 or missed_failures:
        return dict(full, reason="Held out safety check failed", evaluation=evaluation)
    known = {spec for run in prior for spec in run["specs"]}
    previous_failures = {spec for spec, result in history[-1]["specs"].items() if result["failed"]}
    scores = model.predict_proba([features(changed=changed, spec=spec, prior=prior) for spec in specs])[:, 1]
    selected = [spec for spec, score in zip(specs, scores) if score >= threshold or spec not in known or spec in changed or spec in previous_failures]
    if not selected:
        return dict(full, reason="Empty prediction", evaluation=evaluation)
    return {"mode": "subset", "reason": "Historical failure prediction", "specs": selected, "total_specs": len(specs), "evaluation": evaluation}


def git(*args):
    return subprocess.check_output(["git", *args], text=True).strip()


def changed_files():
    base = os.environ.get("RSPEC_BASE_SHA") or git("rev-parse", "HEAD^")
    if len(base) != 40 or any(character not in "0123456789abcdef" for character in base):
        raise ValueError("Invalid base revision")
    if subprocess.run(["git", "cat-file", "-e", base], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode:
        subprocess.run(["git", "fetch", "--no-tags", "--depth=1", "origin", base], check=True)
    return git("diff", "--name-only", "--no-renames", base, "HEAD", "--").splitlines()


def main(command):
    directory = pathlib.Path("tmp/rspec-mapping")
    directory.mkdir(parents=True, exist_ok=True)
    specs = sorted(str(path) for path in pathlib.Path("spec").rglob("*_spec.rb") if not str(path).startswith("spec/system/"))
    if command == "plan":
        started = time.monotonic()
        try:
            changed = changed_files()
            revision = git("rev-parse", "HEAD")
            history = json.loads((directory / "history.json").read_text())
            history = list({run["revision"]: run for run in history if run["revision"] != revision and run.get("specs") and run.get("changed_files")}.values())
            plan = predict(specs=specs, changed=changed, history=history)
        except Exception as error:
            plan = {"mode": "full", "reason": f"Prediction unavailable: {type(error).__name__}", "specs": specs, "total_specs": len(specs)}
        plan["selection_seconds"] = time.monotonic() - started
        (directory / "selection.json").write_text(json.dumps(plan, indent=2))
        print(json.dumps({key: value for key, value in plan.items() if key != "specs"}))
    elif command == "report":
        plan = json.loads((directory / "selection.json").read_text())
        records = [json.loads(path.read_text()) for path in (directory / "raw").glob("*.json")]
        outcomes = [outcome for record in records for outcome in record["outcomes"]]
        entries = {}
        for outcome in outcomes:
            entry = entries.setdefault(outcome["spec"], {"failed": False, "duration_seconds": 0})
            entry["failed"] |= outcome["status"] == "failed"
            entry["duration_seconds"] += outcome.get("duration_seconds") or 0
        try:
            changed = changed_files()
        except Exception:
            changed = []
        missed = [outcome["id"] for outcome in outcomes if outcome["status"] == "failed" and outcome["spec"] not in plan["specs"]]
        report = {"version": 1, "revision": git("rev-parse", "HEAD"), "created_at": datetime.datetime.now(datetime.timezone.utc).isoformat(), "changed_files": changed, "selection": plan, "specs": entries, "missed_failures": missed, "worker_cpu_seconds": sum(record["cpu_seconds"] for record in records)}
        (directory / "report.json").write_text(json.dumps(report))
        if os.environ.get("GITHUB_STEP_SUMMARY"):
            with open(os.environ["GITHUB_STEP_SUMMARY"], "a") as summary:
                summary.write(f"Prediction observation: {len(plan['specs'])}/{len(specs)} specs, {len(missed)} missed failures. All tests ran.\n")
    else:
        raise ValueError("Expected plan or report")


if __name__ == "__main__":
    main(sys.argv[1])
