const fs = require("node:fs");
const { execFileSync } = require("node:child_process");

module.exports = async ({ github, context, core }) => {
  const pullRequest = context.payload.pull_request;
  const branch =
    pullRequest?.base.ref || context.ref.replace("refs/heads/", "");
  const scope = branch.replace(/[^a-zA-Z0-9_-]/g, "-");
  const name = `rspec-mapping-core-${scope}`;
  fs.mkdirSync("tmp/rspec-mapping", { recursive: true });
  try {
    const response = await github.rest.actions.listArtifactsForRepo({
      ...context.repo,
      name,
      per_page: 20,
    });
    for (const artifact of response.data.artifacts) {
      if (
        artifact.expired ||
        artifact.size_in_bytes > 50_000_000 ||
        !artifact.workflow_run
      ) {
        continue;
      }
      const { data: run } = await github.rest.actions.getWorkflowRun({
        ...context.repo,
        run_id: artifact.workflow_run.id,
      });
      const trusted =
        run.path === ".github/workflows/rspec-mapping.yml" &&
        run.conclusion === "success" &&
        ["schedule", "workflow_dispatch"].includes(run.event) &&
        run.head_branch === branch &&
        run.head_repository.id === context.payload.repository.id;
      if (!trusted) {
        continue;
      }
      const archive = await github.rest.actions.downloadArtifact({
        ...context.repo,
        artifact_id: artifact.id,
        archive_format: "zip",
      });
      fs.writeFileSync(
        "tmp/rspec-mapping/baseline.zip",
        Buffer.from(archive.data)
      );
      const mapping = execFileSync(
        "python3",
        [
          "-c",
          "import sys,zipfile; archive=zipfile.ZipFile(sys.argv[1]); entry=archive.getinfo('mapping.json'); assert entry.file_size <= 50000000; sys.stdout.buffer.write(archive.read(entry))",
          "tmp/rspec-mapping/baseline.zip",
        ],
        { maxBuffer: 50_000_000, timeout: 30_000 }
      );
      JSON.parse(mapping.toString());
      fs.writeFileSync("tmp/rspec-mapping/baseline.json", mapping);
      break;
    }
  } catch (error) {
    core.warning(
      `RSpec mapping unavailable (${error.status || error.name}). Full observation remains enabled.`
    );
  }
  core.setOutput(
    "collect",
    process.env.COLLECT_RSPEC_MAPPING === "1" ? "1" : "0"
  );
  core.setOutput("artifact-name", name);
};
