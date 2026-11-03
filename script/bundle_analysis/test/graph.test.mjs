import assert from "node:assert/strict";
import { test } from "node:test";
import {
  describeBuild,
  loadGraph,
  packageOf,
  stripVersion,
} from "../lib/graph.mjs";
import { baseApp, makeDist } from "./helpers.mjs";

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
