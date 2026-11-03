import assert from "node:assert/strict";
import { test } from "node:test";
import { analyze } from "../lib/analyze.mjs";
import { findings } from "../lib/render.mjs";
import { baseApp, BUDGET, makeDist } from "./helpers.mjs";

const ENTRY = "assets/js/discourse-aaaa1111.digested.js";
const SHARED = "assets/js/chunk-bbbb2222.digested.js";
const ADMIN = "assets/js/admin-cccc3333.digested.js";
const CODEMIRROR = "assets/js/codemirror-dddd4444.digested.js";

async function compare(base, head) {
  const report = await analyze({
    baseDir: makeDist(base),
    headDir: makeDist(head),
  });
  return { report, keys: findings(report, BUDGET).map((f) => f.key) };
}

function clone(value) {
  return JSON.parse(JSON.stringify(value));
}

test("identical builds have no findings", async () => {
  const { report, keys } = await compare(baseApp(), baseApp());

  assert.deepEqual(keys, []);
  assert.equal(report.initialLoad.base, report.initialLoad.head);
  assert.ok(report.bundles.every((bundle) => bundle.status === "same"));
});

test("a new lazy import is a new bundle, reported with its importer", async () => {
  const head = baseApp();
  head.chunks[ADMIN].dynamicImports.push(
    "assets/js/rrule-eeee5555.digested.js"
  );
  head.chunks[ADMIN].examples["dynamic:assets/js/rrule-eeee5555.digested.js"] =
    [{ from: "admin/components/a.gjs", to: "rrule@2.8.1/dist/esm/index.js" }];
  head.chunks["assets/js/rrule-eeee5555.digested.js"] = {
    kind: "lazy",
    facade: "rrule@2.8.1/dist/esm/index.js",
    modules: { "rrule@2.8.1/dist/esm/index.js": 8000 },
  };

  const { report, keys } = await compare(baseApp(), head);
  const rrule = report.bundles.find(
    (bundle) => bundle.key === "lazy:rrule/dist/esm/index.js"
  );

  assert.deepEqual(keys, ["new:lazy:rrule/dist/esm/index.js"]);
  assert.equal(rrule.name, "rrule");
  assert.deepEqual(rrule.importedBy, [
    {
      from: "lazy:admin/compat-modules.js",
      fromName: "admin",
      kind: "dynamic",
      examples: [
        { from: "admin/components/a.gjs", to: "rrule@2.8.1/dist/esm/index.js" },
      ],
    },
  ]);
  assert.deepEqual(report.edges.added, []);
});

test("a lazy bundle merged into the initial load is reported with its static importer", async () => {
  const head = baseApp();
  Object.assign(head.chunks[ENTRY].modules, head.chunks[CODEMIRROR].modules);
  delete head.chunks[CODEMIRROR];
  head.chunks[ADMIN].dynamicImports = [];
  head.importers["app/static/codemirror.js"] = ["app/app.js"];

  const { report, keys } = await compare(baseApp(), head);
  const [moved] = report.movedIntoInitialLoad;

  assert.deepEqual(keys, ["moved:lazy:app/static/codemirror.js", "initial"]);
  assert.equal(moved.name, "codemirror");
  assert.equal(moved.bytes, 25000);
  assert.deepEqual(moved.importers, [
    { from: "app/app.js", to: "app/static/codemirror.js" },
  ]);
  const bundle = report.bundles.find(
    (b) => b.key === "lazy:app/static/codemirror.js"
  );
  assert.equal(bundle.status, "removed");
  assert.equal(bundle.movedToInitialLoad, true);
});

test("splitting a shared chunk differently has no findings", async () => {
  const base = baseApp();
  base.chunks[SHARED].modules["lodash@4.17.21/lodash.js"] = 15000;
  const head = clone(base);
  delete head.chunks[SHARED];
  head.chunks["assets/js/chunk-ffff6666.digested.js"] = {
    kind: "shared",
    modules: { "moment@2.30.1/moment.js": 20000 },
  };
  head.chunks["assets/js/chunk-gggg7777.digested.js"] = {
    kind: "shared",
    modules: { "lodash@4.17.21/lodash.js": 15000 },
  };
  const shared = [
    "assets/js/chunk-ffff6666.digested.js",
    "assets/js/chunk-gggg7777.digested.js",
  ];
  head.chunks[ENTRY].imports = shared;
  head.chunks[ADMIN].imports = shared;

  const { keys } = await compare(base, head);

  assert.deepEqual(keys, []);
});

