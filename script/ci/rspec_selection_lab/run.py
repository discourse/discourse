import argparse
import json
import os
from pathlib import Path
import resource
import re
import shutil
import signal
import subprocess
import sys
import tarfile
import time
import uuid
import zipfile

sys.dont_write_bytecode = True

import scenarios as extra_scenarios


SAMPLE = {
    "spec/lib/url_helper_spec.rb", "spec/lib/remote_image_spec.rb",
    "spec/lib/plaintext_mentions_spec.rb", "spec/lib/slug_spec.rb",
    "spec/lib/pbkdf2_spec.rb", "spec/lib/user_name_suggester_spec.rb",
    "spec/lib/rate_limiter_spec.rb", "spec/lib/archetype_spec.rb",
    "spec/integrity/oj_spec.rb", "spec/script/rspec_mapping_spec.rb",
    "spec/models/badge_grouping_spec.rb", "spec/requests/offline_controller_spec.rb",
    "spec/jobs/create_missing_avatars_spec.rb", "spec/views/topics/show.html.erb_spec.rb",
}


def container_cpu_seconds():
    try:
        if Path("/proc/self/cgroup").read_text().strip() != "0::/":
            return None
        return int(dict(line.split() for line in Path("/sys/fs/cgroup/cpu.stat").read_text().splitlines())["usage_usec"]) / 1_000_000
    except (OSError, KeyError, ValueError):
        return None


def allocated_processors():
    available = len(os.sched_getaffinity(0)) if hasattr(os, "sched_getaffinity") else (os.cpu_count() or 1)
    try:
        quota, period = Path("/sys/fs/cgroup/cpu.max").read_text().split()
        return min(available, int(quota) / int(period)) if quota != "max" else available
    except (FileNotFoundError, PermissionError):
        return available


def execute(command, *, cwd, log, env, timeout_seconds):
    before = resource.getrusage(resource.RUSAGE_CHILDREN)
    container_before = container_cpu_seconds()
    started = time.monotonic()
    with log.open("wb") as output:
        process = subprocess.Popen(command, cwd=cwd, env=env, stdout=output, stderr=subprocess.STDOUT, start_new_session=True)
        try:
            code = process.wait(timeout=timeout_seconds)
        except (subprocess.TimeoutExpired, KeyboardInterrupt):
            os.killpg(process.pid, signal.SIGTERM)
            try:
                process.wait(timeout=10)
            except subprocess.TimeoutExpired:
                os.killpg(process.pid, signal.SIGKILL)
                process.wait()
            raise
    after = resource.getrusage(resource.RUSAGE_CHILDREN)
    container_after = container_cpu_seconds()
    workers = after.ru_utime + after.ru_stime - before.ru_utime - before.ru_stime
    container = container_after - container_before if container_before is not None and container_after is not None else None
    return {"exit": code, "wall_seconds": time.monotonic() - started,
            "cpu_seconds": container if container is not None else workers,
            "worker_cpu_seconds": workers,
            "cpu_scope": "cgroup namespace root including all its processes" if container is not None else "child processes excluding services",
            "cgroup_identity": Path("/proc/self/cgroup").read_text().strip() if Path("/proc/self/cgroup").exists() else None}


def git(workspace, *arguments):
    return subprocess.check_output(["git", "-C", str(workspace), "-c", "user.name=RSpec lab", "-c", "user.email=rspec-lab@example.invalid", "-c", "commit.gpgsign=false", "-c", "core.hooksPath=/dev/null", *arguments], text=True, timeout=180).strip()


