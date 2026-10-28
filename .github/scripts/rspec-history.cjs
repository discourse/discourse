const fs = require("node:fs");
const { execFileSync } = require("node:child_process");

module.exports = async ({ github, context, core }) => {
  fs.mkdirSync("tmp/rspec-mapping", { recursive: true });
  const history = [];
  const started = Date.now();
  try {
    const response = await github.rest.actions.listArtifactsForRepo({
      ...context.repo,
      name: "rspec-prediction-observation",
      per_page: 100,
    });
    for (const artifact of response.data.artifacts) {
      if (Date.now() - started > 20_000 || history.length >= 50) break;
      if (
        artifact.expired ||
        artifact.size_in_bytes > 5_000_000 ||
        !artifact.workflow_run
      )
        continue;
      const { data: run } = await github.rest.actions.getWorkflowRun({
        ...context.repo,
        run_id: artifact.workflow_run.id,
      });
      if (
        run.path !== ".github/workflows/tests.yml" ||
        !["success", "failure"].includes(run.conclusion) ||
        run.head_repository.id !== context.payload.repository.id
      )
        continue;
      const archive = await github.rest.actions.downloadArtifact({
        ...context.repo,
        artifact_id: artifact.id,
        archive_format: "zip",
      });
      fs.writeFileSync(
        "tmp/rspec-mapping/history.zip",
        Buffer.from(archive.data)
      );
      const bytes = execFileSync(
        "python3",
        [
          "-c",
          "import sys,zipfile; archive=zipfile.ZipFile(sys.argv[1]); entry=archive.getinfo('report.json'); assert entry.file_size <= 5000000; sys.stdout.buffer.write(archive.read(entry))",
          "tmp/rspec-mapping/history.zip",
        ],
        { maxBuffer: 5_000_000, timeout: 5_000 }
      );
      const record = JSON.parse(bytes.toString());
      record.created_at = run.created_at;
      record.revision = run.head_sha;
      history.push(record);
    }
  } catch (error) {
    core.warning(
      `Prediction history incomplete (${error.status || error.name}).`
    );
  }
  fs.writeFileSync("tmp/rspec-mapping/history.json", JSON.stringify(history));
};