test("a version bump that only changes paths keeps the bundle", async () => {
  const withDiff = (version) => {
    const app = baseApp();
    const file = `assets/js/diff-${version.replaceAll(".", "")}zz.digested.js`;
    app.chunks[ENTRY].dynamicImports.push(file);
    app.chunks[file] = {
      kind: "lazy",
      facade: `diff@${version}/libesm/index.js`,
      modules: { [`diff@${version}/libesm/index.js`]: 7000 },
    };
    return app;
  };

  const { report, keys } = await compare(withDiff("9.0.0"), withDiff("9.1.0"));
  const diff = report.bundles.find(
    (bundle) => bundle.key === "lazy:diff/libesm/index.js"
  );

  assert.deepEqual(keys, []);
  assert.equal(diff.status, "same");
});

test("a new import between existing bundles is a new connection", async () => {
  const head = baseApp();
  head.chunks[ENTRY].dynamicImports.push(CODEMIRROR);
  head.chunks[ENTRY].examples[`dynamic:${CODEMIRROR}`] = [
    { from: "app/lib/editor.js", to: "app/static/codemirror.js" },
  ];

  const { report, keys } = await compare(baseApp(), head);

  assert.deepEqual(keys, [
    "edge:entry:discourse:lazy:app/static/codemirror.js:dynamic",
  ]);
  assert.deepEqual(report.edges.added[0].examples, [
    { from: "app/lib/editor.js", to: "app/static/codemirror.js" },
  ]);
});

test("imports inside the initial load are not attributed to lazy bundles", async () => {
  const head = baseApp();
  head.chunks[SHARED].dynamicImports = [CODEMIRROR];

  const { report } = await compare(baseApp(), head);

  assert.deepEqual(
    report.edges.added.map((edge) => edge.from),
    ["entry:discourse"]
  );
});

test("growth over the threshold names the largest additions", async () => {
  const head = baseApp();
  head.chunks[ADMIN].modules["admin/components/b.gjs"] = 5000;

  const { report, keys } = await compare(baseApp(), head);
  const admin = report.bundles.find(
    (bundle) => bundle.key === "lazy:admin/compat-modules.js"
  );

  assert.deepEqual(keys, ["grew:lazy:admin/compat-modules.js"]);
  assert.deepEqual(admin.topModules, [
    { id: "admin/components/b.gjs", delta: 5000, added: true },
  ]);
});

test("duplicate package versions are listed", async () => {
  const head = baseApp();
  head.chunks[ADMIN].modules["moment@2.29.0/moment.js"] = 3000;

  const { report } = await compare(baseApp(), head);

  assert.deepEqual(report.duplicatePackages, [
    { name: "moment", versions: ["2.29.0", "2.30.1"], new: true },
  ]);
});

test("core importing admin code names the import that pulled it in", async () => {
  const base = baseApp();
  base.chunks[ADMIN].modules["admin/components/big.gjs"] = 20000;
  base.importers["admin/components/big.gjs"] = ["admin/components/a.gjs"];
  const head = clone(base);
  delete head.chunks[ADMIN].modules["admin/components/big.gjs"];
  head.chunks[ENTRY].modules["admin/components/big.gjs"] = 20000;
  head.importers["admin/components/big.gjs"] = [
    "admin/components/a.gjs",
    "app/app.js",
  ];

  const { report, keys } = await compare(base, head);
  const [moved] = report.movedIntoInitialLoad;

  assert.deepEqual(keys, ["moved:lazy:admin/compat-modules.js", "initial"]);
  assert.equal(moved.name, "admin");
  assert.deepEqual(moved.importers, [
    { from: "app/app.js", to: "admin/components/big.gjs" },
  ]);
  assert.deepEqual(report.initialLoad.topModules[0], {
    id: "admin/components/big.gjs",
    delta: 20000,
    added: false,
  });
});

test("code moved into the initial load is found across a version bump", async () => {
  const head = baseApp();
  delete head.chunks[CODEMIRROR];
  head.chunks[ADMIN].dynamicImports = [];
  head.chunks[ENTRY].modules["app/static/codemirror.js"] = 5000;
  head.chunks[ENTRY].modules["@codemirror/view@6.2.0/dist/index.js"] = 20000;
  head.importers["app/static/codemirror.js"] = ["app/app.js"];

  const { report } = await compare(baseApp(), head);

  assert.equal(report.movedIntoInitialLoad[0].bytes, 25000);
});

test("a lazy chunk without a facade is treated as shared", async () => {
  const head = baseApp();
  head.chunks[CODEMIRROR].facade = null;

  const { report } = await compare(baseApp(), head);

  assert.ok(report.bundles.every((bundle) => bundle.facade !== null));
});
