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

function select({
  mapping,
  revision,
  inventory,
  changed,
  prChanged = changed,
}) {
  const full = (reason) => ({ mode: "full", revision, reason });
  if (
    mapping.version !== 1 ||
    !Array.isArray(mapping.shared_globs) ||
    !mapping.shared_globs.every((pattern) => typeof pattern === "string") ||
    !/^[a-f0-9]{40}$/.test(mapping.revision) ||
    !mapping.dependencies ||
    typeof mapping.dependencies !== "object" ||
    Array.isArray(mapping.dependencies)
  ) {
    return full("Invalid mapping");
  }

  const selected = new Set(
    inventory.filter((spec) => spec.startsWith("spec/integrity/"))
  );
  const changedPaths = new Set(changed);
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
    }
  }

  for (const spec of inventory) {
    if (!Object.hasOwn(mapping.dependencies, spec) || changedPaths.has(spec)) {
      selected.add(spec);
    }
  }

  for (const path of prChanged) {
    if (mapping.shared_globs.some((pattern) => matchesGlob(path, pattern))) {
      return full(`Shared bundle input: ${path}`);
    }
    if (/^spec\/(?!system\/).*_spec\.rb$/.test(path)) {
      continue;
    }
    if (/^(app|lib)\/.*\.rb$/.test(path)) {
      if (!sources.has(path)) {
        const directory = path.startsWith("lib/") ? "lib" : path.split("/")[1];
        const related = inventory.filter((spec) =>
          spec.startsWith(`spec/${directory}/`)
        );
        if (related.length === 0) {
          return full(`No subsystem rule for ${path}`);
        }
        related.forEach((spec) => selected.add(spec));
      }
      continue;
    }
    if (
      /^(frontend\/|docs\/|plugins\/|spec\/system\/)/.test(path) ||
      /^[^/]+\.md$/.test(path)
    ) {
      continue;
    }
    return full(`Shared or untraceable file: ${path}`);
  }

  return {
    mode: "subset",
    revision,
    mapping_revision: mapping.revision,
    specs: inventory.filter((spec) => selected.has(spec)),
  };
}

async function prepare({ github, context, core }) {
  const started = Date.now();
  const revision = context.sha;
  let selection = { mode: "full", revision, reason: "Not a PR targeting main" };
  fs.mkdirSync("tmp/rspec-mapping", { recursive: true });
  try {
    if (
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
        const { data: jobs } = await github.rest.actions.listJobsForWorkflowRun(
          {
            ...context.repo,
            run_id: run.id,
            per_page: 100,
          }
        );
        if (
          !jobs.jobs.some(
            (job) => job.name === "core backend" && job.conclusion === "success"
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
          .filter((path) => /^spec\/(?!system\/).*_spec\.rb$/.test(path));
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
          prChanged,
        });
        break;
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
  selection.selection_seconds = (Date.now() - started) / 1000;
  fs.writeFileSync(
    "tmp/rspec-mapping/selection.json",
    JSON.stringify(selection)
  );
  core.info(JSON.stringify(selection));
  await core.summary
    .addRaw(
      `Core backend RSpec: ${selection.mode}. ${selection.specs?.length ?? "All"} spec files. Selection took ${selection.selection_seconds.toFixed(2)} seconds.`
    )
    .write();
}

module.exports = { select, prepare };
