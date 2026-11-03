import assert from "node:assert/strict";
import { test } from "node:test";
import { analyze } from "../lib/analyze.mjs";
import { findings, renderSummary } from "../lib/render.mjs";
import { baseApp, BUDGET, makeDist } from "./helpers.mjs";

const ENTRY = "assets/js/discourse-aaaa1111.digested.js";
const SHARED = "assets/js/chunk-bbbb2222.digested.js";
const ADMIN = "assets/js/admin-cccc3333.digested.js";
const CODEMIRROR = "assets/js/codemirror-dddd4444.digested.js";
const RRULE = "assets/js/rrule-eeee5555.digested.js";
const MARKDOWN = "assets/js/chunk-hhhh8888.digested.js";

function compare(base, head) {
  const report = analyze({ baseDir: makeDist(base), headDir: makeDist(head) });
  return { report, keys: findings(report, BUDGET).map((f) => f.key) };
}

function bundle(report, key) {
  return report.bundles.find((b) => b.key === key);
}

test("a new lazy import is a new bundle, reported with its importer", () => {
  const head = baseApp();
  const example = {
    from: "admin/components/a.gjs",
    to: "rrule@2.8.1/dist/esm/index.js",
  };
  head.chunks[ADMIN].dynamicImports.push(RRULE);
  head.chunks[ADMIN].examples.dynamic[RRULE] = example;
  head.chunks[RRULE] = {
    facade: "rrule@2.8.1/dist/esm/index.js",
    modules: { "rrule@2.8.1/dist/esm/index.js": 8000 },
  };

  const { report, keys } = compare(baseApp(), head);
  const rrule = bundle(report, "lazy:rrule/dist/esm/index.js");

  assert.deepEqual(keys, ["new:lazy:rrule/dist/esm/index.js"]);
  assert.equal(rrule.name, "rrule");
  assert.deepEqual(rrule.importedBy[0].example, example);
  assert.deepEqual(report.edges.added, []);
});

test("a lazy bundle merged into the initial load names its importer", () => {
  const head = baseApp();
  delete head.chunks[CODEMIRROR];
  head.chunks[ADMIN].dynamicImports = [];
  Object.assign(head.chunks[ENTRY].modules, {
    "app/static/codemirror.js": 5000,
    // Moved in the same PR that bumps the package.
    "@codemirror/view@6.2.0/dist/index.js": 20000,
  });
  head.importers["app/static/codemirror.js"] = ["app/app.js"];

  const { report, keys } = compare(baseApp(), head);
  const [moved] = report.movedIntoInitialLoad;

  assert.deepEqual(keys, ["moved:lazy:app/static/codemirror.js", "initial"]);
  assert.equal(moved.bytes, 25000);
  assert.deepEqual(moved.importers, [
    { from: "app/app.js", to: "app/static/codemirror.js" },
  ]);
  assert.match(
    renderSummary(report, BUDGET),
    /\| `codemirror` \| lazy \| moved into initial load \|/
  );
});

test("core importing lazy code names the import that pulled it in", () => {
  const base = baseApp();
  base.chunks[ADMIN].modules["admin/components/big.gjs"] = 20000;
  base.importers["admin/components/big.gjs"] = ["admin/components/a.gjs"];
  const head = structuredClone(base);
  delete head.chunks[ADMIN].modules["admin/components/big.gjs"];
  head.chunks[ENTRY].modules["admin/components/big.gjs"] = 20000;
  head.importers["admin/components/big.gjs"].push("app/app.js");

  const { report, keys } = compare(base, head);

  assert.deepEqual(keys, ["moved:lazy:admin/compat-modules.js", "initial"]);
  assert.deepEqual(report.movedIntoInitialLoad[0].importers, [
    { from: "app/app.js", to: "admin/components/big.gjs" },
  ]);
  assert.deepEqual(report.initialLoad.topModules[0], {
    id: "admin/components/big.gjs",
    delta: 20000,
    added: false,
  });
});

