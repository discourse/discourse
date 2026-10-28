const assert = require("node:assert/strict");
const test = require("node:test");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const { execFileSync } = require("node:child_process");
const { select, prepare } = require("./select-rspec.cjs");

const revision = "b".repeat(40);
const inventory = [
  "spec/lib/url_helper_spec.rb",
  "spec/lib/slug_spec.rb",
  "spec/models/topic_spec.rb",
  "spec/models/post_spec.rb",
];
const mapping = {
  version: 1,
  shared_globs: [
    "frontend/pretty-text/addon/**/*.js",
    "frontend/asset-processor/**/*.{js,mjs}",
    "frontend/discourse/app/lib/escape.js",
  ],
  revision: "a".repeat(40),
  dependencies: {
    "spec/lib/url_helper_spec.rb": ["lib/url_helper.rb"],
    "spec/lib/slug_spec.rb": ["lib/slug.rb"],
    "spec/models/topic_spec.rb": ["lib/url_helper.rb", "app/models/topic.rb"],
    "spec/models/post_spec.rb": ["app/models/post.rb"],
  },
};

test("selects consumers of a shared helper and changed specs", () => {
  const result = select({
    mapping,
    revision,
    inventory,
    changed: ["lib/url_helper.rb", "spec/lib/slug_spec.rb"],
  });

  assert.equal(result.mode, "subset");
  assert.deepEqual(result.specs, inventory.slice(0, 3));
});

test("includes specs absent from an older mapping", () => {
  const newSpec = "spec/lib/topic_formatter_spec.rb";

  const result = select({
    mapping,
    revision,
    inventory: [...inventory, newSpec],
    changed: [],
  });

  assert.deepEqual(result.specs, [newSpec]);
});

test("broadens an unmapped Ruby file to its subsystem", () => {
  const result = select({
    mapping,
    revision,
    inventory,
    changed: ["app/models/topic_formatter.rb"],
  });

  assert.equal(result.mode, "subset");
  assert.deepEqual(result.specs, inventory.slice(2));
});

test("retains consumers of deleted or renamed source paths", () => {
  const result = select({
    mapping,
    revision,
    inventory,
    changed: ["lib/url_helper.rb", "lib/renamed_helper.rb"],
  });

  assert.deepEqual(result.specs, inventory.slice(0, 3));
});

test("runs the full backend for shared setup or unbounded changes", () => {
  for (const path of [
    "spec/rails_helper.rb",
    "spec/fabricators/topic.rb",
    "Gemfile.lock",
    "config/site_settings.yml",
    "app/unknown/new.rb",
    "spec/fixtures/images/logo.png",
    "themes/foundation/about.json",
    "frontend/pretty-text/addon/engines/discourse-markdown-it.js",
    "frontend/asset-processor/build.mjs",
    "frontend/discourse/app/lib/escape.js",
  ]) {
    assert.equal(
      select({ mapping, revision, inventory, changed: [path] }).mode,
      "full"
    );
  }
});

test("allows an empty selection for changes handled by other jobs", () => {
  const result = select({
    mapping,
    revision,
    inventory,
    changed: ["frontend/discourse/app/example.gjs"],
  });

  assert.equal(result.mode, "subset");
  assert.deepEqual(result.specs, []);
});

test("rejects malformed mapping dependencies", () => {
  const result = select({
    mapping: { ...mapping, dependencies: { "spec/example_spec.rb": null } },
    revision,
    inventory,
    changed: [],
  });

  assert.equal(result.mode, "full");
});