def snapshot(source, workspace, *, all_specs, ci_bootstrap):
    workspace.mkdir()
    archive = workspace.parent / "source.tar"
    with archive.open("wb") as output:
        subprocess.run(["git", "-C", str(source), "archive", "HEAD"], stdout=output, check=True, timeout=180)
    with tarfile.open(archive) as bundle:
        bundle.extractall(workspace, filter="data")
    archive.unlink()
    changed = git(source, "diff", "--name-only", "HEAD").splitlines()
    changed += git(source, "ls-files", "--others", "--exclude-standard").splitlines()
    for relative in changed:
        if "__pycache__" in Path(relative).parts:
            continue
        origin = source / relative
        target = workspace / relative
        if origin.is_file():
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(origin, target)
        elif not origin.exists():
            target.unlink(missing_ok=True)
    if not all_specs:
        for spec in (workspace / "spec").rglob("*_spec.rb"):
            if str(spec.relative_to(workspace)) not in SAMPLE:
                spec.unlink()
    links = [".bundle", "config/database.yml", "config/redis.yml", "public/assets"]
    if not ci_bootstrap:
        links.append("node_modules")
    for relative in links:
        target = workspace / relative
        if (source / relative).exists() and not target.exists():
            target.parent.mkdir(parents=True, exist_ok=True)
            target.symlink_to(source / relative)
    uploads = source / "public/uploads"
    if uploads.exists():
        shutil.copytree(uploads, workspace / "public/uploads", dirs_exist_ok=True)
    (workspace / "log").mkdir(exist_ok=True)
    extra_scenarios.setup(workspace)
    git(workspace, "init", "-q")
    git(workspace, "add", ".")
    git(workspace, "commit", "-qm", "Local experiment baseline")
    origin = workspace.parent / "origin.git"
    subprocess.run(["git", "clone", "--quiet", "--bare", str(workspace), str(origin)], check=True, timeout=180)
    git(workspace, "remote", "add", "origin", origin.as_uri())


def commit(workspace, message):
    git(workspace, "add", ".")
    git(workspace, "commit", "--allow-empty", "-qm", message)
    revision = git(workspace, "rev-parse", "HEAD")
    git(workspace, "push", "--quiet", "origin", f"HEAD:refs/heads/lab-{revision}")
    return revision


def append(workspace, path, content):
    with (workspace / path).open("a") as output:
        output.write(content)


def replace(workspace, path, before, after):
    target = workspace / path
    content = target.read_text()
    if before not in content:
        raise RuntimeError(f"Scenario anchor missing in {path}")
    target.write_text(content.replace(before, after, 1))


def break_helper(workspace):
    replace(workspace, "lib/url_helper.rb", "  def self.normalized_encode(uri)\n", '  def self.normalized_encode(uri)\n    return "https://broken.invalid"\n')


def run_tests(workspace, directory, *, revision, collect, timeout_seconds, timing, guard_error=None, processors=2):
    directory.mkdir()
    history = workspace / "tmp/turbo_rspec_runtime.log"
    if timing is not None:
        history.write_bytes(timing)
    else:
        history.unlink(missing_ok=True)
    env = dict(os.environ, CI="true", GITHUB_ACTIONS="true", USES_PARALLEL_DATABASES="true", GITHUB_SHA=revision, COLLECT_RSPEC_MAPPING="1" if collect else "0",
               RSPEC_MAPPING_DIRECTORY=str(workspace / "tmp/rspec-mapping"),
               RSPEC_LAB_RESULTS=str(directory / "examples"), PARALLEL_TEST_PROCESSORS=str(processors),
               DISCOURSE_TURBO_RSPEC_RETRY_AND_LOG_FLAKY_TESTS="0",
               SPEC_OPTS=f"--require {workspace}/script/ci/rspec_selection_lab/record.rb --seed 123")
    if os.environ.get("RUBY_ALLOCATOR"):
        env["LD_PRELOAD"] = os.environ["RUBY_ALLOCATOR"]
    result = execute(["ruby", "script/ci/rspec_selection.rb", "run"], cwd=workspace, log=directory / "run.log", env=env, timeout_seconds=timeout_seconds)
    if guard_error:
        if result["exit"] == 0 or guard_error not in (directory / "run.log").read_text():
            raise RuntimeError(f"Expected guard did not reject the run: {directory}")
        result.update(examples=0, failures=[], seeds=[], executed_files=0, guard_error=guard_error)
        (directory / "measurement.json").write_text(json.dumps(result, indent=2))
        return result
    records = [json.loads(path.read_text()) for path in (directory / "examples").glob("*.json")]
    if not records or any(record["errors"] != 0 for record in records) or result["exit"] not in (0, 1):
        raise RuntimeError(f"Test infrastructure failed, inspect {directory}/run.log")
    if any(record["seed"] != 123 for record in records):
        raise RuntimeError(f"Test seed differs from the comparison seed: {directory}")
    examples = {example["id"]: example["status"] for record in records for example in record["examples"]}
    if not examples:
        raise RuntimeError(f"No examples executed: {directory}")
    failures = sorted(identity for identity, status in examples.items() if status == "failed")
    if (result["exit"] == 0) != (len(failures) == 0):
        raise RuntimeError(f"Test exit does not match recorded failures: {directory}")
    log_text = (directory / "run.log").read_text()
    file_count = re.search(r"Running turbo_rspec on (\d+) files", log_text)
    explicit = re.search(r"^Running turbo_rspec on: (.+)$", log_text, re.MULTILINE)
    if not file_count and not explicit:
        raise RuntimeError(f"Turbo did not report its files: {directory}")
    explicit_specs = explicit[1].split(", ") if explicit else None
    consumer = json.loads((workspace / "tmp/rspec-mapping/run.json").read_text())
    result["consumer"] = consumer
    result.update(examples=len(examples), failures=failures, seeds=[record["seed"] for record in records],
                  executed_files=int(file_count[1]) if file_count else len(explicit_specs), explicit_specs=explicit_specs)
    (directory / "measurement.json").write_text(json.dumps(result, indent=2))
    return result


