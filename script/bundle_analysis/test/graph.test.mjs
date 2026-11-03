import { readFileSync, writeFileSync } from "fs";
import assert from "node:assert/strict";
import { test } from "node:test";
import { join } from "path";
import {
  describeBuild,
  loadGraph,
  packageOf,
  stripVersion,
} from "../lib/graph.mjs";
import { baseApp, makeDist, REPORT } from "./helpers.mjs";

test("stripVersion and packageOf", () => {
  assert.equal(
    stripVersion("@faker-js/faker@10.6.0/dist/index.js"),
    "@faker-js/faker/dist/index.js"
  );
  assert.equal(
    stripVersion("diff@9.0.0/libesm/index.js"),
    "diff/libesm/index.js"
  );
  assert.equal(stripVersion("app/lib/a@b.js"), "app/lib/a@b.js");
  assert.deepEqual(packageOf("@scope/pkg@1.2.3-beta.1/x.js"), {
    name: "@scope/pkg",
    version: "1.2.3-beta.1",
  });
  assert.equal(packageOf("app/app.js"), null);
});

test("describeBuild names bundles and measures what they add", () => {
  const build = describeBuild(loadGraph(makeDist(baseApp())));
  const admin = build.bundles.get("lazy:admin/compat-modules.js");

  assert.deepEqual([...build.bundles.keys()].sort(), [
    "entry:discourse",
    "lazy:admin/compat-modules.js",
    "lazy:app/static/codemirror.js",
  ]);
  assert.equal(admin.name, "admin");
  assert.deepEqual(
    [...admin.costChunks],
    ["assets/js/admin-cccc3333.digested.js"]
  );
  assert.equal(build.initial.size, 2);
});

test("generic labels fall back to the facade", () => {
  const app = baseApp({
    "assets/js/dist-zzzz9999.digested.js": {
      kind: "lazy",
      facade: "dom-accessibility-api@0.7.1/dist/index.js",
      modules: { "dom-accessibility-api@0.7.1/dist/index.js": 100 },
    },
  });
  const build = describeBuild(loadGraph(makeDist(app)));

  assert.equal(
    build.bundles.get("lazy:dom-accessibility-api/dist/index.js").name,
    "dom-accessibility-api"
  );
});

function withReportedModules(file, modules) {
  const dir = makeDist(
    baseApp({ [file]: { kind: "shared", modules: { "app/a.js": 1 } } })
  );
  const path = join(dir, REPORT);
  const report = JSON.parse(readFileSync(path, "utf8"));
  const graphPath = join(dir, "manifest/bundle-graph.json");
  const graph = JSON.parse(readFileSync(graphPath, "utf8"));
  graph.chunks[file].modules = modules.graph;
  report.chunks[file].modules = modules.report;
  writeFileSync(graphPath, JSON.stringify(graph));
  writeFileSync(path, JSON.stringify(report));
  return { dir, path, report };
}

test("loadGraph matches report module ids to graph ids", () => {
  const file = "assets/js/chunk-hhhh8888.digested.js";
  const { dir } = withReportedModules(file, {
    graph: [
      "moment@2.29.0/moment.js",
      "moment@2.30.1/moment.js",
      "virtual:dynamic-chunk-url:app/workers/entry.js",
      "virtual:rolldown/runtime.js",
    ],
    report: [
      { id: "\0rolldown/runtime.js", renderedLength: 10 },
      {
        id: "\0virtual:dynamic-chunk-url:/build/frontend/discourse/app/workers/entry.js",
        renderedLength: 20,
      },
      { id: "node_modules/moment/moment.js", renderedLength: 30 },
      { id: "node_modules/moment/moment.js", renderedLength: 40 },
      { id: "\0virtual:elsewhere", renderedLength: 5 },
    ],
  });
  const chunk = loadGraph(dir).chunks[file];

  assert.deepEqual(chunk.modules, {
    "moment@2.29.0/moment.js": 30,
    "moment@2.30.1/moment.js": 40,
    "virtual:dynamic-chunk-url:app/workers/entry.js": 20,
    "virtual:rolldown/runtime.js": 10,
    "virtual:elsewhere": 5,
  });
  assert.equal(chunk.brotliSize, 1);
});

test("loadGraph needs brotli sizes, which only production builds have", () => {
  const file = "assets/js/chunk-hhhh8888.digested.js";
  const { dir, path, report } = withReportedModules(file, {
    graph: ["app/a.js"],
    report: [{ id: "app/a.js", renderedLength: 1 }],
  });
  report.chunks[file].brotliSize = null;
  writeFileSync(path, JSON.stringify(report));

  assert.throws(() => loadGraph(dir), /no brotli size for assets\/js\/chunk/);
});