test("restores a trusted mapping and includes changes since its commit", async () => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), "rspec-selection-"));
  const previous = process.cwd();
  const runGit = (...args) =>
    execFileSync("git", args, { cwd: directory, encoding: "utf8" }).trim();
  try {
    process.chdir(directory);
    runGit("init", "--quiet");
    for (const file of [
      ...inventory,
      "lib/url_helper.rb",
      "app/models/post.rb",
    ]) {
      fs.mkdirSync(path.dirname(file), { recursive: true });
      fs.writeFileSync(file, "original\n");
    }
    runGit("add", ".");
    runGit(
      "-c",
      "user.name=CI",
      "-c",
      "user.email=ci@ci.invalid",
      "-c",
      "commit.gpgsign=false",
      "-c",
      "core.hooksPath=/dev/null",
      "commit",
      "--quiet",
      "-m",
      "mapping baseline"
    );
    const baseline = runGit("rev-parse", "HEAD");
    fs.writeFileSync("app/models/post.rb", "main changed this after mapping\n");
    fs.writeFileSync("spec/lib/slug_spec.rb", "main changed this spec\n");
    runGit("add", ".");
    runGit(
      "-c",
      "user.name=CI",
      "-c",
      "user.email=ci@ci.invalid",
      "-c",
      "commit.gpgsign=false",
      "-c",
      "core.hooksPath=/dev/null",
      "commit",
      "--quiet",
      "-m",
      "main update"
    );
    const prBase = runGit("rev-parse", "HEAD");
    fs.writeFileSync("lib/url_helper.rb", "PR changed this\n");
    fs.writeFileSync("spec/lib/slug_spec.rb", "original\n");
    runGit("add", ".");
    runGit(
      "-c",
      "user.name=CI",
      "-c",
      "user.email=ci@ci.invalid",
      "-c",
      "commit.gpgsign=false",
      "-c",
      "core.hooksPath=/dev/null",
      "commit",
      "--quiet",
      "-m",
      "PR update"
    );
    const head = runGit("rev-parse", "HEAD");
    runGit("remote", "add", "origin", directory);
    const archive = execFileSync(
      "python3",
      [
        "-c",
        "import io,json,sys,zipfile; b=io.BytesIO(); z=zipfile.ZipFile(b,'w'); z.writestr('mapping.json',sys.stdin.read()); z.close(); sys.stdout.buffer.write(b.getvalue())",
      ],
      {
        input: JSON.stringify({ ...mapping, revision: baseline }),
      }
    );
    const context = {
      repo: { owner: "example", repo: "discourse" },
      sha: head,
      eventName: "pull_request",
      payload: {
        repository: { id: 1 },
        pull_request: { base: { ref: "main", sha: prBase } },
      },
    };
    const core = {
      info() {},
      warning() {},
      summary: {
        addRaw() {
          return this;
        },
        async write() {},
      },
    };
    const producer = {
      path: ".github/workflows/tests.yml",
      event: "push",
      id: 20,
      head_branch: "main",
      conclusion: "failure",
      repository: { id: 1 },
      head_repository: { id: 1 },
      head_sha: baseline,
    };
    let coreConclusion = "success";
    const github = {
      rest: {
        actions: {
          async listArtifactsForRepo() {
            return {
              data: {
                artifacts: [
                  {
                    id: 10,
                    size_in_bytes: archive.length,
                    workflow_run: { id: 20 },
                  },
                ],
              },
            };
          },
          async getWorkflowRun() {
            return { data: producer };
          },
          async listJobsForWorkflowRun() {
            return {
              data: {
                jobs: [{ name: "core backend", conclusion: coreConclusion }],
              },
            };
          },
          async downloadArtifact() {
            return { data: archive };
          },
        },
      },
    };

    await prepare({ github, context, core });

    const result = JSON.parse(
      fs.readFileSync("tmp/rspec-mapping/selection.json")
    );
    assert.equal(result.mode, "subset");
    assert.deepEqual(result.specs.toSorted(), inventory.toSorted());
    assert.equal(result.mapping_revision, baseline);

    producer.event = "pull_request";

    await prepare({ github, context, core });

    assert.equal(
      JSON.parse(fs.readFileSync("tmp/rspec-mapping/selection.json")).mode,
      "full"
    );

    producer.event = "push";
    coreConclusion = "failure";

    await prepare({ github, context, core });

    assert.equal(
      JSON.parse(fs.readFileSync("tmp/rspec-mapping/selection.json")).mode,
      "full"
    );
  } finally {
    process.chdir(previous);
    fs.rmSync(directory, { recursive: true, force: true });
  }
});

test("main configuration changes since mapping do not force full PR runs", () => {
  const result = select({
    mapping,
    revision,
    inventory,
    changed: ["config/site_settings.yml", "lib/url_helper.rb"],
    prChanged: ["lib/url_helper.rb"],
  });

  assert.equal(result.mode, "subset");
  assert.deepEqual(result.specs, [inventory[0], inventory[2]]);
});

test("retains backend integrity checks for frontend changes", () => {
  const integrity = "spec/integrity/js_constants_spec.rb";
  const result = select({
    mapping: {
      ...mapping,
      dependencies: { ...mapping.dependencies, [integrity]: [] },
    },
    revision,
    inventory: [...inventory, integrity],
    changed: ["frontend/discourse/app/lib/constants.js"],
  });

  assert.equal(result.mode, "subset");
  assert.deepEqual(result.specs, [integrity]);
});