test("splitting a shared chunk differently has no findings", () => {
  const base = baseApp();
  base.chunks[SHARED].modules["lodash@4.17.21/lodash.js"] = 15000;
  const head = structuredClone(base);
  const split = {
    "assets/js/chunk-ffff6666.digested.js": "moment@2.30.1/moment.js",
    "assets/js/chunk-gggg7777.digested.js": "lodash@4.17.21/lodash.js",
  };
  delete head.chunks[SHARED];
  for (const [file, id] of Object.entries(split)) {
    head.chunks[file] = {
      modules: { [id]: base.chunks[SHARED].modules[id] },
    };
  }
  head.chunks[ENTRY].imports = Object.keys(split);
  head.chunks[ADMIN].imports = Object.keys(split);

  assert.deepEqual(compare(base, head).keys, []);
});

test("bundles keep their keys across version bumps and lost facades", () => {
  const withDiff = (version) => {
    const app = baseApp();
    const file = `assets/js/diff-${version.replaceAll(".", "")}zz.digested.js`;
    app.chunks[ENTRY].dynamicImports.push(file);
    app.chunks[file] = {
      facade: `diff@${version}/libesm/index.js`,
      modules: { [`diff@${version}/libesm/index.js`]: 7000 },
    };
    return app;
  };
  const head = withDiff("9.1.0");
  head.chunks[CODEMIRROR].facade = null;
  head.chunks[CODEMIRROR].dynamicEntryModules = ["app/static/codemirror.js"];

  const { report, keys } = compare(withDiff("9.0.0"), head);

  assert.deepEqual(keys, []);
  assert.ok(report.bundles.every((b) => b.status === "same"));
});

test("a new import from the initial load is one new connection", () => {
  const head = baseApp();
  // The shared chunk is in the initial load and in admin's closure.
  head.chunks[SHARED].dynamicImports = [CODEMIRROR];
  head.chunks[SHARED].examples = {
    dynamic: {
      [CODEMIRROR]: {
        from: "moment@2.30.1/moment.js",
        to: "app/static/codemirror.js",
      },
    },
  };

  const { report, keys } = compare(baseApp(), head);

  assert.deepEqual(keys, [
    "edge:entry:discourse:lazy:app/static/codemirror.js:dynamic",
  ]);
  assert.equal(report.edges.added[0].example.from, "moment@2.30.1/moment.js");
});

test("growth over the threshold names the largest additions", () => {
  const head = baseApp();
  head.chunks[ADMIN].modules["admin/components/b.gjs"] = 5000;

  const { report, keys } = compare(baseApp(), head);

  assert.deepEqual(keys, ["grew:lazy:admin/compat-modules.js"]);
  assert.deepEqual(bundle(report, "lazy:admin/compat-modules.js").topModules, [
    { id: "admin/components/b.gjs", delta: 5000, added: true },
  ]);
});

test("a lazy chunk without a facade is a bundle named after its import", () => {
  const withMarkdown = (bytes) => {
    const app = baseApp({
      [MARKDOWN]: {
        dynamicEntryModules: ["app/static/markdown-it/index.js"],
        modules: {
          "app/static/markdown-it/index.js": 1000,
          "markdown-it@15.0.3/dist/markdown-it.mjs": bytes,
        },
      },
    });
    app.chunks[ENTRY].dynamicImports.push(MARKDOWN);
    return app;
  };

  const { report, keys } = compare(withMarkdown(40000), withMarkdown(45000));

  assert.deepEqual(keys, ["grew:lazy:app/static/markdown-it/index.js"]);
  assert.equal(
    bundle(report, "lazy:app/static/markdown-it/index.js").name,
    "app/static/markdown-it/index"
  );
});

test("making initial-load code lazy again is a new bundle, nothing more", () => {
  const base = baseApp();
  base.chunks[ENTRY].imports.push(CODEMIRROR);

  assert.deepEqual(compare(base, baseApp()).keys, [
    "new:lazy:app/static/codemirror.js",
  ]);
});

test("an import() of code the initial load has is no new bundle", () => {
  const head = baseApp();
  head.chunks[ADMIN].dynamicImports.push(SHARED);
  head.chunks[SHARED].dynamicEntryModules = ["moment@2.30.1/moment.js"];

  assert.deepEqual(compare(baseApp(), head).keys, []);
});

test("a second version of a lazy package in core is not moved code", () => {
  const base = baseApp();
  base.chunks[ADMIN].modules["foo@1.0.0/x.js"] = 5000;
  const head = structuredClone(base);
  head.chunks[ENTRY].modules["foo@2.0.0/x.js"] = 5000;

  assert.deepEqual(compare(base, head).report.movedIntoInitialLoad, []);
});
