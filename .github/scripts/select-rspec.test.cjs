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
  version: 4,
  grouping_runtime_log: null,
  worker_specs: inventory.map((spec) => [spec]),
  empty_specs: [],
  shared_files: [],
  source_checks: Object.fromEntries(
    [
      "lib/url_helper.rb",
      "lib/slug.rb",
      "app/models/topic.rb",
      "app/models/post.rb",
    ].map((file) => [file, { digest: "d".repeat(64), immutable_methods: [] }])
  ),
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

test("runs full for an unmapped Ruby file", () => {
  const result = select({
    mapping,
    revision,
    inventory,
    changed: ["app/models/topic_formatter.rb"],
  });

  assert.equal(result.mode, "full");
});

test("runs full when a renamed source introduces an unmapped path", () => {
  const result = select({
    mapping,
    revision,
    inventory,
    changed: ["lib/url_helper.rb", "lib/renamed_helper.rb"],
  });

  assert.equal(result.mode, "full");
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
    const groupingHistory = "spec/lib/url_helper_spec.rb:10\n";
    const archive = execFileSync(
      "python3",
      [
        "-c",
        "import io,json,sys,zipfile; b=io.BytesIO(); z=zipfile.ZipFile(b,'w'); z.writestr('mapping.json',sys.stdin.read()); z.close(); sys.stdout.buffer.write(b.getvalue())",
      ],
      {
        input: JSON.stringify({
          ...mapping,
          revision: baseline,
          grouping_runtime_log: groupingHistory,
        }),
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

    fs.mkdirSync("tmp", { recursive: true });
    fs.writeFileSync("tmp/turbo_rspec_runtime.log", "newer cache data\n");
    await prepare({ github, context, core });
    assert.equal(
      fs.readFileSync("tmp/turbo_rspec_runtime.log", "utf8"),
      groupingHistory
    );

    const result = JSON.parse(
      fs.readFileSync("tmp/rspec-mapping/selection.json")
    );
    assert.equal(result.mode, "subset");
    assert.deepEqual(result.specs.toSorted(), inventory.toSorted());
    assert.equal(result.mapping_revision, baseline);

    const originalList = github.rest.actions.listArtifactsForRepo;
    const originalDownload = github.rest.actions.downloadArtifact;
    const originalRun = github.rest.actions.getWorkflowRun;
    github.rest.actions.listArtifactsForRepo = async () => ({
      data: {
        artifacts: [
          { id: 11, size_in_bytes: 10, workflow_run: { id: 21 } },
          { id: 10, size_in_bytes: archive.length, workflow_run: { id: 20 } },
        ],
      },
    });
    github.rest.actions.getWorkflowRun = async ({ run_id }) => ({
      data: {
        ...producer,
        id: run_id,
        head_sha: run_id === 21 ? head : baseline,
      },
    });
    github.rest.actions.downloadArtifact = async ({ artifact_id }) =>
      artifact_id === 11
        ? { data: Buffer.from("invalid zip") }
        : { data: archive };
    await prepare({ github, context, core });
    assert.equal(
      JSON.parse(fs.readFileSync("tmp/rspec-mapping/selection.json"))
        .mapping_revision,
      baseline
    );
    assert.equal(
      JSON.parse(fs.readFileSync("tmp/rspec-mapping/selection.json")).mode,
      "subset"
    );
    github.rest.actions.listArtifactsForRepo = originalList;
    github.rest.actions.downloadArtifact = originalDownload;
    github.rest.actions.getWorkflowRun = originalRun;

    await prepare({ github, context, core, auditPercent: 100 });
    assert.equal(
      JSON.parse(fs.readFileSync("tmp/rspec-mapping/selection.json")).audit,
      true
    );
    await prepare({ github, context, core, mode: "audit", auditPercent: 0 });
    assert.equal(
      JSON.parse(fs.readFileSync("tmp/rspec-mapping/selection.json")).audit,
      true
    );
    github.rest.actions.listArtifactsForRepo = async () => {
      throw new Error("Full mode must not request mappings");
    };
    await prepare({ github, context, core, mode: "full" });
    assert.equal(
      JSON.parse(fs.readFileSync("tmp/rspec-mapping/selection.json")).reason,
      "Full execution configured"
    );
    for (const invalid of [101, " ", "1e2"]) {
      await prepare({ github, context, core, auditPercent: invalid });
      assert.equal(
        JSON.parse(fs.readFileSync("tmp/rspec-mapping/selection.json")).reason,
        "Full execution configured"
      );
    }
    github.rest.actions.listArtifactsForRepo = originalList;

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

test("unsafe configuration drift runs the full suite", () => {
  const result = select({
    mapping,
    revision,
    inventory,
    changed: ["config/site_settings.yml", "lib/url_helper.rb"],
  });

  assert.equal(result.mode, "full");
});

test("retains backend integrity checks for frontend changes", () => {
  const integrity = "spec/integrity/js_constants_spec.rb";
  const result = select({
    mapping: {
      ...mapping,
      dependencies: { ...mapping.dependencies, [integrity]: [] },
      worker_specs: [...mapping.worker_specs, [integrity]],
    },
    revision,
    inventory: [...inventory, integrity],
    changed: ["frontend/discourse/app/lib/constants.js"],
  });

  assert.equal(result.mode, "subset");
  assert.deepEqual(result.specs, [integrity]);
});

test("runs full for data files under frontend paths", () => {
  for (const file of [
    "frontend/rspec-lab/value.json",
    "frontend/discourse/app/value.json",
    "frontend/discourse/app/value.txt",
  ]) {
    assert.equal(
      select({ mapping, revision, inventory, changed: [file] }).mode,
      "full"
    );
  }
});

test("a deleted mapped Ruby file requires a full run", () => {
  const result = select({
    mapping,
    revision,
    inventory,
    changed: ["lib/url_helper.rb"],
    structural: ["lib/url_helper.rb"],
  });
  assert.equal(result.mode, "full");
});

test("runs full for observed file inputs, including cached reads", () => {
  assert.equal(
    select({
      mapping: { ...mapping, shared_files: ["frontend/discourse/app/data.js"] },
      revision,
      inventory,
      changed: ["frontend/discourse/app/data.js"],
    }).mode,
    "full"
  );
});

test("new frontend files require a full run", () => {
  const path = "frontend/discourse/app/new-module.js";
  assert.equal(
    select({
      mapping,
      revision,
      inventory,
      changed: [path],
      structural: [path],
    }).mode,
    "full"
  );
});

test("selects locale integrity through its mapped dependencies", () => {
  const localeSpec = "spec/integrity/i18n_spec.rb";
  const fixture = {
    ...mapping,
    worker_specs: [...mapping.worker_specs, [localeSpec]],
    dependencies: { ...mapping.dependencies, [localeSpec]: ["lib/slug.rb"] },
  };
  const files = [...inventory, localeSpec];
  assert.deepEqual(
    select({
      mapping: fixture,
      revision,
      inventory: files,
      changed: ["README.md"],
    }).specs,
    []
  );
  assert.deepEqual(
    select({
      mapping: fixture,
      revision,
      inventory: files,
      changed: ["lib/slug.rb"],
    }).specs,
    [inventory[1], localeSpec]
  );
});

test("includes complete historical worker cohorts regardless of execution order", () => {
  const fixture = {
    ...mapping,
    worker_specs: [
      [inventory[3], inventory[1], inventory[0], inventory[3]],
      [inventory[2]],
    ],
  };
  const result = select({
    mapping: fixture,
    revision,
    inventory,
    changed: ["lib/url_helper.rb"],
  });
  assert.equal(result.mode, "subset");
  assert.deepEqual(result.specs, inventory);
  assert.deepEqual(result.cohort_specs, inventory);
});

test("rejects mappings without complete worker cohorts", () => {
  for (const fixture of [
    { ...mapping, version: 2 },
    { ...mapping, worker_specs: [] },
    { ...mapping, worker_specs: null },
  ]) {
    assert.equal(
      select({
        mapping: fixture,
        revision,
        inventory,
        changed: ["lib/url_helper.rb"],
      }).mode,
      "full"
    );
  }
});

test("new and existing locale files require a full run", () => {
  for (const path of [
    "config/locales/server.en.yml",
    "plugins/chat/config/locales/server.zz.yml",
    "docs/locales/new.en.yml",
  ]) {
    for (const structural of [[], [path]]) {
      assert.equal(
        select({ mapping, revision, inventory, changed: [path], structural })
          .mode,
        "full"
      );
    }
  }
});

test("new and changed specs seed cohorts while known empty specs stay required", () => {
  const empty = "spec/lib/empty_spec.rb";
  const added = "spec/lib/new_spec.rb";
  const fixture = { ...mapping, empty_specs: [empty] };
  const result = select({
    mapping: fixture,
    revision,
    inventory: [...inventory, empty, added],
    changed: [inventory[1]],
  });
  assert.deepEqual(result.cohort_specs, [inventory[1], added]);
  assert.deepEqual(result.specs, [inventory[1], empty, added]);
});

test("a deleted setup file still selects the multisite process", () => {
  const empty = "spec/lib/setup_spec.rb";
  const fixture = {
    ...mapping,
    empty_specs: [empty],
    worker_specs: [...mapping.worker_specs, [empty]],
  };
  const result = select({
    mapping: fixture,
    revision,
    inventory,
    changed: [empty],
  });
  assert.deepEqual(result.specs, []);
  assert.deepEqual(result.cohort_specs, []);
  assert.equal(result.full_multisite, true);
});

test("delegates system spec changes without expanding backend multisite", () => {
  for (const changed of [
    ["spec/system/example_spec.rb"],
    ["frontend/discourse/app/example.gjs", "spec/system/example_spec.rb"],
  ]) {
    const result = select({ mapping, revision, inventory, changed });
    assert.equal(result.mode, "subset");
    assert.deepEqual(result.specs, []);
    assert.deepEqual(result.cohort_specs, []);
    assert.equal(result.full_multisite, false);
  }
});
