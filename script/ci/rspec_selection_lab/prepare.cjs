const fs = require("node:fs");
const path = require("node:path");
const { prepare } = require(path.resolve(".github/scripts/select-rspec.cjs"));

const input = JSON.parse(fs.readFileSync(process.argv[2], "utf8"));
const calls = [];
const repository = { id: 1 };
const actions = {
  async listArtifactsForRepo() {
    calls.push("listArtifactsForRepo");
    return {
      data: {
        artifacts: input.missing
          ? []
          : [
              {
                id: 1,
                expired: false,
                size_in_bytes: fs.statSync(input.archive).size,
                workflow_run: { id: 1 },
                ...input.artifact,
              },
            ],
      },
    };
  },
  async getWorkflowRun() {
    calls.push("getWorkflowRun");
    return {
      data: {
        id: 1,
        event: "push",
        path: ".github/workflows/tests.yml",
        head_branch: "main",
        head_sha: input.mapping_revision,
        repository,
        head_repository: repository,
        ...input.run,
      },
    };
  },
  async listJobsForWorkflowRun() {
    calls.push("listJobsForWorkflowRun");
    return {
      data: {
        jobs: [
          {
            name: "core backend",
            conclusion: input.producer_conclusion || "success",
          },
        ],
      },
    };
  },
  async downloadArtifact() {
    calls.push("downloadArtifact");
    if (input.download_error) {
      throw new Error("Simulated artifact download failure");
    }
    return { data: fs.readFileSync(input.archive) };
  },
};

prepare({
  auditPercent: input.audit_percent ?? 0,
  mode: input.mode || "select",
  github: { rest: { actions } },
  context: {
    sha: input.revision,
    eventName: "pull_request",
    repo: { owner: "local", repo: "discourse" },
    payload: {
      repository,
      pull_request: { base: { ref: "main", sha: input.base_revision } },
    },
  },
  core: {
    info: console.log,
    warning: console.error,
    summary: {
      addRaw() {
        return this;
      },
      async write() {},
    },
  },
})
  .then(() => fs.writeFileSync(input.calls, JSON.stringify(calls)))
  .catch((error) => {
    console.error(error);
    process.exitCode = 1;
  });