def main():
    scenarios = ["documentation", "mapped_helper", "changed_spec", "new_file_and_spec", "shared_configuration", "stale_mapping", "main_configuration_drift", "reverted_spec", "missing_mapping", "corrupt_mapping", "failed_producer", "lost_dependency_control", *extra_scenarios.CASES]
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", type=Path, default=Path.cwd())
    parser.add_argument("--directory", type=Path, required=True)
    parser.add_argument("--all-specs", action="store_true")
    parser.add_argument("--baseline-only", action="store_true")
    parser.add_argument("--ci-bootstrap", action="store_true")
    parser.add_argument("--processors", type=int, default=int(os.environ.get("PARALLEL_TEST_PROCESSORS", "2")))
    parser.add_argument("--scenario", choices=scenarios, action="append")
    parser.add_argument("--timeout-seconds", type=int, default=300)
    parser.add_argument("--pr-runs-per-main", type=float, default=1.0)
    args = parser.parse_args()
    if args.all_specs and not args.baseline_only and not args.scenario:
        parser.error("Choose --scenario explicitly with --all-specs to bound compute")
    scenarios = list(dict.fromkeys(args.scenario or scenarios))
    if args.processors < 1:
        parser.error("--processors must be positive")
    if args.pr_runs_per_main <= 0:
        parser.error("--pr-runs-per-main must be positive")
    os.environ.update(CI="true", GITHUB_ACTIONS="true", USES_PARALLEL_DATABASES="true")
    source = args.source.resolve()
    root = args.directory.resolve()
    if root == source or source in root.parents or root in source.parents:
        parser.error("Experiment directory must be outside the source checkout")
    root.mkdir(parents=True, exist_ok=False)
    (root / "owner.json").write_text(json.dumps({"source": str(source), "id": str(uuid.uuid4()), "purpose": "disposable RSpec selection experiment"}, indent=2))
    workspace = root / "source"
    snapshot(source, workspace, all_specs=args.all_specs, ci_bootstrap=args.ci_bootstrap)
    revision = git(workspace, "rev-parse", "HEAD")
    mapping_directory = workspace / "tmp/rspec-mapping"
    mapping_directory.mkdir(parents=True, exist_ok=True)
    hidden_modules = []
    setup = []
    def restore_modules():
        for original, hidden in reversed(hidden_modules):
            hidden.rename(original)
        hidden_modules.clear()

    def build_assets(log):
        restore_modules()
        result = execute(["bin/rake", "assets:precompile:asset_processor", "assets:precompile:pretty_text"],
                         cwd=workspace, log=log, env=dict(os.environ), timeout_seconds=max(args.timeout_seconds, 300))
        if result["exit"]:
            raise RuntimeError(f"CI bundle compilation failed: {log}")
        stash = root / "dependency-stash"
        stash.mkdir(exist_ok=True)
        for directory, children, _files in os.walk(workspace):
            if ".git" in children:
                children.remove(".git")
            if "node_modules" in children:
                original = Path(directory) / "node_modules"
                hidden = stash / str(len(hidden_modules))
                original.rename(hidden)
                hidden_modules.append((original, hidden))
                children.remove("node_modules")
        return result

    try:
        if args.ci_bootstrap:
            installation = execute(["pnpm", "install", "--frozen-lockfile"], cwd=workspace,
                                   log=root / "pnpm.log", env=dict(os.environ, CI="1", LEFTHOOK="0"), timeout_seconds=600)
            if installation["exit"]:
                raise RuntimeError("CI dependency installation failed")
            setup.append(installation)
            setup.append(build_assets(root / "baseline-assets.log"))
        print(json.dumps({"phase": "baseline", "workspace": str(workspace)}), flush=True)
        plain = run_tests(workspace, root / "baseline", revision=revision, collect=False, timeout_seconds=args.timeout_seconds, timing=None, processors=args.processors)
        if plain["failures"]:
            raise RuntimeError("Baseline must pass before evaluating selection")
        print(json.dumps({"phase": "traced-main", "examples": plain["examples"]}), flush=True)
        traced = run_tests(workspace, root / "traced-main", revision=revision, collect=True, timeout_seconds=args.timeout_seconds, timing=None, processors=args.processors)
        if traced["failures"]:
            raise RuntimeError("Traced baseline must pass")
        env = dict(os.environ, GITHUB_SHA=revision)
        merge = execute(["ruby", "script/ci/rspec_selection.rb", "merge"], cwd=workspace, log=root / "merge.log", env=env, timeout_seconds=30)
        if merge["exit"]:
            raise RuntimeError("Real mapping merge failed")
        archive = root / "main-mapping.zip"
        packaging_started = time.monotonic()
        packaging_container_before = container_cpu_seconds()
        packaging_usage = resource.getrusage(resource.RUSAGE_SELF)
        with zipfile.ZipFile(archive, "w", zipfile.ZIP_DEFLATED) as bundle:
            bundle.write(mapping_directory / "mapping.json", "mapping.json")
        packaged_usage = resource.getrusage(resource.RUSAGE_SELF)
        packaging_container_after = container_cpu_seconds()
        packaging_worker_cpu = packaged_usage.ru_utime + packaged_usage.ru_stime - packaging_usage.ru_utime - packaging_usage.ru_stime
        packaging = {"wall_seconds": time.monotonic() - packaging_started,
                     "cpu_seconds": packaging_container_after - packaging_container_before if packaging_container_before is not None and packaging_container_after is not None else packaging_worker_cpu}
        timing = (workspace / "tmp/turbo_rspec_runtime.log").read_bytes()
        report = {"scope": "all core backend specs plus dependency probes" if args.all_specs else "bounded core sample plus dependency probes",
                  "processors": args.processors, "allocated_processors": allocated_processors(), "ci_eager_loading": True, "ci_bootstrap": args.ci_bootstrap, "common_setup": setup,
                  "transport": "local artifact bytes and simulated Actions metadata, no GitHub requests",
                  "baseline": plain, "traced_main": traced, "merge": merge, "artifact_packaging": packaging,
                  "mapping_bytes": (mapping_directory / "mapping.json").stat().st_size, "scenarios": []}
        (root / "report.json").write_text(json.dumps(report, indent=2))
        if args.baseline_only:
            print(json.dumps({"report": str(root / "report.json"), "mapping_bytes": report["mapping_bytes"]}), flush=True)
            restore_modules()
            return 0
        for index, name in enumerate(scenarios):
            restore_modules()
            git(workspace, "reset", "--hard", revision)
            directory = root / name
            directory.mkdir()
            base = revision
            expected_mode = "subset"
            expected_failures = name not in ["documentation", "reverted_spec"]
            if name in extra_scenarios.CASES:
                expected_mode, expected_failures = extra_scenarios.apply(workspace, name, append=append, replace=replace, break_helper=break_helper)
            elif name == "documentation":
                append(workspace, "README.md", "\nLocal selection experiment.\n")
            elif name == "changed_spec":
                append(workspace, "spec/lib/archetype_spec.rb", '\nRSpec.describe Archetype do\n  it("detects the experiment regression") { expect(Archetype.default).to eq("broken") }\nend\n')
            elif name == "new_file_and_spec":
                expected_mode = "full"
                (workspace / "lib/rspec_lab_fixture.rb").write_text('class RspecLabFixture\n  def self.value\n    false\n  end\nend\n')
                (workspace / "spec/lib/rspec_lab_fixture_spec.rb").write_text('require "rails_helper"\nrequire "rspec_lab_fixture"\nRSpec.describe RspecLabFixture do\n  it("detects the experiment regression") { expect(RspecLabFixture.value).to eq(true) }\nend\n')
            elif name == "stale_mapping":
                anchor = '  def self.for(string, default = "topic", max_length = MAX_LENGTH, method: nil)\n'
                replace(workspace, "lib/slug.rb", anchor, anchor + '    raise "URL normalization changed" unless UrlHelper.normalized_encode("https://example.com") == "https://example.com"\n')
                base = commit(workspace, "Main introduces a dependency after mapping")
                break_helper(workspace)
            elif name == "main_configuration_drift":
                expected_mode = "full"
                append(workspace, "config/site_settings.yml", "\n")
                base = commit(workspace, "Main configuration drift")
                break_helper(workspace)
            elif name == "reverted_spec":
                original = (workspace / "spec/lib/archetype_spec.rb").read_bytes()
                append(workspace, "spec/lib/archetype_spec.rb", "\n")
                base = commit(workspace, "Main spec change after mapping")
                (workspace / "spec/lib/archetype_spec.rb").write_bytes(original)
            else:
                break_helper(workspace)
                if name == "shared_configuration":
                    append(workspace, "config/site_settings.yml", "\n")
                if name in ["shared_configuration", "missing_mapping", "corrupt_mapping", "failed_producer"]:
                    expected_mode = "full"
            current = commit(workspace, f"PR scenario {name}")
            if not git(workspace, "diff", "--name-only", f"{base}..{current}"):
                raise RuntimeError(f"Scenario produced no tracked PR changes: {name}")
            common_setup = build_assets(directory / "assets.log") if args.ci_bootstrap else None
            input_archive = archive
            if name == "corrupt_mapping":
                input_archive = directory / "corrupt.zip"
                input_archive.write_bytes(b"not a zip file")
            if name in ["lost_dependency_control", "audit_miss_control", "missing_spec_entry", "invalid_schema", "revision_mismatch", "missing_zip_member"]:
                input_archive = directory / "incomplete.zip"
                with zipfile.ZipFile(archive) as baseline_archive:
                    mapping = json.loads(baseline_archive.read("mapping.json"))
                if name in ["lost_dependency_control", "audit_miss_control"]:
                    omitted_spec = "spec/lib/url_helper_spec.rb"
                    mapping["dependencies"][omitted_spec] = []
                    mapping["worker_spec_order"] = [[spec for spec in order if spec != omitted_spec] for order in mapping["worker_spec_order"]] + [[omitted_spec]]
                elif name == "missing_spec_entry":
                    del mapping["dependencies"]["spec/lib/url_helper_spec.rb"]
                elif name == "invalid_schema":
                    mapping["version"] = 999
                elif name == "revision_mismatch":
                    mapping["revision"] = "0" * 40
                with zipfile.ZipFile(input_archive, "w", zipfile.ZIP_DEFLATED) as bundle:
                    bundle.writestr("wrong.json" if name == "missing_zip_member" else "mapping.json", json.dumps(mapping))
            config = {"archive": str(input_archive), "mapping_revision": revision, "base_revision": base,
                      "revision": current, "missing": name == "missing_mapping",
                      "producer_conclusion": "failure" if name == "failed_producer" else "success",
                      "calls": str(directory / "artifact-calls.json")}
            overrides = {
                "expired_mapping": {"artifact": {"expired": True}},
                "oversized_mapping": {"artifact": {"size_in_bytes": 50000001}},
                "wrong_workflow": {"run": {"path": ".github/workflows/unrelated.yml"}},
                "wrong_event": {"run": {"event": "pull_request"}},
                "fork_mapping": {"run": {"head_repository": {"id": 2}}},
                "wrong_branch": {"run": {"head_branch": "feature"}},
                "download_error": {"download_error": True},
            }
            config.update(overrides.get(name, {}))
            if name in ["audit_subset", "audit_miss_control"]:
                config["audit_percent"] = 100
            elif name == "audit_override":
                config["mode"] = "audit"
            elif name == "full_override":
                config["mode"] = "full"
            (directory / "input.json").write_text(json.dumps(config))
            preparation = execute(["node", "script/ci/rspec_selection_lab/prepare.cjs", str(directory / "input.json")], cwd=workspace, log=directory / "prepare.log", env=env, timeout_seconds=60)
            if preparation["exit"]:
                raise RuntimeError(f"Preparation failed: {directory}")
            selection_path = mapping_directory / "selection.json"
            plan = json.loads(selection_path.read_text())
            selection = selection_path.read_bytes()
            (directory / "selection.json").write_bytes(selection)
            results = {}
            for mode in (["full", "selected"] if index % 2 == 0 else ["selected", "full"]):
                if mode == "full":
                    selection_path.unlink(missing_ok=True)
                else:
                    selection_path.write_bytes(selection)
                    if name == "consumer_missing":
                        selection_path.unlink()
                    elif name == "consumer_corrupt":
                        selection_path.write_text("invalid JSON")
                    elif name == "consumer_stale":
                        stale = dict(plan, revision="0" * 40)
                        selection_path.write_text(json.dumps(stale))
                results[mode] = run_tests(workspace, directory / mode, revision=current, collect=False, timeout_seconds=args.timeout_seconds, timing=timing, guard_error="There are pending migrations" if name == "pending_migration" else None, processors=args.processors)
            missed = sorted(set(results["full"]["failures"]) - set(results["selected"]["failures"]))
            extra = sorted(set(results["selected"]["failures"]) - set(results["full"]["failures"]))
            expected_execution_mode = "full" if name.startswith("consumer_") or name in ["audit_subset", "audit_miss_control", "audit_override"] else expected_mode
            if results["selected"].get("consumer", {}).get("reason") == "Source structure changed or unavailable":
                expected_execution_mode = "full"
            if name.startswith("consumer_"):
                expected_mode = "subset"
            if plan["mode"] != expected_mode:
                raise RuntimeError(f"Unexpected selection mode for {name}: expected {expected_mode}, received {plan}")
            inventory_size = len([path for path in workspace.glob("spec/**/*_spec.rb") if not str(path.relative_to(workspace)).startswith("spec/system/")])
            full_files = 0 if name == "pending_migration" else inventory_size
            selected_files = full_files if expected_execution_mode == "full" else len(plan["specs"])
            if results["full"]["executed_files"] != full_files or results["selected"]["executed_files"] != selected_files:
                raise RuntimeError(f"Wrapper executed an unexpected file count: {directory}")
            if expected_execution_mode == "subset" and results["selected"]["explicit_specs"] is not None and results["selected"]["explicit_specs"] != plan["specs"]:
                raise RuntimeError(f"Turbo received different specs than selected: {directory}")
            passed = not missed and not extra and plan["mode"] == expected_mode and bool(results["full"]["failures"]) == expected_failures
            if name == "lost_dependency_control":
                passed = bool(missed) and not extra and plan["mode"] == "subset"
            if name == "audit_miss_control":
                passed = passed and bool(results["selected"]["consumer"].get("omitted_failures"))
            if name in ["audit_subset", "audit_miss_control", "audit_override"]:
                passed = passed and results["selected"]["consumer"].get("audit_complete") == True
            if name == "new_file_and_spec":
                passed = passed and (plan["mode"] == "full" or "spec/lib/rspec_lab_fixture_spec.rb" in plan.get("specs", []))
            if name == "reverted_spec":
                passed = passed and "spec/lib/archetype_spec.rb" in plan.get("specs", [])
            record = {"name": name, "common_setup": common_setup, "passed": passed, "negative_control": name in ["lost_dependency_control", "audit_miss_control"], "selection": plan, "prepare": preparation,
                      "full": results["full"], "selected": results["selected"], "missed": missed, "extra": extra}
            report["scenarios"].append(record)
            (root / "report.json").write_text(json.dumps(report, indent=2))
            print(json.dumps({"scenario": name, "passed": passed, "mode": plan["mode"], "selected_files": len(plan.get("specs", [])) if plan["mode"] == "subset" else "all", "missed": len(missed)}), flush=True)
        positive_cases = [case for case in report["scenarios"] if not case["negative_control"]]
        main_runs = len(positive_cases) / args.pr_runs_per_main
        setup_cpu = sum(item["cpu_seconds"] for item in setup)
        setup_wall = sum(item["wall_seconds"] for item in setup)
        installation_cpu = setup[0]["cpu_seconds"] if setup else 0
        installation_wall = setup[0]["wall_seconds"] if setup else 0
        pr_setup_cpu = sum(installation_cpu + (case["common_setup"]["cpu_seconds"] if case["common_setup"] else 0) for case in positive_cases)
        pr_setup_wall = sum(installation_wall + (case["common_setup"]["wall_seconds"] if case["common_setup"] else 0) for case in positive_cases)
        full_cpu = main_runs * (plain["cpu_seconds"] + setup_cpu) + pr_setup_cpu + sum(case["full"]["cpu_seconds"] for case in positive_cases)
        selected_cpu = main_runs * (traced["cpu_seconds"] + merge["cpu_seconds"] + packaging["cpu_seconds"] + setup_cpu) + pr_setup_cpu + sum(case["selected"]["cpu_seconds"] + case["prepare"]["cpu_seconds"] for case in positive_cases)
        report["compute"] = {"baseline_cpu_seconds": full_cpu, "selection_cpu_seconds": selected_cpu,
                             "saving_percent": 100 * (full_cpu - selected_cpu) / full_cpu,
                             "baseline_wall_seconds": main_runs * (plain["wall_seconds"] + setup_wall) + pr_setup_wall + sum(case["full"]["wall_seconds"] for case in positive_cases),
                             "selection_wall_seconds": main_runs * (traced["wall_seconds"] + merge["wall_seconds"] + packaging["wall_seconds"] + setup_wall) + pr_setup_wall + sum(case["selected"]["wall_seconds"] + case["prepare"]["wall_seconds"] for case in positive_cases),
                             "accounting": f"{main_runs:g} main runs plus {len(positive_cases)} PR scenarios, including tracing, merge, artifact packaging and preparation; replay setup and negative control excluded; local transport omits GitHub network latency"}
        report["compute"]["baseline_allocated_cpu_seconds"] = report["compute"]["baseline_wall_seconds"] * report["allocated_processors"]
        report["compute"]["selection_allocated_cpu_seconds"] = report["compute"]["selection_wall_seconds"] * report["allocated_processors"]
        report["compute"]["allocated_saving_percent"] = 100 * (1 - report["compute"]["selection_wall_seconds"] / report["compute"]["baseline_wall_seconds"])
        report["compute"]["cpu_scope"] = plain["cpu_scope"]
        report["passed"] = all(case["passed"] for case in report["scenarios"])
        (root / "report.json").write_text(json.dumps(report, indent=2))
        print(json.dumps({"passed": report["passed"], "compute": report["compute"], "report": str(root / "report.json")}), flush=True)
        restore_modules()
        return 0 if report["passed"] else 1
    finally:
        restore_modules()


if __name__ == "__main__":
    raise SystemExit(main())
