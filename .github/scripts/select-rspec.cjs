const fs = require("node:fs");
const { execFileSync } = require("node:child_process");
const { matchesGlob } = require("node:path");

function git(...args) {
  return execFileSync("git", args, {
    encoding: "utf8",
    timeout: 30_000,
    maxBuffer: 10_000_000,
  });
}

function containerCpuSeconds() {
  try {
    if (fs.readFileSync("/proc/self/cgroup", "utf8").trim() !== "0::/")
      return null;
    const match = fs
      .readFileSync("/sys/fs/cgroup/cpu.stat", "utf8")
      .match(/^usage_usec (\d+)$/m);
    return match ? Number(match[1]) / 1_000_000 : null;
  } catch {
    return null;
  }
}

function isCoreSpec(path) {
  return /^spec\/(?!system\/).*_spec\.rb$/.test(path);
}

function select({ mapping, revision, inventory, changed, structural = [] }) {
  const full = (reason) => ({ mode: "full", revision, reason });
  if (
    mapping.version !== 4 ||
    !Array.isArray(mapping.worker_specs) ||
    !mapping.worker_specs.every(
      (order) =>
        Array.isArray(order) && order.every((spec) => typeof spec === "string")
    ) ||
    !Object.hasOwn(mapping, "grouping_runtime_log") ||
    !(
      mapping.grouping_runtime_log === null ||
      (typeof mapping.grouping_runtime_log === "string" &&
        Buffer.byteLength(mapping.grouping_runtime_log) <= 2_000_000)
    ) ||
    !Array.isArray(mapping.empty_specs) ||
    !mapping.empty_specs.every((spec) => typeof spec === "string") ||
    !Array.isArray(mapping.shared_files) ||
    !mapping.shared_files.every((file) => typeof file === "string") ||
    !Array.isArray(mapping.shared_globs) ||
    !mapping.shared_globs.every((pattern) => typeof pattern === "string") ||
    !/^[a-f0-9]{40}$/.test(mapping.revision) ||
    !mapping.source_checks ||
    typeof mapping.source_checks !== "object" ||
    Array.isArray(mapping.source_checks) ||
    !mapping.dependencies ||
    typeof mapping.dependencies !== "object" ||
    Array.isArray(mapping.dependencies)
  ) {
    return full("Invalid mapping");
  }

  const selected = new Set(
    inventory.filter(
      (spec) =>
        spec.startsWith("spec/integrity/") &&
        spec !== "spec/integrity/i18n_spec.rb"
    )
  );
  const changedPaths = new Set(changed);
  const directlyAffected = new Set();
  const sources = new Set();
  for (const [spec, dependencies] of Object.entries(mapping.dependencies)) {
    if (
      !Array.isArray(dependencies) ||
      !dependencies.every((path) => typeof path === "string")
    ) {
      return full("Invalid dependencies");
    }
    dependencies.forEach((path) => sources.add(path.replace(/^\.\//, "")));
    if (
      dependencies.some((path) => changedPaths.has(path.replace(/^\.\//, "")))
    ) {
      selected.add(spec.replace(/^\.\//, ""));
      directlyAffected.add(spec.replace(/^\.\//, ""));
    }
  }

  for (const spec of changed) {
    if (isCoreSpec(spec)) {
      directlyAffected.add(spec);
    }
  }
  const cohorts = mapping.worker_specs.map((cohort) =>
    cohort.map((spec) => spec.replace(/^\.\//, ""))
  );
  const recordedSpecs = new Set(cohorts.flat());
  if (
    Object.keys(mapping.dependencies).some(
      (spec) => !recordedSpecs.has(spec.replace(/^\.\//, ""))
    )
  ) {
    return full("Incomplete worker cohorts");
  }
  const cohortSpecs = new Set(directlyAffected);
  for (const cohort of cohorts) {
    if (cohort.some((spec) => directlyAffected.has(spec))) {
      cohort.forEach((spec) => cohortSpecs.add(spec));
    }
  }
  for (const spec of inventory) {
    if (!Object.hasOwn(mapping.dependencies, spec)) {
      if (mapping.empty_specs.includes(spec)) {
        selected.add(spec);
      } else {
        cohortSpecs.add(spec);
      }
    }
  }
  cohortSpecs.forEach((spec) => selected.add(spec));

  const sourceChecks = {};
  for (const path of changed) {
    if (/(^|\/)locale[^/]*\/[^/]+\.ya?ml$/.test(path)) {
      return full(`Locale input: ${path}`);
    }
    if (mapping.shared_files.includes(path)) {
      return full(`Shared file input: ${path}`);
    }
    if (structural.includes(path) && path.startsWith("frontend/")) {
      return full(`Changed frontend file inventory: ${path}`);
    }
    if (mapping.shared_globs.some((pattern) => matchesGlob(path, pattern))) {
      return full(`Shared bundle input: ${path}`);
    }
    if (isCoreSpec(path)) {
      continue;
    }
    if (/^(app|lib)\/.*\.rb$/.test(path)) {
      if (
        structural.includes(path) ||
        !sources.has(path) ||
        !mapping.source_checks[path]
      ) {
        return full(`Unmapped Ruby source: ${path}`);
      }
      sourceChecks[path] = mapping.source_checks[path];
      continue;
    }
    if (
      /^(docs\/|plugins\/|spec\/system\/)/.test(path) ||
      /^[^/]+\.md$/.test(path) ||
      /^frontend\/discourse\/(app|admin|tests)\/.*\.(js|gjs|ts|gts|hbs|css|scss)$/.test(
        path
      )
    ) {
      continue;
    }
    return full(`Shared or untraceable file: ${path}`);
  }

  return {
    mode: "subset",
    revision,
    mapping_revision: mapping.revision,
    source_checks: sourceChecks,
    specs: inventory.filter((spec) => selected.has(spec)),
    cohort_specs: inventory.filter((spec) => cohortSpecs.has(spec)),
    full_multisite: cohortSpecs.size > 0,
  };
}

async function prepare({
  github,
  context,
  core,
  mode = process.env.RSPEC_SELECTION_MODE || "select",
  auditPercent = process.env.RSPEC_SELECTION_AUDIT_PERCENT ?? 10,
}) {
  const started = Date.now();
  if (typeof auditPercent === "string") {
    auditPercent = /^\d+$/.test(auditPercent)
      ? Number(auditPercent)
      : Number.NaN;
  }
  const containerBefore = containerCpuSeconds();
  const revision = context.sha;
  const configuredFull =
    !["select", "audit", "full"].includes(mode) ||
    !Number.isInteger(auditPercent) ||
    auditPercent < 0 ||
    auditPercent > 100 ||
    mode === "full";
  let selection = { mode: "full", revision, reason: "Not a PR targeting main" };
  fs.mkdirSync("tmp/rspec-mapping", { recursive: true });
  try {
    if (
      !configuredFull &&
      context.eventName === "pull_request" &&
      context.payload.pull_request.base.ref === "main"
    ) {
      const { data } = await github.rest.actions.listArtifactsForRepo({
        ...context.repo,
        name: "rspec-core-mapping-main",
        per_page: 20,
      });
      const candidates = data.artifacts
        .filter(
          (artifact) =>
            !artifact.expired &&
            artifact.size_in_bytes <= 50_000_000 &&
            artifact.workflow_run
        )
        .sort((left, right) => right.workflow_run.id - left.workflow_run.id);
      selection.reason = "No successful main mapping available";
      for (const artifact of candidates) {
        try {
          const { data: run } = await github.rest.actions.getWorkflowRun({
            ...context.repo,
            run_id: artifact.workflow_run.id,
          });
          if (
            run.path !== ".github/workflows/tests.yml" ||
            run.event !== "push" ||
            run.head_branch !== "main" ||
            run.repository.id !== context.payload.repository.id ||
            run.head_repository.id !== context.payload.repository.id
          ) {
            continue;
          }
          const { data: jobs } =
            await github.rest.actions.listJobsForWorkflowRun({
              ...context.repo,
              run_id: run.id,
              per_page: 100,
            });
          if (
            !jobs.jobs.some(
              (job) =>
                job.name === "core backend" && job.conclusion === "success"
            )
          ) {
            continue;
          }
          const archive = await github.rest.actions.downloadArtifact({
            ...context.repo,
            artifact_id: artifact.id,
            archive_format: "zip",
          });
          fs.writeFileSync(
            "tmp/rspec-mapping/mapping.zip",
            Buffer.from(archive.data)
          );
          const mapping = JSON.parse(
            execFileSync(
              "python3",
              [
                "-c",
                "import sys,zipfile; z=zipfile.ZipFile(sys.argv[1]); e=z.getinfo('mapping.json'); assert e.file_size <= 50000000; sys.stdout.buffer.write(z.read(e))",
                "tmp/rspec-mapping/mapping.zip",
              ],
              { encoding: "utf8", timeout: 30_000, maxBuffer: 50_000_000 }
            )
          );
          if (mapping.revision !== run.head_sha) {
            throw new Error("Mapping revision differs from producer");
          }
          const baseRevision = context.payload.pull_request.base.sha;
          git(
            "fetch",
            "--no-tags",
            "--depth=1",
            "origin",
            mapping.revision,
            baseRevision
          );
          const inventory = git("ls-files", "-z", "spec")
            .split("\0")
            .filter(isCoreSpec);
          const prChanged = git(
            "diff",
            "--no-renames",
            "--name-only",
            "-z",
            `${baseRevision}..${revision}`
          )
            .split("\0")
            .filter(Boolean);
          const changed = [
            ...new Set([
              ...prChanged,
              ...git(
                "diff",
                "--no-renames",
                "--name-only",
                "-z",
                `${mapping.revision}..${revision}`
              )
                .split("\0")
                .filter(Boolean),
            ]),
          ];
          selection = select({
            mapping,
            revision,
            inventory,
            changed,
            structural: [mapping.revision, baseRevision].flatMap((base) =>
              git(
                "diff",
                "--no-renames",
                "--diff-filter=ADRT",
                "--name-only",
                "-z",
                `${base}..${revision}`
              )
                .split("\0")
                .filter(Boolean)
            ),
          });
          if (selection.mode === "subset") {
            if (mapping.grouping_runtime_log === null) {
              fs.rmSync("tmp/turbo_rspec_runtime.log", { force: true });
            } else {
              fs.writeFileSync(
                "tmp/turbo_rspec_runtime.log",
                mapping.grouping_runtime_log
              );
            }
          }
          break;
        } catch (error) {
          selection.reason = `Mapping unavailable: ${error.message.slice(0, 500)}`;
          core.warning(selection.reason);
        }
      }
    }
  } catch (error) {
    selection = {
      mode: "full",
      revision,
      reason: `Selection unavailable: ${error.message.slice(0, 500)}`,
    };
    core.warning(selection.reason);
  }
  if (configuredFull) {
    selection = { mode: "full", revision, reason: "Full execution configured" };
  } else if (selection.mode === "subset") {
    selection.audit =
      mode === "audit" ||
      parseInt(revision.slice(0, 8), 16) % 100 < auditPercent;
  }
  selection.selection_seconds = (Date.now() - started) / 1000;
  const containerAfter = containerCpuSeconds();
  selection.selection_cpu_seconds =
    containerBefore !== null && containerAfter !== null
      ? containerAfter - containerBefore
      : null;
  selection.selection_cpu_scope =
    "cgroup namespace root, including all its processes";
  fs.writeFileSync(
    "tmp/rspec-mapping/selection.json",
    JSON.stringify(selection)
  );
  core.info(JSON.stringify(selection));
  await core.summary
    .addRaw(
      `Core backend RSpec prediction: ${selection.mode}. ${selection.specs?.length ?? "All"} candidate files. Preparation took ${selection.selection_seconds.toFixed(2)} seconds.`
    )
    .write();
}

module.exports = { select, prepare };
