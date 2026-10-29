const assert = require("node:assert/strict");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const { execFileSync } = require("node:child_process");
const { test, beforeEach, afterEach } = require("node:test");
const restore = require("./rspec-mapping.cjs");

let directory;
let originalDirectory;
let outputs;
let context;
let run;
let downloads;

beforeEach(() => {
  originalDirectory = process.cwd();
  directory = fs.mkdtempSync(path.join(os.tmpdir(), "rspec-artifact-"));
  process.chdir(directory);
  outputs = {};
  downloads = 0;
  context = {
    repo: { owner: "discourse", repo: "discourse" },
    ref: "refs/heads/main",
    eventName: "push",
    payload: { repository: { id: 1 } },
  };
  run = {
    path: ".github/workflows/rspec-mapping.yml",
    conclusion: "success",
    event: "schedule",
    head_branch: "main",
    head_repository: { id: 1 },
    pull_requests: [],
  };
});

afterEach(() => {
  process.chdir(originalDirectory);
  fs.rmSync(directory, { recursive: true, force: true });
});

const execute = async (artifacts) => {
  const actions = {
    listArtifactsForRepo: async () => ({ data: { artifacts } }),
    getWorkflowRun: async () => ({ data: run }),
    downloadArtifact: async () => {
      downloads++;
      const data = execFileSync("python3", [
        "-c",
        "import io,zipfile,sys; stream=io.BytesIO(); archive=zipfile.ZipFile(stream,'w'); archive.writestr('mapping.json','{\"version\":1}'); archive.close(); sys.stdout.buffer.write(stream.getvalue())",
      ]);
      return { data };
    },
  };
  await restore({
    github: { rest: { actions } },
    context,
    core: {
      setOutput: (key, value) => (outputs[key] = value),
      warning: () => {},
    },
  });
};

const artifact = () => ({
  id: 9,
  expired: false,
  size_in_bytes: 100,
  workflow_run: { id: 10 },
  created_at: new Date(Date.now() - 120_000).toISOString(),
});

test("a missing baseline does not collect on ordinary pushes", async () => {
  await execute([]);
  assert.equal(outputs.collect, "0");
  assert.equal(outputs["artifact-name"], "rspec-mapping-core-main");
});

test("restores an older successful branch artifact without exact SHA matching", async () => {
  await execute([artifact()]);
  assert.equal(downloads, 1);
  assert.deepEqual(
    JSON.parse(fs.readFileSync("tmp/rspec-mapping/baseline.json")),
    { version: 1 }
  );
  assert.equal(outputs.collect, "0");
});

test("does not trust another repository or failed workflow", async () => {
  run.head_repository.id = 2;
  await execute([artifact()]);
  assert.equal(downloads, 0);
  run.head_repository.id = 1;
  run.conclusion = "failure";
  await execute([artifact()]);
  assert.equal(downloads, 0);
});

test("branch strategy never consumes PR artifacts", async () => {
  run.event = "pull_request";
  await execute([artifact()]);
  assert.equal(downloads, 0);
});

test("a download failure leaves full observation available", async () => {
  await restore({
    github: {
      rest: {
        actions: {
          listArtifactsForRepo: async () => {
            throw new Error("offline");
          },
        },
      },
    },
    context,
    core: {
      setOutput: (key, value) => (outputs[key] = value),
      warning: () => {},
    },
  });
  assert.equal(outputs.collect, "0");
  assert.equal(fs.existsSync("tmp/rspec-mapping/baseline.json"), false);
});

test("explicit collection runs without an existing artifact", async () => {
  process.env.COLLECT_RSPEC_MAPPING = "1";
  try {
    await execute([]);
    assert.equal(outputs.collect, "1");
  } finally {
    delete process.env.COLLECT_RSPEC_MAPPING;
  }
});
