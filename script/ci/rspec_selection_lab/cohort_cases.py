import argparse
import json
import os
from pathlib import Path
import zipfile

import run


def main():
    available_cases = ["order_drift", "worker_reassignment", "new_warmer", "changed_consumer", "deleted_setup_multisite"]
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", type=Path, default=Path.cwd())
    parser.add_argument("--directory", type=Path, required=True)
    parser.add_argument("--case", dest="cases", action="append", choices=available_cases)
    args = parser.parse_args()
    cases = list(dict.fromkeys(args.cases or available_cases))
    root = args.directory.resolve()
    source = args.source.resolve()
    if root == source or source in root.parents or root in source.parents:
        parser.error("Experiment directory must be outside the source checkout")
    root.mkdir(parents=True, exist_ok=False)
    (root / "owner.json").write_text(json.dumps({"source": str(source), "purpose": "worker context regression cases"}))
    reports = []
    workspace = root / "source"
    run.snapshot(source, workspace, all_specs=False, ci_bootstrap=False, include_probes=False)
    source_revision = run.git(workspace, "rev-parse", "HEAD")
    previous_order = os.environ.get("RSPEC_COHORT_ORDER")
    try:
        for name in cases:
            directory = root / name
            directory.mkdir()
            run.git(workspace, "reset", "--hard", source_revision)
            for spec in workspace.glob("spec/**/*_spec.rb"):
                spec.unlink()
            shared = workspace / "lib/rspec_cohort_cache.rb"
            shared.write_text('''module RspecCohortCache
module Producer
  def self.values
    { first: "good", second: "good" }
  end
end
class Reader
  class << self
    attr_reader :values
    def load!
      @values = Producer.values
    end
  end
end
end
''')
            ordering = workspace / "spec/support/rspec_cohort_order.rb"
            ordering.write_text('''RSpec.configure do |config|
  config.register_ordering(:global) do |groups|
    groups.sort_by do |group|
      if ENV["RSPEC_COHORT_ORDER"] == "consumer_first"
        group.metadata[:cohort_priority] == 4 ? 0 : 1
      else
        group.metadata.fetch(:cohort_priority)
      end
    end
  end
end
''')
            paths = {"warm": "spec/models/warm_spec.rb", "conditional": "spec/models/conditional_spec.rb", "consumer": "spec/requests/consumer_spec.rb", "unrelated": "spec/requests/unrelated_spec.rb"}
            bodies = {
                "warm": 'before(:context) { RspecCohortCache::Reader.load! }\nit("checks first") { expect(RspecCohortCache::Reader.values[:first]).to eq("good") }',
                "conditional": 'before(:context) { RspecCohortCache::Reader.load! unless RspecCohortCache::Reader.values }\nit("checks first") { expect(RspecCohortCache::Reader.values[:first]).to eq("good") }',
                "consumer": 'it("checks a populated cache") { expect(RspecCohortCache::Reader.values[:second]).to eq("good") if RspecCohortCache::Reader.values }',
                "unrelated": 'it("passes") { expect(true).to eq(true) }',
            }
            if name == "order_drift":
                paths = {key: value for key, value in paths.items() if key in ["warm", "consumer"]}
            if name == "deleted_setup_multisite":
                paths = {key: value for key, value in paths.items() if key != "conditional"}
            for key, path in paths.items():
                target = workspace / path
                target.parent.mkdir(parents=True, exist_ok=True)
                priority = {"warm": 1, "conditional": 2, "consumer": 4, "unrelated": 5}[key]
                target.write_text('require "rails_helper"\nrequire Rails.root.join("lib/rspec_cohort_cache")\nrequire Rails.root.join("spec/support/rspec_cohort_order")\n' + f'RSpec.describe "{key}", cohort_priority: {priority} do\n{bodies[key]}\nend\n')
            if name == "deleted_setup_multisite":
                (workspace / paths["warm"]).write_text('require "rails_helper"\nrequire Rails.root.join("lib/rspec_cohort_cache")\nRspecCohortCache::Reader.load!\n')
                consumer = workspace / paths["consumer"]
                consumer.write_text(consumer.read_text().replace('cohort_priority: 4 do', 'cohort_priority: 4, type: :multisite do').replace(bodies["consumer"], 'it("requires setup") { expect(RspecCohortCache::Reader.values).not_to eq(nil) }'))
            revision = run.commit(workspace, "Worker context baseline")
            old_weights = {"warm": 4000, "consumer": 3000, "unrelated": 2000, "conditional": 1000}
            timing = "".join(f"{path}:{old_weights[key]}\n" for key, path in paths.items()).encode()
            if name == "deleted_setup_multisite":
                old_weights = {"warm": 4000, "consumer": 300, "unrelated": 200}
                timing = "".join(f"{path}:{old_weights[key]}\n" for key, path in paths.items()).encode()
            processors = 1 if name == "order_drift" else 2
            os.environ["RSPEC_COHORT_ORDER"] = "consumer_first" if name == "order_drift" else "producer_first"
            baseline = run.run_tests(workspace, directory / "baseline", revision=revision, collect=True, timeout_seconds=180, timing=timing, processors=processors, seed=5)
            if baseline["failures"]:
                raise RuntimeError(f"Cohort baseline failed: {directory}")
            merge = run.execute(["ruby", "script/ci/rspec_selection.rb", "merge"], cwd=workspace, log=directory / "merge.log", env=dict(os.environ, GITHUB_SHA=revision), timeout_seconds=30)
            if merge["exit"]:
                raise RuntimeError(f"Cohort mapping merge failed: {directory}")
            archive = directory / "mapping.zip"
            with zipfile.ZipFile(archive, "w", zipfile.ZIP_DEFLATED) as bundle:
                bundle.write(workspace / "tmp/rspec-mapping/mapping.json", "mapping.json")
            os.environ["RSPEC_COHORT_ORDER"] = "producer_first"
            weights = {"warm": 4000, "conditional": 3000, "consumer": 2000, "unrelated": 1000}
            if name in ["order_drift", "worker_reassignment"]:
                shared.write_text(shared.read_text().replace('second: "good"', 'second: "bad"'))
            elif name == "deleted_setup_multisite":
                (workspace / paths.pop("warm")).unlink()
            elif name == "new_warmer":
                path = "spec/requests/new_warmer_spec.rb"
                paths["new"] = path
                (workspace / path).write_text('''require "rails_helper"
require Rails.root.join("lib/rspec_cohort_cache")
require Rails.root.join("spec/support/rspec_cohort_order")
RSpec.describe "new warmer", cohort_priority: 3 do
  before(:context) do
    RspecCohortCache::Reader.load!
    RspecCohortCache::Reader.values[:second] = "bad"
  end
  it("checks first") { expect(RspecCohortCache::Reader.values[:first]).to eq("good") }
end
''')
                weights = {"warm": 4000, "new": 3000, "consumer": 2000, "unrelated": 1000, "conditional": 0.01}
            else:
                consumer = workspace / paths["consumer"]
                consumer.write_text(consumer.read_text().replace('to eq("good")', 'to eq("bad")'))
                weights = {"warm": 4000, "conditional": 3000, "unrelated": 2000, "consumer": 1000}
            current = run.commit(workspace, f"Worker context case {name}")
            config = {"archive": str(archive), "mapping_revision": revision, "base_revision": revision, "revision": current, "audit_percent": 0, "calls": str(directory / "artifact-calls.json")}
            config_path = directory / "input.json"
            config_path.write_text(json.dumps(config))
            prepare = run.execute(["node", "script/ci/rspec_selection_lab/prepare.cjs", str(config_path)], cwd=workspace, log=directory / "prepare.log", env=dict(os.environ), timeout_seconds=60)
            if prepare["exit"]:
                raise RuntimeError(f"Cohort preparation failed: {directory}")
            selection_path = workspace / "tmp/rspec-mapping/selection.json"
            selection = json.loads(selection_path.read_text())
            if selection["mode"] != "subset":
                raise RuntimeError(f"Cohort case fell back to full: {selection}")
            timing = "".join(f"{path}:{weights[key]}\n" for key, path in paths.items()).encode()
            selection_path.unlink()
            full = run.run_tests(workspace, directory / "full", revision=current, collect=False, timeout_seconds=180, timing=timing, processors=processors, seed=1)
            selection_path.write_text(json.dumps(selection))
            selected = run.run_tests(workspace, directory / "selected", revision=current, collect=False, timeout_seconds=180, timing=timing, processors=processors, seed=1)
            if not full["failures"] or full["failures"] != selected["failures"] or selected["consumer"]["mode"] != "subset":
                raise RuntimeError(f"Cohort regression was missed: {directory}")
            for identity, files in selected["execution"]["workers"].items():
                if identity != "multisite" and files != full["execution"]["workers"][identity]:
                    raise RuntimeError(f"Selected worker was regrouped: {directory}")
            weakened = dict(selection, cohort_specs=[], full_multisite=False)
            if name == "deleted_setup_multisite":
                control_spec = paths["unrelated"]
            elif name == "new_warmer":
                control_spec = paths["new"]
            elif name == "changed_consumer":
                control_spec = paths["consumer"]
            else:
                control_spec = paths["warm"]
            weakened["specs"] = [control_spec]
            selection_path.write_text(json.dumps(weakened))
            control = run.run_tests(workspace, directory / "weakened-control", revision=current, collect=False, timeout_seconds=180, timing=timing, processors=processors, seed=1)
            missed = sorted(set(full["failures"]) - set(control["failures"]))
            if not missed:
                raise RuntimeError(f"Cohort fixture did not expose the weakened control: {directory}")
            report = {"name": name, "passed": True, "baseline": baseline, "full": full, "selected": selected, "weakened_control": control, "control_missed": missed}
            if name == "worker_reassignment":
                audit = dict(selection, cohort_specs=[paths["warm"]], specs=[paths["warm"]], audit=True)
                selection_path.write_text(json.dumps(audit))
                observed = run.run_tests(workspace, directory / "audit-control", revision=current, collect=False, timeout_seconds=180, timing=timing, processors=processors, seed=1)
                if observed["consumer"].get("audit_complete") is not True or not set(full["failures"]).issubset(observed["consumer"]["omitted_failures"]):
                    raise RuntimeError(f"Regular audit omissions were hidden by multisite selection: {directory}")
                report["audit_control"] = observed
            reports.append(report)
            (root / "report.json").write_text(json.dumps({"passed": len(reports) == len(cases), "requested_cases": cases, "cases": reports}, indent=2))
            print(json.dumps({"case": name, "passed": True, "missed": 0, "control_missed": len(missed)}), flush=True)
    finally:
        if previous_order is None:
            os.environ.pop("RSPEC_COHORT_ORDER", None)
        else:
            os.environ["RSPEC_COHORT_ORDER"] = previous_order
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
